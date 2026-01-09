# Uptime

A simple sit/stand timer app for Android and iOS.

## Building and Releasing

### Single Source of Truth
The version is defined **once** in `pubspec.yaml`. All builds, tags, and releases use this version automatically.

### Quick Release Workflow

1. **Update version** (if needed):
   ```powershell
   .\bump_version.ps1 alpha    # For alpha releases
   .\bump_version.ps1 beta     # For beta releases
   .\bump_version.ps1 patch    # For patch releases
   ```

2. **Build and prepare release**:
   ```powershell
   .\build_and_release.ps1
   ```
   This will:
   - Read version from `pubspec.yaml`
   - Build the Android APK
   - Show you the exact commands to create the GitHub release

3. **Create GitHub release**:
   - Follow the instructions shown by the script
   - Upload the APK from the `releases/` folder
   - Mark as pre-release for alpha/beta versions

### Version Bumping

The `bump_version.ps1` script helps increment versions:
- `alpha` - Increment alpha version (0.1.0-alpha.1 → 0.1.0-alpha.2)
- `beta` - Move to beta (0.1.0-alpha.1 → 0.1.0-beta.1)
- `rc` - Move to release candidate (0.1.0-beta.1 → 0.1.0-rc.1)
- `patch` - Bump patch version (0.1.0 → 0.1.1)
- `minor` - Bump minor version (0.1.0 → 0.2.0)
- `major` - Bump major version (0.1.0 → 1.0.0)

### Manual Version Update

Just edit `version:` in `pubspec.yaml` - the build scripts will automatically use it.
