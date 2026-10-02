param(
    [string]$ProjectTitle = "MicroC0re",
    [string]$Owner = "@me"
)

$ErrorActionPreference = "Stop"

trap {
    Write-Host ""
    Write-Host "PROJECT SYNC FAILED" -ForegroundColor Red
    Write-Error $_
    exit 1
}

function Invoke-GhText {
    param([Parameter(Mandatory = $true)][string[]]$Args)

    $lines = @(& gh @Args 2>&1)
    $exitCode = $LASTEXITCODE
    $text = ($lines | ForEach-Object { "$_" }) -join [Environment]::NewLine

    if ($exitCode -ne 0) {
        throw ("gh failed ({0}): gh {1}{2}{3}" -f $exitCode, ($Args -join " "), [Environment]::NewLine, $text)
    }

    return $text
}

function ConvertFrom-GhJsonText {
    param([Parameter(Mandatory = $true)][string]$Text)

    $objectStart = $Text.IndexOf("{")
    $arrayStart = $Text.IndexOf("[")

    if ($objectStart -lt 0) {
        $start = $arrayStart
    }
    elseif ($arrayStart -lt 0) {
        $start = $objectStart
    }
    else {
        $start = [Math]::Min($objectStart, $arrayStart)
    }

    if ($start -lt 0) {
        throw ("gh did not return JSON. Raw output:{0}{1}" -f [Environment]::NewLine, $Text)
    }

    $trimmed = $Text.Substring($start)
    $lastObject = $trimmed.LastIndexOf("}")
    $lastArray = $trimmed.LastIndexOf("]")
    $end = [Math]::Max($lastObject, $lastArray)

    if ($end -lt 0) {
        throw ("Incomplete JSON returned by gh. Raw output:{0}{1}" -f [Environment]::NewLine, $Text)
    }

    $json = $trimmed.Substring(0, $end + 1)

    try {
        return ($json | ConvertFrom-Json)
    }
    catch {
        throw ("Unable to parse gh JSON.{0}Raw output:{0}{1}{0}JSON candidate:{0}{2}" -f [Environment]::NewLine, $Text, $json)
    }
}

function Invoke-GhJson {
    param([Parameter(Mandatory = $true)][string[]]$Args)
    return ConvertFrom-GhJsonText -Text (Invoke-GhText -Args $Args)
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI (gh) is not installed."
}

& gh auth status *> $null
if ($LASTEXITCODE -ne 0) {
    throw "GitHub CLI is not authenticated."
}

$projects = Invoke-GhJson -Args @(
    "project", "list",
    "--owner", $Owner,
    "--format", "json"
)

$project = @($projects.projects) |
    Where-Object { $_.title -eq $ProjectTitle } |
    Select-Object -First 1

if (-not $project) {
    throw "Project '$ProjectTitle' not found for owner '$Owner'."
}

$projectNumber = [int]$project.number

$projectInfo = Invoke-GhJson -Args @(
    "project", "view", "$projectNumber",
    "--owner", $Owner,
    "--format", "json"
)

$projectId = [string]$projectInfo.id
if ([string]::IsNullOrWhiteSpace($projectId)) {
    throw "Unable to resolve the Project V2 node ID."
}

Write-Host ""
Write-Host "Project: $ProjectTitle (#$projectNumber)" -ForegroundColor Cyan
Write-Host "Project ID: $projectId" -ForegroundColor DarkGray

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

function Get-StatusField {
    param([string]$ProjectNodeId)

    $payload = @{
        query = $fieldQuery
        variables = @{
            projectId = $ProjectNodeId
        }
    } | ConvertTo-Json -Depth 12

    $raw = @($payload | & gh api graphql --input - 2>&1)
    $exitCode = $LASTEXITCODE
    $text = ($raw | ForEach-Object { "$_" }) -join [Environment]::NewLine

    if ($exitCode -ne 0) {
        throw ("Unable to read GitHub Project fields.{0}{1}" -f [Environment]::NewLine, $text)
    }

    $result = ConvertFrom-GhJsonText -Text $text
    $field = @($result.data.node.fields.nodes) |
        Where-Object { $_.name -eq "Status" } |
        Select-Object -First 1

    if (-not $field) {
        throw "The project has no single-select field named 'Status'."
    }

    return $field
}

$statusField = Get-StatusField -ProjectNodeId $projectId

$desiredOptions = @(
    @{ name = "Backlog"; color = "GRAY"; description = "Gated or later work" },
    @{ name = "Todo"; color = "GREEN"; description = "Ready but not started" },
    @{ name = "In Progress"; color = "YELLOW"; description = "Actively being worked on" },
    @{ name = "Review"; color = "PURPLE"; description = "Implemented; awaiting validation/review" },
    @{ name = "Done"; color = "BLUE"; description = "Completed" }
)

$existingByName = @{}
foreach ($option in @($statusField.options)) {
    $existingByName[[string]$option.name] = $option
}

$missingNames = @(
    $desiredOptions |
    Where-Object { -not $existingByName.ContainsKey($_.name) } |
    ForEach-Object { $_.name }
)

