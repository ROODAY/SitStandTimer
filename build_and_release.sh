#!/bin/bash
# Script to build Android APK and prepare for GitHub release
# Reads version from pubspec.yaml automatically

set -e

echo "Reading version from pubspec.yaml..."

# Read version from pubspec.yaml
VERSION=$(grep -E "^version:" pubspec.yaml | sed -E 's/version:[[:space:]]*//' | tr -d '[:space:]')

if [ -z "$VERSION" ]; then
    echo "ERROR: Could not find version in pubspec.yaml"
    exit 1
fi

echo "Found version: $VERSION"

# Create git tag (v prefix)
TAG="v$VERSION"

echo ""
echo "Building Android APK for version $VERSION..."

# Build the APK
flutter build apk --release

# Create output directory
mkdir -p releases

# Copy APK to releases folder with version name
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
OUTPUT_APK="releases/uptime-${VERSION}.apk"

if [ -f "$APK_PATH" ]; then
    cp "$APK_PATH" "$OUTPUT_APK"
    FILE_SIZE=$(du -h "$OUTPUT_APK" | cut -f1)
    echo ""
    echo "✓ APK built successfully: $OUTPUT_APK"
    echo "  File size: $FILE_SIZE"
    echo ""
    echo "============================================================"
    echo "Next steps:"
    echo "============================================================"
    echo ""
    echo "1. Create and push git tag:"
    echo "   git tag $TAG"
    echo "   git push origin $TAG"
    echo ""
    echo "2. Create GitHub release:"
    echo "   https://github.com/ROODAY/SitStandTimer/releases/new"
    echo ""
    echo "   Release details:"
    echo "   - Tag: $TAG"
    echo "   - Title: Uptime $VERSION"
    echo "   - Description: Alpha release - testing phase"
    echo "   - ☑ Mark as pre-release"
    echo "   - Upload: $OUTPUT_APK"
    echo ""
    echo "3. Share the release link with your testers!"
    echo ""
else
    echo "ERROR: APK build failed!"
    exit 1
fi
