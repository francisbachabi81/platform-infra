# Creates/reuses an Entra ID App Registration + Service Principal for GitHub Actions

[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidateSet("gov","commercial")]
  [string]$Cloud,

  [Parameter(Mandatory)]
  [ValidateSet("nonprod","prod")]
  [string]$Plane,

  [Parameter(Mandatory)]
  [string]$TenantId,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$Product,

  [Parameter()]
  [string]$Org = "test",

  [Parameter()]
  [string]$Repo = "platform-infra",

  # MG is now a parameter (no longer hardcoded)
  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ManagementGroupId,

  # --- Nonprod subscription IDs (required when Plane=nonprod)
  [Parameter()]
  [string]$NonprodCoreSubId,

  [Parameter()]
  [string]$DevSubId,

  [Parameter()]
  [string]$QaSubId,

  # --- Prod subscription IDs (required when Plane=prod)
  [Parameter()]
  [string]$ProdCoreSubId,

  [Parameter()]
  [string]$UatSubId,

  [Parameter()]
  [string]$ProdSubId,

  [Parameter()]
  [string]$OutputJson = "",

  # Optional: emit Azure CLI debug output
  [Parameter()]
  [switch]$AzDebug
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Require-ParamIf {
  param(
    [Parameter(Mandatory)][bool]$Condition,
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Value
  )
  if ($Condition -and [string]::IsNullOrWhiteSpace($Value)) {
    throw "Missing required parameter for this plane: -$Name"
  }
}

function Invoke-Az {
  param(
    [Parameter(Mandatory)][string[]]$AzArgs,
    [ValidateSet("json","tsv","none")][string]$OutFormat = "json"
  )

  $full = @()
  $full += $AzArgs
  if ($AzDebug) { $full += "--debug" }

  $stderrFile = New-TemporaryFile
  try {
    $cmdLine = "az " + ($full -join " ")
    Write-Host ">> $cmdLine"

    if ($OutFormat -eq "json") {
      $stdout = & az @full --only-show-errors -o json 2> $stderrFile
    } elseif ($OutFormat -eq "tsv") {
      $stdout = & az @full --only-show-errors -o tsv 2> $stderrFile
    } else {
      $stdout = & az @full --only-show-errors 2> $stderrFile
    }

    $exit   = $LASTEXITCODE
    $stderr = (Get-Content -Path $stderrFile -Raw)

    if ($exit -ne 0) {
      Write-Host "!! Azure CLI failed (exit=$exit)"
      if (-not [string]::IsNullOrWhiteSpace($stderr)) {
        Write-Host "!! stderr:`n$stderr"
      }
      throw "az command failed: $cmdLine"
    }

    return [pscustomobject]@{
      StdOut = $stdout
      StdErr = $stderr
    }
  }
  finally {
    Remove-Item $stderrFile -Force -ErrorAction SilentlyContinue
  }
}

function AzJson {
  param([Parameter(Mandatory)][string[]]$AzArgs)
  $r = Invoke-Az -AzArgs $AzArgs -OutFormat "json"
  if ([string]::IsNullOrWhiteSpace($r.StdOut)) { return $null }
  return ($r.StdOut | ConvertFrom-Json)
}

function AzText {
  param([Parameter(Mandatory)][string[]]$AzArgs)
  $r = Invoke-Az -AzArgs $AzArgs -OutFormat "tsv"
  return $r.StdOut
}

# ---------------------------
# Validate plane-specific required parameters
# ---------------------------
if ($Plane -eq "nonprod") {
  Require-ParamIf -Condition $true -Name "NonprodCoreSubId" -Value $NonprodCoreSubId
  Require-ParamIf -Condition $true -Name "DevSubId"        -Value $DevSubId
  Require-ParamIf -Condition $true -Name "QaSubId"         -Value $QaSubId
} else {
  Require-ParamIf -Condition $true -Name "ProdCoreSubId" -Value $ProdCoreSubId
  Require-ParamIf -Condition $true -Name "UatSubId"      -Value $UatSubId
  Require-ParamIf -Condition $true -Name "ProdSubId"     -Value $ProdSubId
}

# Default output file (now includes Product)
if ([string]::IsNullOrWhiteSpace($OutputJson)) {
  $OutputJson = "gha-oidc-$Product-$Repo-$Cloud-$Plane.json"
}

# App name now includes Product and NO trailing 2-digit/seq
$appName = "app-gha-$Product-$Repo-$Plane"

# OIDC constants for GitHub Actions -> Azure
$issuer = "https://token.actions.githubusercontent.com"

# Audience differs by cloud (per your requirement)
$audience = if ($Cloud -eq "gov") { "api://AzureADTokenExchangeUSGov" } else { "api://AzureADTokenExchange" }