if ($missingNames.Count -gt 0) {
    Write-Host "Adding Status options: $($missingNames -join ', ')" -ForegroundColor Yellow

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
            $newOptions += @{
                name = [string]$desired.name
                color = [string]$desired.color
                description = [string]$desired.description
            }
        }
    }

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
        options {
          id
          name
        }
      }
    }
  }
}
'@

    $payload = @{
        query = $mutation
        variables = @{
            fieldId = [string]$statusField.id
            options = $newOptions
        }
    } | ConvertTo-Json -Depth 20

    $raw = @($payload | & gh api graphql --input - 2>&1)
    $exitCode = $LASTEXITCODE
    $text = ($raw | ForEach-Object { "$_" }) -join [Environment]::NewLine

    if ($exitCode -ne 0) {
        throw ("Unable to update Status options.{0}{1}" -f [Environment]::NewLine, $text)
    }

    $null = ConvertFrom-GhJsonText -Text $text
    $statusField = Get-StatusField -ProjectNodeId $projectId
}

$actualOptions = @($statusField.options | ForEach-Object { [string]$_.name })
foreach ($required in @("Backlog", "Todo", "In Progress", "Review", "Done")) {
    if ($actualOptions -notcontains $required) {
        throw "Status option '$required' is still missing after configuration."
    }
}

$statusOptionIdByName = @{}
foreach ($option in @($statusField.options)) {
    $statusOptionIdByName[[string]$option.name] = [string]$option.id
}

$statusMap = [ordered]@{
    "Backlog" = @(25)
    "Todo" = @(6, 11, 20, 21, 22, 24, 30, 32, 33, 34, 35, 36)
    "In Progress" = @(1, 3, 7, 8, 9, 10, 13, 14, 15, 17, 18, 19, 23, 26, 27, 28, 29, 31)
    "Review" = @(2, 4, 5, 12, 16)
}

$pullRequests = @(12, 19)

Write-Host ""
Write-Host "Synchronizing cards..." -ForegroundColor Cyan

foreach ($status in $statusMap.Keys) {
    $optionId = [string]$statusOptionIdByName[$status]

    if ([string]::IsNullOrWhiteSpace($optionId)) {
        throw "No option ID found for Status '$status'."
    }

    foreach ($number in $statusMap[$status]) {
        $kind = if ($pullRequests -contains $number) { "pull" } else { "issues" }
        $url = "https://github.com/Rzbck/MicroC0re/$kind/$number"

        # item-add is used as the reliable way to resolve the ProjectV2 item ID.
        # On existing items GitHub CLI returns the project item rather than
        # requiring us to scrape the board separately.
        $addRaw = Invoke-GhText -Args @(
            "project", "item-add", "$projectNumber",
            "--owner", $Owner,
            "--url", $url,
            "--format", "json"
        )
        $projectItem = ConvertFrom-GhJsonText -Text $addRaw
        $itemId = [string]$projectItem.id

        if ([string]::IsNullOrWhiteSpace($itemId)) {
            throw "Unable to resolve Project item ID for #$number ($url)."
        }

        Write-Host ("#{0,-2} -> {1}" -f $number, $status)

        $editRaw = Invoke-GhText -Args @(
            "project", "item-edit",
            "--id", $itemId,
            "--project-id", $projectId,
            "--field-id", ([string]$statusField.id),
            "--single-select-option-id", $optionId,
            "--format", "json"
        )

        $null = ConvertFrom-GhJsonText -Text $editRaw
    }
}

Write-Host ""
Write-Host "Board after sync:" -ForegroundColor Cyan

$listRaw = Invoke-GhText -Args @(
    "project", "item-list", "$projectNumber",
    "--owner", $Owner,
    "--limit", "200",
    "--format", "json"
)
$list = ConvertFrom-GhJsonText -Text $listRaw

$rows = @(
    foreach ($item in @($list.items)) {
        $number = $null
        $type = $null
        $url = $null

        if ($null -ne $item.content) {
            $number = $item.content.number
            $type = $item.content.type
            $url = $item.content.url
        }

        [PSCustomObject]@{
            Number = $number
            Type = $type
            Status = $item.status
            Title = $item.title
            URL = $url
        }
    }
)

$rows |
    Sort-Object Status, Number |
    Format-Table Number, Type, Status, Title -AutoSize |
    Out-Host

$expectedCount = 0
foreach ($status in $statusMap.Keys) {
    $expectedCount += @($statusMap[$status]).Count
}

if (@($rows).Count -lt $expectedCount) {
    Write-Host (
        "Warning: board lists {0} items; expected at least {1} mapped items." -f
        @($rows).Count,
        $expectedCount
    ) -ForegroundColor Yellow
}

Write-Host ""
Write-Host "PROJECT SYNC PASS" -ForegroundColor Green
Write-Host "Backlog / Todo / In Progress / Review / Done are real Project Status columns."`nWrite-Host "Project items were updated through ProjectV2 item/field/option IDs."
exit 0
