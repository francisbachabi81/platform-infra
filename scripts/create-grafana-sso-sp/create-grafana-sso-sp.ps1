
# pwsh -File ./create-grafana-sso-sp.ps1 -Product hrz -Env dev -Region usaz -Seq 01 -TenantId dd58f16c-b85a-4d66-99e1-f86905453853

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [ValidateSet("hrz","pub")]
  [string]$Product,

  [Parameter(Mandatory=$true)]
  [ValidateSet("dev","qa","uat","prod")]
  [string]$Env,

  [Parameter(Mandatory=$true)]
  [ValidatePattern("^[a-z0-9]{2,6}$")]
  [string]$Region,

  [Parameter(Mandatory=$true)]
  [ValidatePattern("^[0-9]{2}$")]
  [string]$Seq,

  [Parameter(Mandatory=$true)]
  [ValidatePattern("^[0-9a-fA-F-]{36}$")]
  [string]$TenantId,

  # Allowed group ids for Grafana SSO (comma-separated GUIDs).
  [Parameter()]
  [string]$AllowedGroupIds = "225931d5-d049-41e4-8561-cd77c16eeac8",

  [Parameter()]
  [string]$AllowedDomains = "intterragroup.com",

  [Parameter()]
  [ValidateRange(30, 3650)]
  [int]$SecretValidityDays = 365,

  [Parameter()]
  [switch]$NoRotate,

  [Parameter()]
  [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name. Install Azure CLI and ensure it's in PATH."
  }
}

