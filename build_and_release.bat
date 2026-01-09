@echo off
REM Script to build Android APK and prepare for GitHub release
REM Reads version from pubspec.yaml automatically
REM Note: For better functionality, use build_and_release.ps1 instead

setlocal enabledelayedexpansion

echo Reading version from pubspec.yaml...

REM Read version from pubspec.yaml (simple grep-like approach)
for /f "tokens=2" %%a in ('findstr /r /c:"^version:" pubspec.yaml') do set VERSION=%%a

if "%VERSION%"=="" (
    echo ERROR: Could not find version in pubspec.yaml
    exit /b 1
)

echo Found version: %VERSION%

REM Create git tag (v prefix)
set TAG=v%VERSION%

echo.
echo Building Android APK for version %VERSION%...

REM Build the APK
flutter build apk --release

if errorlevel 1 (
    echo ERROR: APK build failed!
    exit /b 1
)

REM Create output directory
if not exist releases mkdir releases

REM Copy APK to releases folder with version name
set APK_PATH=build\app\outputs\flutter-apk\app-release.apk
set OUTPUT_APK=releases\uptime-%VERSION%.apk

if exist "%APK_PATH%" (
    copy "%APK_PATH%" "%OUTPUT_APK%" >nul
    echo.
    echo ✓ APK built successfully: %OUTPUT_APK%
    echo.
    echo ============================================================
    echo Next steps:
    echo ============================================================
    echo.
    echo 1. Create and push git tag:
    echo    git tag %TAG%
    echo    git push origin %TAG%
    echo.
    echo 2. Create GitHub release:
    echo    https://github.com/ROODAY/SitStandTimer/releases/new
    echo.
    echo    Release details:
    echo    - Tag: %TAG%
    echo    - Title: Uptime %VERSION%
    echo    - Description: Alpha release - testing phase
    echo    - ☑ Mark as pre-release
    echo    - Upload: %OUTPUT_APK%
    echo.
    echo 3. Share the release link with your testers!
    echo.
) else (
    echo ERROR: APK not found at %APK_PATH%
    exit /b 1
)

endlocal
