<# 
  Creates/reuses an Entra ID App Registration + Service Principal for identity-svc.
  pwsh -File ./create-identity-svc-sp.ps1 -Product hrz -Env dev -Region usaz -Seq 01 -TenantId dd58f16c-b85a-4d66-99e1-f8690545385
#>

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

  [Parameter()]
  [ValidateRange(30, 3650)]
  [int]$SecretValidityDays = 365,

  [Parameter()]
  [switch]$NoRotate,

  [Parameter()]
  [switch]$SkipAdminConsent,

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
function Write-Ok([string]$Msg) { Write-Host "[OK] $Msg" -ForegroundColor Green }
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

function Grant-GraphAppRole {
  param(
    [Parameter(Mandatory=$true)][string]$GraphBaseUrl,         # https://graph.microsoft.com OR https://graph.microsoft.us
    [Parameter(Mandatory=$true)][string]$PrincipalSpObjectId,  # service principal objectId of *your app*
    [Parameter(Mandatory=$true)][string]$ResourceSpObjectId,   # service principal objectId of Microsoft Graph in tenant
    [Parameter(Mandatory=$true)][string]$AppRoleId             # appRole id for User.Read.All
  )

  # Check if assignment already exists
  $filter = "resourceId eq $ResourceSpObjectId"
  $uriGet = "$GraphBaseUrl/v1.0/servicePrincipals/$PrincipalSpObjectId/appRoleAssignments?`$filter=$filter"
  $existing = AzJson -Args @("rest","--method","GET","--uri",$uriGet) -OnlyShowErrors
  $already = $false
  if ($existing -and $existing.value) {
    foreach ($a in $existing.value) {
      if (($a.appRoleId -eq $AppRoleId) -and ($a.resourceId -eq $ResourceSpObjectId)) { $already = $true; break }
    }
  }
  if ($already) {
    return [pscustomobject]@{ Attempted=$true; Granted=$true; Message="Already granted (assignment exists)." }
  }

  $bodyObj = @{
    principalId = $PrincipalSpObjectId
    resourceId  = $ResourceSpObjectId
    appRoleId   = $AppRoleId
  }
  $body = ($bodyObj | ConvertTo-Json -Compress)

  $uriPost = "$GraphBaseUrl/v1.0/servicePrincipals/$PrincipalSpObjectId/appRoleAssignments"

  $r = AzRun -Args @("rest","--method","POST","--uri",$uriPost,"--headers","Content-Type=application/json","--body",$body) -Format "none" -OnlyShowErrors
  if ($r.ExitCode -eq 0) {
    return [pscustomobject]@{ Attempted=$true; Granted=$true; Message="Granted via appRoleAssignment." }
  }

  # If create failed, return failure but do not crash the whole script unless you want it to.
  return [pscustomobject]@{ Attempted=$true; Granted=$false; Message=$r.Text.Trim() }
}

Assert-Command az

# Plane inference
$Plane = switch ($Env) { "dev" { "np" } "qa" { "np" } "uat" { "pr" } "prod" { "pr" } }

# Naming convention
$AppName = "app-$Product-$Env-$Region-identity-svc-$Seq"
$EnvUpper   = $Env.ToUpperInvariant()
$SecretName = "$EnvUpper--IDENTITY-SERVICE--AZURE-CLIENT-SECRET"
$ClientIdSecretName = "$EnvUpper--IDENTITY-SERVICE--AZURE-CLIENT-ID"
$TenantIdSecretName = "$EnvUpper--IDENTITY-SERVICE--AZURE-TENANT-ID"

if (-not $OutputPath) { $OutputPath = "identity-svc-sp-$Product-$Plane-$Region-$Env-$Seq.json" }

$GraphBaseUrl = if ($Product -eq "hrz") { "https://graph.microsoft.com" } else { "https://graph.microsoft.com" }

Write-Host "== identity-svc Service Principal Creator (PowerShell) ==" -ForegroundColor Cyan
Write-Host "TenantId:         $TenantId"
Write-Host "Product:          $Product"
Write-Host "Env:              $Env"
Write-Host "Plane:            $Plane"
Write-Host "Region:           $Region"
Write-Host "Seq:              $Seq"
Write-Host "AppName:          $AppName"
Write-Host "SecretName:       $SecretName"
Write-Host "Output:           $OutputPath"
Write-Host "RotateSecret:     $(-not $NoRotate)"
Write-Host "SkipAdminConsent: $SkipAdminConsent"
Write-Host "Graph endpoint:   $GraphBaseUrl"
Write-Host ""

# Ensure logged in + correct tenant
$currentTenant = AzTsv -Args @("account","show","--query","tenantId") -AllowEmpty
if ([string]::IsNullOrWhiteSpace($currentTenant)) { Die "Azure CLI is not logged in. Run: az login --tenant $TenantId" }

