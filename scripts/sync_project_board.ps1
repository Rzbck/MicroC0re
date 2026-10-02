param(
    [string]$ProjectTitle = "MicroC0re",
    [string]$Owner = "@me"
)

$ErrorActionPreference = "Stop"

function Invoke-GhJson {
    param([string[]]$Args)

    $output = & gh @Args
    if ($LASTEXITCODE -ne 0) {
        throw "gh failed: gh $($Args -join ' ')"
    }
    return ($output | Out-String | ConvertFrom-Json)
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI (gh) is not installed."
}

& gh auth status | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "GitHub CLI is not authenticated."
}

$projects = Invoke-GhJson @("project", "list", "--owner", $Owner, "--format", "json")
$projectList = @($projects.projects)
$project = $projectList | Where-Object { $_.title -eq $ProjectTitle } | Select-Object -First 1

if (-not $project) {
    throw "Project '$ProjectTitle' not found for owner $Owner."
}

$projectNumber = [int]$project.number
$projectInfo = Invoke-GhJson @("project", "view", "$projectNumber", "--owner", $Owner, "--format", "json")
$projectId = [string]$projectInfo.id

Write-Host "Project: $ProjectTitle (#$projectNumber)" -ForegroundColor Cyan

$fieldQuery = @'
query($projectId: ID!) {
  node(id: $projectId) {
    ... on ProjectV2 {
      fields(first: 100) {
        nodes {
          ... on ProjectV2SingleSelectField {
            id
            name
            options {
              id
              name
              color
              description
            }
          }
        }
      }
    }
  }
}
'@

$fieldPayload = @{
    query = $fieldQuery
    variables = @{ projectId = $projectId }
} | ConvertTo-Json -Depth 10

$fieldResult = ($fieldPayload | & gh api graphql --input -) | Out-String | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    throw "Unable to read GitHub Project fields."
}

$statusField = @($fieldResult.data.node.fields.nodes) |
    Where-Object { $_.name -eq "Status" } |
    Select-Object -First 1

if (-not $statusField) {
    throw "The project has no single-select field named 'Status'."
}

$desiredOptions = @(
    @{ name = "Backlog";     color = "GRAY";   description = "Gated or later work" },
    @{ name = "Todo";        color = "GREEN";  description = "Ready but not started" },
    @{ name = "In Progress"; color = "YELLOW"; description = "Actively being worked on" },
    @{ name = "Review";      color = "PURPLE"; description = "Implemented; awaiting validation/review" },
    @{ name = "Done";        color = "BLUE";   description = "Completed" }
)

$existingByName = @{}
foreach ($option in @($statusField.options)) {
    $existingByName[[string]$option.name] = $option
}

$needsFieldUpdate = $false
$newOptions = @()

foreach ($desired in $desiredOptions) {
    if ($existingByName.ContainsKey($desired.name)) {
        $existing = $existingByName[$desired.name]
        $newOptions += @{
            id = [string]$existing.id
            name = [string]$desired.name
            color = [string]$existing.color
            description = [string]$existing.description
        }
    }
    else {
        $needsFieldUpdate = $true
        $newOptions += @{
            name = [string]$desired.name
            color = [string]$desired.color
            description = [string]$desired.description
        }
    }
}

if ($needsFieldUpdate) {
    Write-Host "Adding missing Status columns..." -ForegroundColor Yellow

    $mutation = @'
mutation($fieldId: ID!, $options: [ProjectV2SingleSelectFieldOptionInput!]!) {
  updateProjectV2Field(
    input: {
      fieldId: $fieldId
      singleSelectOptions: $options
    }
  ) {
    projectV2Field {
      ... on ProjectV2SingleSelectField {
        id
        name
        options { id name }
      }
    }
  }
}
'@

    $mutationPayload = @{
        query = $mutation
        variables = @{
            fieldId = [string]$statusField.id
            options = $newOptions
        }
    } | ConvertTo-Json -Depth 12

    $null = ($mutationPayload | & gh api graphql --input -)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to add Backlog/Review options to the Status field."
    }
}

$statusMap = [ordered]@{
    "Backlog" = @(25)
    "Todo" = @(6, 11, 20, 21, 22, 24, 30, 32, 33, 34, 35, 36)
    "In Progress" = @(1, 3, 7, 8, 9, 10, 13, 14, 15, 17, 18, 19, 23, 26, 27, 28, 29, 31)
    "Review" = @(2, 4, 5, 12, 16)
}

$pullRequests = @(12, 19)

foreach ($status in $statusMap.Keys) {
    foreach ($number in $statusMap[$status]) {
        $kind = if ($pullRequests -contains $number) { "pull" } else { "issues" }
        $url = "https://github.com/Rzbck/MicroC0re/$kind/$number"

        & gh project item-add $projectNumber --owner $Owner --url $url *> $null

        Write-Host ("#{0,-2} -> {1}" -f $number, $status)
        & gh project item-edit $projectNumber --owner $Owner --url $url --field "Status" --value $status *> $null

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set #$number to '$status'."
        }
    }
}

Write-Host ""
Write-Host "Project board synchronized." -ForegroundColor Green
Write-Host "Backlog / Todo / In Progress / Review / Done are now real Status columns."