# Plane-specific config (kept as-is except mgId now comes from param)
$mgId = $ManagementGroupId

if ($Plane -eq "nonprod") {
  $fedCreds = @(
    @{ name="gha-platform-infra-dev";     env="dev";     description="Used by platform-infra workflows to deploy resources to dev" },
    @{ name="gha-platform-infra-qa";      env="qa";      description="Used by platform-infra workflows to deploy resources to qa" },
    @{ name="gha-platform-infra-nonprod"; env="nonprod"; description="Used by platform-infra workflows to deploy resources to nonprod" }
  )
  $contribSubs = @(
    @{ label="core-nonprod"; subId=$NonprodCoreSubId },
    @{ label="dev";          subId=$DevSubId },
    @{ label="qa";           subId=$QaSubId }
  )
} else {
  $fedCreds = @(
    @{ name="gha-platform-infra-prod";     env="prod";     description="Used by platform-infra workflows to deploy resources to prod" },
    @{ name="gha-platform-infra-uat";      env="uat";      description="Used by platform-infra workflows to deploy resources to uat" },
    @{ name="gha-platform-infra-coreprod"; env="coreprod"; description="Used by platform-infra workflows to deploy resources to coreprod" }
  )
  $contribSubs = @(
    @{ label="core-prod"; subId=$ProdCoreSubId },
    @{ label="prod";      subId=$ProdSubId },
    @{ label="uat";       subId=$UatSubId }
  )
}

Write-Host "==> Cloud:    $Cloud"
Write-Host "==> Plane:    $Plane"
Write-Host "==> Product:  $Product"
Write-Host "==> App Name: $appName"
Write-Host "==> Repo:     $Org/$Repo"
Write-Host "==> Issuer:   $issuer"
Write-Host "==> Audience: $audience"
Write-Host "==> MG ID:    $mgId"
Write-Host "==> Output:   $OutputJson"

# ---------------------------
# Ensure we're in the right tenant context
# ---------------------------
$account = AzJson -AzArgs @("account","show")
if ($account.tenantId -ne $TenantId) {
  Write-Host "Switching Azure CLI tenant context to $TenantId ..."
  AzText -AzArgs @("login","--tenant",$TenantId) | Out-Null
  $account = AzJson -AzArgs @("account","show")
  if ($account.tenantId -ne $TenantId) {
    throw "Azure CLI tenant context is still $($account.tenantId) after login; expected $TenantId"
  }
}

# ---------------------------
# 1) Create/reuse app registration
# ---------------------------
$appList = AzJson -AzArgs @("ad","app","list","--filter","displayName eq '$appName'")
if (-not $appList -or $appList.Count -eq 0) {
  Write-Host "Creating app registration: $appName"
  $createdApp  = AzJson -AzArgs @("ad","app","create","--display-name",$appName)
  $appId       = $createdApp.appId
  $appObjectId = $createdApp.id
} else {
  $appId       = $appList[0].appId
  $appObjectId = $appList[0].id
  Write-Host "Reusing existing app registration: $appName (appId=$appId)"
}

# ---------------------------
# 2) Create/reuse service principal
# ---------------------------
$spList = AzJson -AzArgs @("ad","sp","list","--filter","appId eq '$appId'")
if (-not $spList -or $spList.Count -eq 0) {
  Write-Host "Creating service principal for appId: $appId"
  $createdSp  = AzJson -AzArgs @("ad","sp","create","--id",$appId)
  $spObjectId = $createdSp.id
} else {
  $spObjectId = $spList[0].id
  Write-Host "Reusing existing service principal (spObjectId=$spObjectId)"
}

# ---------------------------
# Helper: ensure federated credential exists and matches expected (Environment scenario)
# ---------------------------
function Ensure-FederatedCredential {
  param(
    [Parameter(Mandatory)][string]$AppObjectId,
    [Parameter(Mandatory)][string]$CredName,
    [Parameter(Mandatory)][string]$Subject,
    [Parameter(Mandatory)][string]$Description,
    [Parameter(Mandatory)][string]$Issuer,
    [Parameter(Mandatory)][string]$Audience
  )

  $existing = @()
  try {
    $existing = AzJson -AzArgs @("ad","app","federated-credential","list","--id",$AppObjectId)
  } catch {
    $existing = @()
  }

  $match = $existing | Where-Object { $_.name -eq $CredName } | Select-Object -First 1

  if ($match) {
    Write-Host "Updating federated credential (delete+recreate): $CredName"
    AzText -AzArgs @(
      "ad","app","federated-credential","delete",
      "--id",$AppObjectId,
      "--federated-credential-id",$match.id
    ) | Out-Null
  } else {
    Write-Host "Creating federated credential: $CredName"
  }

  $payload = @{
    name        = $CredName
    issuer      = $Issuer
    subject     = $Subject
    description = $Description
    audiences   = @($Audience)
  } | ConvertTo-Json -Depth 6

  $tmp = New-TemporaryFile
  Set-Content -Path $tmp -Value $payload -Encoding UTF8

  $created = AzJson -AzArgs @(
    "ad","app","federated-credential","create",
    "--id",$AppObjectId,
    "--parameters","@$($tmp.FullName)"
  )

  Remove-Item $tmp -Force
  return $created
}