if ($currentTenant -ne $TenantId) {
  Write-Host "Switching az login tenant from $currentTenant to $TenantId..." -ForegroundColor Yellow
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

# 2) Ensure Microsoft Graph Application permission User.Read.All
$GraphAppId = "00000003-0000-0000-c000-000000000000"
Write-Info "Ensuring Microsoft Graph permission requirement: User.Read.All (Application)..."

$userReadAllRoleId = AzTsv -Args @(
  "ad","sp","show","--id",$GraphAppId,
  "--query","appRoles[?value=='User.Read.All' && contains(allowedMemberTypes, 'Application')].id | [0]"
) -AllowEmpty -Quiet

if ([string]::IsNullOrWhiteSpace($userReadAllRoleId)) { Die "Could not find Graph appRole id for User.Read.All (Application)." }

# Add permission requirement to the app registration (non-fatal if already exists)
$rPerm = AzRun -Args @(
  "ad","app","permission","add",
  "--id",$appObjId,
  "--api",$GraphAppId,
  "--api-permissions","$userReadAllRoleId=Role"
) -Format "none" -OnlyShowErrors
if ($rPerm.ExitCode -ne 0) {
  Write-Warn "Permission add returned non-zero (may already exist). Details: $($rPerm.Text.Trim())"
}

# 3) Find or create service principal
Write-Info "Checking for existing service principal for appId: $clientId"
$spId = AzTsv -Args @("ad","sp","list","--filter","appId eq '$clientId'","--query","[0].id") -AllowEmpty -Quiet

if ([string]::IsNullOrWhiteSpace($spId)) {
  Write-Ok "Creating service principal..."
  $rSp = AzRun -Args @("ad","sp","create","--id",$clientId,"--query","id") -Format "tsv"
  if ($rSp.ExitCode -ne 0) { Die "Failed to create service principal. Details: $($rSp.Text.Trim())" }
  $spId = ($rSp.Text ?? "").Trim()
}
if ([string]::IsNullOrWhiteSpace($spId)) { Die "Failed to create/find service principal for appId=$clientId." }

# 4) Grant permission (admin consent equivalent) via Microsoft Graph appRoleAssignments
$adminConsentAttempted = $false
$adminConsentGranted = $false
$adminConsentMessage = $null

if (-not $SkipAdminConsent) {
  $adminConsentAttempted = $true
  Write-Host "Granting Microsoft Graph app role (admin consent equivalent)..." -ForegroundColor Yellow

  # Need Graph service principal object id in this tenant (resourceId)
  $graphSpObjId = AzTsv -Args @("ad","sp","show","--id",$GraphAppId,"--query","id") -AllowEmpty -Quiet
  if ([string]::IsNullOrWhiteSpace($graphSpObjId)) {
    Write-Warn "Could not resolve Graph service principal object id in tenant. Skipping grant."
  } else {
    $grant = Grant-GraphAppRole -GraphBaseUrl $GraphBaseUrl -PrincipalSpObjectId $spId -ResourceSpObjectId $graphSpObjId -AppRoleId $userReadAllRoleId
    $adminConsentGranted = [bool]$grant.Granted
    $adminConsentMessage = [string]$grant.Message
    if ($adminConsentGranted) {
      Write-Ok "Grant result: $adminConsentMessage"
    } else {
      Write-Warn "Grant failed. You can still grant in the portal. Details: $adminConsentMessage"
    }
  }
} else {
  Write-Warn "SkipAdminConsent set. Permission requirement added but NOT granted."
}

# 5) Create/rotate secret
$secretValue = $null
$secretExpiration = $null
$endDateIso = (Get-Date).ToUniversalTime().AddDays($SecretValidityDays).ToString("yyyy-MM-ddTHH:mm:ssZ")

if (-not $NoRotate) {
  Write-Ok "Creating/rotating client secret (valid $SecretValidityDays days)..."
  $cred = AzJson -Args @(
    "ad","app","credential","reset",
    "--id",$clientId,
    "--display-name",$SecretName,
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

# 6) Emit JSON
$outObj = [pscustomobject]@{
  generatedAtUtc        = (Get-Date).ToUniversalTime().ToString("o")
  product               = $Product
  env                   = $Env
  plane                 = $Plane
  region                = $Region
  seq                   = $Seq
  tenantIdSecretName    = $tenantIdSecretName
  tenantId              = $TenantId
  appName               = $AppName
  clientIdSecretName    = $clientIdSecretName
  clientId              = $clientId
  servicePrincipalId    = $spId
  secretName            = $SecretName
  secretValue           = $secretValue
  secretExpiration      = $secretExpiration
  graphAppPermission    = "Microsoft Graph (Application): User.Read.All"
  consentAttempted      = $adminConsentAttempted
  consentGranted        = $adminConsentGranted
  consentMessage        = $adminConsentMessage
  graphEndpointUsed     = $GraphBaseUrl
}

$outObj | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding utf8 -Force

Write-Host ""
Write-Host "Wrote: $OutputPath" -ForegroundColor Cyan
Write-Host "ClientId: $clientId" -ForegroundColor Cyan
Write-Host "ServicePrincipalId: $spId" -ForegroundColor Cyan
Write-Host "SecretName: $SecretName" -ForegroundColor Cyan
Write-Host "SecretExpiration: $secretExpiration" -ForegroundColor Cyan
if (-not $SkipAdminConsent) {
  if ($adminConsentGranted) {
    Write-Host "Consent: Granted" -ForegroundColor Green
  } else {
    Write-Warn "Consent: NOT granted by script (grant in portal if needed)."
  }
} else {
  Write-Warn "Consent: skipped by request."
}
Write-Host "NOTE: SecretValue is included in the JSON output. Treat the file as sensitive." -ForegroundColor Yellow