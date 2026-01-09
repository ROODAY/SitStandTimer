# PowerShell script to bump version in pubspec.yaml
# Usage: .\bump_version.ps1 [patch|minor|major|alpha|beta|rc]
# Examples:
#   .\bump_version.ps1 alpha    # 0.1.0-alpha.1 -> 0.1.0-alpha.2
#   .\bump_version.ps1 beta     # 0.1.0-alpha.1 -> 0.1.0-beta.1
#   .\bump_version.ps1 patch    # 0.1.0 -> 0.1.1
#   .\bump_version.ps1 minor    # 0.1.0 -> 0.2.0

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("patch", "minor", "major", "alpha", "beta", "rc")]
    [string]$Type
)

$ErrorActionPreference = "Stop"

Write-Host "Reading current version from pubspec.yaml..." -ForegroundColor Cyan

# Read current version
$pubspecContent = Get-Content "pubspec.yaml" -Raw
if ($pubspecContent -match "version:\s*([^\s]+)") {
    $currentVersion = $matches[1].Trim()
    Write-Host "Current version: $currentVersion" -ForegroundColor Green
} else {
    Write-Host "ERROR: Could not find version in pubspec.yaml" -ForegroundColor Red
    exit 1
}

# Parse version
$versionParts = $currentVersion -split '-'
$baseVersion = $versionParts[0]
$preRelease = if ($versionParts.Length -gt 1) { $versionParts[1] } else { $null }

$baseParts = $baseVersion -split '\.'
$major = [int]$baseParts[0]
$minor = [int]$baseParts[1]
$patch = [int]$baseParts[2]

$newVersion = ""

switch ($Type) {
    "alpha" {
        if ($preRelease -match "^alpha\.(\d+)") {
            $alphaNum = [int]$matches[1]
            $newVersion = "$baseVersion-alpha.$($alphaNum + 1)"
        } elseif ($preRelease -match "^(beta|rc)") {
            Write-Host "ERROR: Cannot go from $preRelease to alpha. Use a new base version first." -ForegroundColor Red
            exit 1
        } else {
            $newVersion = "$baseVersion-alpha.1"
        }
    }
    "beta" {
        if ($preRelease -match "^beta\.(\d+)") {
            $betaNum = [int]$matches[1]
            $newVersion = "$baseVersion-beta.$($betaNum + 1)"
        } elseif ($preRelease -match "^rc") {
            Write-Host "ERROR: Cannot go from rc to beta. Use a new base version first." -ForegroundColor Red
            exit 1
        } else {
            # Remove alpha/rc and go to beta
            $newVersion = "$baseVersion-beta.1"
        }
    }
    "rc" {
        if ($preRelease -match "^rc\.(\d+)") {
            $rcNum = [int]$matches[1]
            $newVersion = "$baseVersion-rc.$($rcNum + 1)"
        } else {
            # Remove alpha/beta and go to rc
            $newVersion = "$baseVersion-rc.1"
        }
    }
    "patch" {
        if ($preRelease) {
            # Remove pre-release and bump patch
            $newVersion = "$major.$minor.$($patch + 1)"
        } else {
            $newVersion = "$major.$minor.$($patch + 1)"
        }
    }
    "minor" {
        if ($preRelease) {
            # Remove pre-release and bump minor
            $newVersion = "$major.$($minor + 1).0"
        } else {
            $newVersion = "$major.$($minor + 1).0"
        }
    }
    "major" {
        if ($preRelease) {
            # Remove pre-release and bump major
            $newVersion = "$($major + 1).0.0"
        } else {
            $newVersion = "$($major + 1).0.0"
        }
    }
}

# Update pubspec.yaml
$newContent = $pubspecContent -replace "version:\s*$currentVersion", "version: $newVersion"
Set-Content "pubspec.yaml" -Value $newContent -NoNewline

Write-Host "✓ Version updated: $currentVersion -> $newVersion" -ForegroundColor Green
Write-Host ""
Write-Host "Next: Run .\build_and_release.ps1 to build and release" -ForegroundColor Cyan