# ---------------------------
# 3) Create federated credentials (ENVIRONMENT scenario)
# ---------------------------
$federatedResults = @()
foreach ($fc in $fedCreds) {
  $envName = [string]$fc.env
  $subject = "repo:$($Org)/$($Repo):environment:$envName"  # keep exact format

  $federatedResults += (Ensure-FederatedCredential `
    -AppObjectId  $appObjectId `
    -CredName     $fc.name `
    -Subject      $subject `
    -Description  $fc.description `
    -Issuer       $issuer `
    -Audience     $audience
  )
}

# ---------------------------
# Helper: role assignment (normalize output so JSON rendering never fails)
# ---------------------------
function Ensure-RoleAssignment {
  param(
    [Parameter(Mandatory)][string]$AssigneeObjectId,
    [Parameter(Mandatory)][string]$Role,
    [Parameter(Mandatory)][string]$Scope
  )

  $assignments = @()
  try {
    $assignments = AzJson -AzArgs @("role","assignment","list","--assignee-object-id",$AssigneeObjectId,"--scope",$Scope)
  } catch {
    $assignments = @()
  }

  $exists = $assignments | Where-Object { $_.roleDefinitionName -eq $Role } | Select-Object -First 1
  if ($exists) {
    Write-Host "Role assignment exists: $Role on $Scope"
    return [pscustomobject]@{
      id                 = $exists.id
      roleDefinitionName = $Role
      scope              = $exists.scope
      principalId        = $exists.principalId
    }
  }

  Write-Host "Creating role assignment: $Role on $Scope"
  $created = AzJson -AzArgs @(
    "role","assignment","create",
    "--assignee-object-id",$AssigneeObjectId,
    "--assignee-principal-type","ServicePrincipal",
    "--role",$Role,
    "--scope",$Scope
  )

  return [pscustomobject]@{
    id                 = $created.id
    roleDefinitionName = $Role
    scope              = $created.scope
    principalId        = $created.principalId
  }
}

# ---------------------------
# 4) Assign Contributor to required subscriptions
# ---------------------------
$roleAssignments = @()
foreach ($s in $contribSubs) {
  $scope = "/subscriptions/$($s.subId)"
  $roleAssignments += (Ensure-RoleAssignment -AssigneeObjectId $spObjectId -Role "Contributor" -Scope $scope)
}

# ---------------------------
# 5) Assign Reader to management group
# ---------------------------
$mgScope = "/providers/Microsoft.Management/managementGroups/$mgId"
$roleAssignments += (Ensure-RoleAssignment -AssigneeObjectId $spObjectId -Role "Reader" -Scope $mgScope)

# ---------------------------
# 6) Output JSON summary
# ---------------------------
$result = [ordered]@{
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
  cloud          = $Cloud
  plane          = $Plane
  tenantId       = $TenantId
  product        = $Product
  org            = $Org
  repo           = $Repo
  appName        = $appName
  appId          = $appId              # ClientId
  appObjectId    = $appObjectId
  spObjectId     = $spObjectId
  oidc = @{
    issuer        = $issuer
    audience      = $audience
    scenario      = "github-actions-azure-deploy"
    subjectFormat = "repo:<org>/<repo>:environment:<env>"
  }
  managementGroup = @{
    id    = $mgId
    scope = $mgScope
    role  = "Reader"
  }
  subscriptions = $contribSubs | ForEach-Object {
    [ordered]@{
      label = $_.label
      subId = $_.subId
      scope = "/subscriptions/$($_.subId)"
      role  = "Contributor"
    }
  }
  federatedCredentials = $federatedResults | ForEach-Object {
    [ordered]@{
      id          = $_.id
      name        = $_.name
      subject     = $_.subject
      issuer      = $_.issuer
      audiences   = $_.audiences
      description = $_.description
    }
  }
  roleAssignments = $roleAssignments | ForEach-Object {
    [ordered]@{
      id                 = $_.id
      roleDefinitionName = $_.roleDefinitionName
      scope              = $_.scope
      principalId        = $_.principalId
    }
  }
}

($result | ConvertTo-Json -Depth 12) | Set-Content -Path $OutputJson -Encoding UTF8

Write-Host "`n✅ Done. Wrote: $OutputJson"
Write-Host "AppId (ClientId): $appId"
Write-Host "SP ObjectId:       $spObjectId"