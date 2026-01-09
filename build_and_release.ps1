# PowerShell script to build Android APK and prepare for GitHub release
# Reads version from pubspec.yaml automatically

$ErrorActionPreference = "Stop"

Write-Host "Reading version from pubspec.yaml..." -ForegroundColor Cyan

# Read version from pubspec.yaml
$pubspecContent = Get-Content "pubspec.yaml" -Raw
if ($pubspecContent -match "version:\s*([^\s]+)") {
    $version = $matches[1].Trim()
    Write-Host "Found version: $version" -ForegroundColor Green
} else {
    Write-Host "ERROR: Could not find version in pubspec.yaml" -ForegroundColor Red
    exit 1
}

# Create git tag (v prefix)
$tag = "v$version"

Write-Host "`nBuilding Android APK for version $version..." -ForegroundColor Cyan

# Build the APK
flutter build apk --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: APK build failed!" -ForegroundColor Red
    exit 1
}

# Create output directory
if (-not (Test-Path "releases")) {
    New-Item -ItemType Directory -Path "releases" | Out-Null
}

# Copy APK to releases folder with version name
$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
$outputApk = "releases\uptime-$version.apk"

if (Test-Path $apkPath) {
    Copy-Item $apkPath $outputApk -Force
    Write-Host "`n✓ APK built successfully: $outputApk" -ForegroundColor Green
    
    # Get file size
    $fileSize = (Get-Item $outputApk).Length / 1MB
    Write-Host "  File size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Gray
    
    Write-Host "`n" + ("="*60) -ForegroundColor Cyan
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host ("="*60) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Create and push git tag:" -ForegroundColor White
    Write-Host "   git tag $tag" -ForegroundColor Gray
    Write-Host "   git push origin $tag" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Create GitHub release:" -ForegroundColor White
    Write-Host "   https://github.com/ROODAY/SitStandTimer/releases/new" -ForegroundColor Blue
    Write-Host ""
    Write-Host "   Release details:" -ForegroundColor White
    Write-Host "   - Tag: $tag" -ForegroundColor Gray
    Write-Host "   - Title: Uptime $version" -ForegroundColor Gray
    Write-Host "   - Description: Alpha release - testing phase" -ForegroundColor Gray
    Write-Host "   - ☑ Mark as pre-release" -ForegroundColor Gray
    Write-Host "   - Upload: $outputApk" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Share the release link with your testers!" -ForegroundColor White
    Write-Host ""
    
} else {
    Write-Host "ERROR: APK not found at $apkPath" -ForegroundColor Red
    exit 1
}