function Write-Warn([string]$Msg) { Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Write-Info([string]$Msg) { Write-Host "[INFO] $Msg" -ForegroundColor Blue }
function Write-Ok([string]$Msg)   { Write-Host "[OK] $Msg" -ForegroundColor Green }
function Die([string]$Msg) { throw $Msg }

function AzRun {
  param(
    [Parameter(Mandatory=$true)][string[]]$Args,
    [ValidateSet("tsv","json","none")][string]$Format = "none",
    [switch]$OnlyShowErrors
  )
  $azArgs = @($Args)
  if ($OnlyShowErrors) { $azArgs += "--only-show-errors" }
  if ($Format -ne "none") { $azArgs += @("-o", $Format) }

  $out = & az @azArgs 2>&1
  $code = $LASTEXITCODE
  return [pscustomobject]@{
    ExitCode = $code
    Text     = ($out | Out-String)
    Args     = $azArgs
  }
}

function AzTsv {
  param(
    [Parameter(Mandatory=$true)][string[]]$Args,
    [switch]$AllowEmpty,
    [switch]$Quiet
  )
  $r = if ($Quiet) { AzRun -Args $Args -Format "tsv" -OnlyShowErrors } else { AzRun -Args $Args -Format "tsv" }
  if ($r.ExitCode -ne 0) {
    if ($Quiet) { return "" }
    Die "az $($r.Args -join ' ') failed: $($r.Text.Trim())"
  }
  $val = ($r.Text ?? "").Trim()
  if (-not $AllowEmpty -and [string]::IsNullOrWhiteSpace($val)) { return "" }
  return $val
}

function Extract-JsonObjectFromText {
  param([Parameter(Mandatory=$true)][string]$Text)
  $t = ($Text ?? "").Trim()
  if ([string]::IsNullOrWhiteSpace($t)) { return $null }

  if (($t.StartsWith("{") -and $t.EndsWith("}")) -or ($t.StartsWith("[") -and $t.EndsWith("]"))) { return $t }

  $objMatch = [regex]::Match($t, "\{[\s\S]*\}")
  if ($objMatch.Success) { return $objMatch.Value }

  $arrMatch = [regex]::Match($t, "\[[\s\S]*\]")
  if ($arrMatch.Success) { return $arrMatch.Value }

  return $null
}

function AzJson {
  param(
    [Parameter(Mandatory=$true)][string[]]$Args,
    [switch]$OnlyShowErrors
  )
  $r = AzRun -Args $Args -Format "json" -OnlyShowErrors:$OnlyShowErrors
  if ($r.ExitCode -ne 0) {
    Die "az $($r.Args -join ' ') failed: $($r.Text.Trim())"
  }
  $txt = ($r.Text ?? "").Trim()
  $jsonText = Extract-JsonObjectFromText -Text $txt
  if ([string]::IsNullOrWhiteSpace($jsonText)) {
    Die "Failed to locate JSON in az output: $txt"
  }
  try { return $jsonText | ConvertFrom-Json } catch { Die "Failed to parse JSON from az output: $txt" }
}

function New-AppRoleObject {
  param(
    [Parameter(Mandatory=$true)][string]$DisplayName,
    [Parameter(Mandatory=$true)][string]$Value,
    [Parameter(Mandatory=$true)][string]$Description
  )
  # IMPORTANT: "users/groups" in portal -> allowedMemberTypes=["User"] in Graph.
  return @{
    allowedMemberTypes = @("User")
    description        = $Description
    displayName        = $DisplayName
    id                 = ([guid]::NewGuid()).ToString()
    isEnabled          = $true
    origin             = "Application"
    value              = $Value
  }
}

Assert-Command az

# Plane inference
$Plane = switch ($Env) { "dev" { "np" } "qa" { "np" } "uat" { "pr" } "prod" { "pr" } }

# Naming convention (Grafana SSO)
$AppName = "app-$Product-$Env-$Region-obs-grafana-sso-$Seq"
$EnvUpper = $Env.ToUpperInvariant()

# Credential display name in Entra
$ClientSecretDisplayName = "$EnvUpper--OBS--GRAFANA-ENTRA-CLIENT-SECRET"

if (-not $OutputPath) {
  $OutputPath = "grafana-sso-sp-$Product-$Plane-$Region-$Env-$Seq.json"
}

Write-Host "== Grafana UI SSO App Registration Creator (PowerShell) ==" -ForegroundColor Cyan
Write-Host "TenantId:            $TenantId"
Write-Host "Product:             $Product"
Write-Host "Env:                 $Env"
Write-Host "Plane:               $Plane"
Write-Host "Region:              $Region"
Write-Host "Seq:                 $Seq"
Write-Host "AppName:             $AppName"
Write-Host "Secret display name: $ClientSecretDisplayName"
Write-Host "AllowedGroupIds:     $AllowedGroupIds"
Write-Host "AllowedDomains:      $AllowedDomains"
Write-Host "Output:              $OutputPath"
Write-Host "RotateSecret:        $(-not $NoRotate)"
Write-Host ""

# Ensure logged in + correct tenant
$currentTenant = AzTsv -Args @("account","show","--query","tenantId") -AllowEmpty
if ([string]::IsNullOrWhiteSpace($currentTenant)) { Die "Azure CLI is not logged in. Run: az login --tenant $TenantId" }

if ($currentTenant -ne $TenantId) {
  Write-Info "Switching az login tenant from $currentTenant to $TenantId..."
  $rLogin = AzRun -Args @("login","--tenant",$TenantId) -Format "none" -OnlyShowErrors
  if ($rLogin.ExitCode -ne 0) { Die "az login --tenant $TenantId failed: $($rLogin.Text.Trim())" }
}

# 1) Find or create app registration
Write-Info "Checking for existing app registration: $AppName"
$clientId = AzTsv -Args @("ad","app","list","--display-name",$AppName,"--query","[0].appId") -AllowEmpty -Quiet
$appObjId = AzTsv -Args @("ad","app","list","--display-name",$AppName,"--query","[0].id")    -AllowEmpty -Quiet

if ([string]::IsNullOrWhiteSpace($clientId)) {
  Write-Ok "Creating app registration: $AppName"
  $rCreate = AzRun -Args @("ad","app","create","--display-name",$AppName,"--query","appId") -Format "tsv"
  if ($rCreate.ExitCode -ne 0) { Die "Failed to create app registration. Details: $($rCreate.Text.Trim())" }
  $clientId = ($rCreate.Text ?? "").Trim()
  if ([string]::IsNullOrWhiteSpace($clientId)) { Die "App creation returned empty appId." }
  $appObjId = AzTsv -Args @("ad","app","show","--id",$clientId,"--query","id") -AllowEmpty -Quiet
} else {
  if ([string]::IsNullOrWhiteSpace($appObjId)) {
    $appObjId = AzTsv -Args @("ad","app","show","--id",$clientId,"--query","id") -AllowEmpty -Quiet
  }
}
if ([string]::IsNullOrWhiteSpace($clientId) -or [string]::IsNullOrWhiteSpace($appObjId)) {
  Die "Failed to obtain appId/objectId after create/find."
}
Write-Ok "App: $AppName ($clientId)"

# 2) Ensure service principal exists
Write-Info "Ensuring service principal exists for appId: $clientId"
$spId = AzTsv -Args @("ad","sp","list","--filter","appId eq '$clientId'","--query","[0].id") -AllowEmpty -Quiet
if ([string]::IsNullOrWhiteSpace($spId)) {
  Write-Ok "Creating service principal..."
  $rSp = AzRun -Args @("ad","sp","create","--id",$clientId,"--query","id") -Format "tsv"
  if ($rSp.ExitCode -ne 0) { Die "Failed to create service principal. Details: $($rSp.Text.Trim())" }
  $spId = ($rSp.Text ?? "").Trim()
}
if ([string]::IsNullOrWhiteSpace($spId)) { Die "Failed to create/find service principal for appId=$clientId." }

# 3) Add Microsoft Graph delegated permission: User.Read (Scope)
$GraphAppId = "00000003-0000-0000-c000-000000000000"
Write-Info "Adding Microsoft Graph delegated permission: User.Read (no admin consent required)..."

$userReadScopeId = AzTsv -Args @(
  "ad","sp","show","--id",$GraphAppId,
  "--query","oauth2PermissionScopes[?value=='User.Read'].id | [0]"
) -AllowEmpty -Quiet

if ([string]::IsNullOrWhiteSpace($userReadScopeId)) { Die "Could not find Microsoft Graph delegated scope id for User.Read." }

$rPerm = AzRun -Args @(
  "ad","app","permission","add",
  "--id",$appObjId,
  "--api",$GraphAppId,
  "--api-permissions","$userReadScopeId=Scope"
) -Format "none" -OnlyShowErrors
if ($rPerm.ExitCode -ne 0) {
  Write-Warn "Permission add returned non-zero (may already exist). Details: $($rPerm.Text.Trim())"
}

# 4) Configure group claims (groupMembershipClaims = 'All')
Write-Info "Configuring token group claims (groupMembershipClaims = 'All')..."
$uriApp = "https://graph.microsoft.com/v1.0/applications/$appObjId"

# First: set groupMembershipClaims = All (matches portal: Add groups claim -> All groups)
$bodyPatch = @{ groupMembershipClaims = "All" } | ConvertTo-Json -Compress
$rPatch = AzRun -Args @(
  "rest","--method","PATCH","--uri",$uriApp,
  "--headers","Content-Type=application/json",
  "--body",$bodyPatch
) -Format "none" -OnlyShowErrors

if ($rPatch.ExitCode -ne 0) {
  Write-Warn "Failed to set groupMembershipClaims. Portal path: Token configuration > Add groups claim. Details: $($rPatch.Text.Trim())"
} else {
  Write-Ok "Group claims set to 'All'."
}

# 4a) Ensure Optional Claim 'groups' exists for ID, Access, and SAML tokens
Write-Info "Ensuring optional claim 'groups' is present for ID/Access/SAML token types..."

# Read current optionalClaims so we merge (avoid overwriting other optional claims)
$appNow = AzJson -Args @("rest","--method","GET","--uri",$uriApp) -OnlyShowErrors

$optionalClaims = $appNow.optionalClaims
if (-not $optionalClaims) {
  $optionalClaims = @{
    idToken     = @()
    accessToken = @()
    saml2Token  = @()
  }
}
function Ensure-GroupsOptionalClaim {
  param(
    [hashtable]$OptClaims,
    [ValidateSet("idToken","accessToken","saml2Token")]
    [string]$TokenType
  )

  if (-not $OptClaims.ContainsKey($TokenType) -or -not $OptClaims[$TokenType]) {
    $OptClaims[$TokenType] = @()
  }

  $exists = $false
  foreach ($c in @($OptClaims[$TokenType])) {
    if ($c.name -eq "groups") { $exists = $true; break }
  }

  if (-not $exists) {
    # Keep default behavior (group object IDs). Optional formatting can be added later via additionalProperties.
    $OptClaims[$TokenType] += @(@{
      name = "groups"
      additionalProperties = @()
    })
  }

  return $OptClaims
}

$optionalClaims = Ensure-GroupsOptionalClaim -OptClaims $optionalClaims -TokenType "idToken"
$optionalClaims = Ensure-GroupsOptionalClaim -OptClaims $optionalClaims -TokenType "accessToken"
$optionalClaims = Ensure-GroupsOptionalClaim -OptClaims $optionalClaims -TokenType "saml2Token"

$bodyOpt = @{ optionalClaims = $optionalClaims } | ConvertTo-Json -Depth 20 -Compress
$rOpt = AzRun -Args @(
  "rest","--method","PATCH","--uri",$uriApp,
  "--headers","Content-Type=application/json",
  "--body",$bodyOpt
) -Format "none" -OnlyShowErrors

if ($rOpt.ExitCode -ne 0) {
  Write-Warn "Failed to set optionalClaims(groups) for ID/Access/SAML. Details: $($rOpt.Text.Trim())"
} else {
  Write-Ok "Optional claim 'groups' ensured for ID/Access/SAML."
}

# 4b) Configure Web redirect URIs for Grafana OAuth (web platform)
Write-Info "Configuring Web redirect URIs for Grafana OAuth..."
$appHostName = "internal.$Env.horizon.intterra.io"
$redirectUris = @(
  "https://$($appHostName):8443/logs",
  "https://$($appHostName)/logs/login/azuread",
  "https://$($appHostName):8443/logs/login/azuread"
)

# Merge with any existing redirect URIs (avoid overwriting)
$webNow = AzJson -Args @("rest","--method","GET","--uri",$uriApp,"--query","web") -OnlyShowErrors
$existingRedirects = @()
if ($webNow -and $webNow.redirectUris) { $existingRedirects = @($webNow.redirectUris) }

$merged = New-Object System.Collections.Generic.List[string]
foreach ($u in $existingRedirects) { if (-not [string]::IsNullOrWhiteSpace($u) -and -not $merged.Contains($u)) { [void]$merged.Add($u) } }
foreach ($u in $redirectUris)      { if (-not [string]::IsNullOrWhiteSpace($u) -and -not $merged.Contains($u)) { [void]$merged.Add($u) } }

$bodyWeb = @{ web = @{ redirectUris = $merged } } | ConvertTo-Json -Depth 10 -Compress
$rWeb = AzRun -Args @("rest","--method","PATCH","--uri",$uriApp,"--headers","Content-Type=application/json","--body",$bodyWeb) -Format "none" -OnlyShowErrors
if ($rWeb.ExitCode -ne 0) {
  Write-Warn "Failed to set Web redirect URIs. You can set this in the portal under Authentication > Web. Details: $($rWeb.Text.Trim())"
} else {
  Write-Ok ("Web redirect URIs set/merged: " + ($redirectUris -join ", "))
}

# 5) Ensure app roles exist (Admin/Editor/Viewer)
Write-Info "Ensuring Grafana app roles exist (Admin/Editor/Viewer)..."
$appNow = AzJson -Args @("rest","--method","GET","--uri",$uriApp) -OnlyShowErrors
$existingRoles = @()
if ($appNow -and $appNow.appRoles) { $existingRoles = @($appNow.appRoles) }

function Find-RoleByValue([object[]]$roles, [string]$val) {
  foreach ($r in ($roles ?? @())) { if ($r.value -eq $val) { return $r } }
  return $null
}

$newRoles = @()
$newRoles += $existingRoles

if (-not (Find-RoleByValue -roles $existingRoles -val "Admin"))  { $newRoles += (New-AppRoleObject -DisplayName "Grafana Org Admin" -Value "Admin"  -Description "Grafana Org Admin") }
if (-not (Find-RoleByValue -roles $existingRoles -val "Editor")) { $newRoles += (New-AppRoleObject -DisplayName "Grafana Editor"    -Value "Editor" -Description "Grafana Editor") }
if (-not (Find-RoleByValue -roles $existingRoles -val "Viewer")) { $newRoles += (New-AppRoleObject -DisplayName "Grafana Viewer"    -Value "Viewer" -Description "Grafana Viewer") }

if ($newRoles.Count -ne $existingRoles.Count) {
  $bodyRoles = @{ appRoles = $newRoles } | ConvertTo-Json -Depth 20 -Compress
  $rRoles = AzRun -Args @("rest","--method","PATCH","--uri",$uriApp,"--headers","Content-Type=application/json","--body",$bodyRoles) -Format "none" -OnlyShowErrors
  if ($rRoles.ExitCode -ne 0) {
    Write-Warn "Failed to update app roles. You can add roles in the portal. Details: $($rRoles.Text.Trim())"
  } else {
    Write-Ok "App roles updated."
  }
} else {
  Write-Ok "App roles already present."
}

# 6) Create/rotate client secret
$secretValue = $null
$secretExpiration = $null
$endDateIso = (Get-Date).ToUniversalTime().AddDays($SecretValidityDays).ToString("yyyy-MM-ddTHH:mm:ssZ")

if (-not $NoRotate) {
  Write-Ok "Creating/rotating client secret (valid $SecretValidityDays days)..."
  $cred = AzJson -Args @(
    "ad","app","credential","reset",
    "--id",$clientId,
    "--display-name",$ClientSecretDisplayName,
    "--end-date",$endDateIso,
    "--query","{password:password, endDate:endDate, endDateTime:endDateTime}"
  ) -OnlyShowErrors

  $secretValue = $cred.password
  $secretExpiration = $cred.endDate
  if ([string]::IsNullOrWhiteSpace($secretExpiration)) { $secretExpiration = $cred.endDateTime }
  if ([string]::IsNullOrWhiteSpace($secretExpiration)) { $secretExpiration = $endDateIso }

  if ([string]::IsNullOrWhiteSpace($secretValue)) { Die "Secret creation did not return a password value." }
} else {
  Write-Warn "NoRotate set. Skipping secret creation (cannot retrieve existing secret value)."
  $secretExpiration = $endDateIso
}

# 7) Output JSON (including your requested keys)
$authUrl  = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/authorize"
$tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

$kvClientIdKey       = "$EnvUpper--OBS--GRAFANA-ENTRA-CLIENT-ID"
$kvClientSecretKey   = "$EnvUpper--OBS--GRAFANA-ENTRA-CLIENT-SECRET"
$kvAllowedGroupsKey  = "$EnvUpper--OBS--GRAFANA-ENTRA-ALLOWED-GROUP-IDS"
$kvAuthUrlKey        = "$EnvUpper--OBS--GRAFANA-ENTRA-AUTH-URL"
$kvTokenUrlKey       = "$EnvUpper--OBS--GRAFANA-ENTRA-TOKEN-URL"
$kvAllowedOrgsKey    = "$EnvUpper--OBS--GRAFANA-ENTRA-ALLOWED-ORGANIZATIONS"
$kvAllowedDomainsKey = "$EnvUpper--OBS--GRAFANA-ENTRA-ALLOWED-DOMAINS"

$appRolesOut = @(
  @{ displayName="Grafana Org Admin"; value="Admin";  description="Grafana Org Admin";  allowedMemberTypes=@("User"); isEnabled=$true },
  @{ displayName="Grafana Editor";    value="Editor"; description="Grafana Editor";    allowedMemberTypes=@("User"); isEnabled=$true },
  @{ displayName="Grafana Viewer";    value="Viewer"; description="Grafana Viewer";    allowedMemberTypes=@("User"); isEnabled=$true }
)

$outObj = [pscustomobject]@{
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
  product        = $Product
  env            = $Env
  plane          = $Plane
  region         = $Region
  seq            = $Seq
  tenantId       = $TenantId

  appName            = $AppName
  clientId           = $clientId
  servicePrincipalId = $spId

  secretDisplayName = $ClientSecretDisplayName
  secretValue       = $secretValue
  secretExpiration  = $secretExpiration

  settings = @{
    $kvClientIdKey       = $clientId
    $kvClientSecretKey   = $secretValue
    $kvAllowedGroupsKey  = $AllowedGroupIds
    $kvAuthUrlKey        = $authUrl
    $kvTokenUrlKey       = $tokenUrl
    $kvAllowedOrgsKey    = $TenantId
    $kvAllowedDomainsKey = $AllowedDomains
  }
}

$outObj | ConvertTo-Json -Depth 25 | Out-File -FilePath $OutputPath -Encoding utf8 -Force

Write-Host ""
Write-Ok "Wrote: $OutputPath"
Write-Host "ClientId: $clientId" -ForegroundColor Cyan
Write-Host "Secret display name: $ClientSecretDisplayName" -ForegroundColor Cyan
Write-Host "SecretExpiration: $secretExpiration" -ForegroundColor Cyan
Write-Host "NOTE: SecretValue is included in the JSON output. Treat the file as sensitive." -ForegroundColor Yellow