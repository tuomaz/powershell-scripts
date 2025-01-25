<#
.SYNOPSIS
    Move files from a source folder to a destination folder if they are older than a specified number of days.

.DESCRIPTION
    This script will move files from a source folder to a destination folder if they are older than a specified number of days.
    If they exist on the destination folder, the local copy will be deleted.
    Addionatially, a SimplePush notification will be sent if a SimplePush key is provided.

.PARAMETER SourcePath
    Path to the source folder where the files are located.

.PARAMETER DestinationPath
    Path to the destination folder where the files will be moved.

.PARAMETER Days
    Number of days to check for old files. Default is 7 days.
 
.PARAMETER SimplePushKey
    SimplePush key to use for sending notifications. If not provided, no notification will be sent.    

.EXAMPLE
    PS> .\MoveFiles.ps1 -SourcePath "C:\Temp\Source" -DestinationPath "C:\Temp\Destination" -Days 30

.NOTES
    Author:       Fredrik Tuomas
    Created:          2025-01-25
    Latest update: 2025-01-25
    Version:         1.0
    Comments:       added SimplePush notification

.LINK
    https://github.com/tuomaz/powershell-scripts
#>

param(
    [string]$SourcePath,
    [string]$DestinationPath,
    [string]$SimplePushKey = "",
    [int]$Days = 7 
)

if (-not $SourcePath -or -not $DestinationPath) {
    Write-Error "You need to supply both SourcePath and DestinationPath parameters."
    exit 1
}

if (-not (Test-Path -Path $SourcePath)) {
    Write-Error "SourcePath ($SourcePath) doesn't exists. Exiting."
    exit 1
}

if (-not (Test-Path -Path $DestinationPath)) {
    Write-Error "DestinationPath ($DestinationPath) doesn't exists. Exiting."
    exit 1
}

$cutoffDate = (Get-Date).AddDays(-$Days)
$files = Get-ChildItem -Path $SourcePath -File | Where-Object { $_.CreationTime -lt $cutoffDate }

if ($files.Count -eq 0) {
    Write-Host "No files older than $Days days found in $SourcePath. Exiting."
    exit 0
}

$moveCount = 0
foreach ($f in $files) {
    try {
        if (Test-Path -Path $DestinationPath\$($f.Name)) {
            Write-Host "Destination path $f exist. Deleting local copy!."
            Remove-Item -Path $f.FullName -Force
        } else {
            Move-Item -Path $f.FullName -Destination "$DestinationPath\$($f.Name)"
            $moveCount++
        }
    } catch [System.IO.IOException] {
        Write-Error "Failed to move file $($f.FullName). Error: $_"
    }
}

Write-Host "Moved $moveCount files from $SourcePath to $DestinationPath."

if (-not $simplePushKey) {
    Write-Host "No SimplePush key provided. Skipping notification."
    exit 0
}

$timestamp = Get-Date -Format "yyyy-dd-MM HH.mm.ss"
$computerName = (Get-ComputerInfo).CsName
$uri = "https://simplepu.sh"

$body = @{
    key = "$simplePushKey"
    msg = "$moveCount old files moved on $computerName ($timestamp)"
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json"