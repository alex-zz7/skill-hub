#!/bin/zsh
# Archive a Release build and export a Mac App Store package (.pkg) ready for Transporter /
# App Store Connect. Requires an "Apple Distribution" certificate in your keychain; Xcode's
# automatic signing (-allowProvisioningUpdates) creates the Mac App Store provisioning profile.
#
#   scripts/archive.sh            # archive + export to build/export
#   scripts/archive.sh --upload   # additionally upload with `xcrun altool` using an App Store Connect API key
#
# For --upload set: ASC_KEY_ID, ASC_ISSUER_ID and put the .p8 key at ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
cd "$(dirname "$0")/.."

ARCHIVE_PATH="build/SkillHub.xcarchive"
EXPORT_PATH="build/export"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

xcodegen generate
xcodebuild \
  -project SkillHub.xcodeproj \
  -scheme SkillHub \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  -quiet \
  archive

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist scripts/ExportOptions.plist \
  -exportPath "$EXPORT_PATH" \
  -allowProvisioningUpdates \
  -quiet

echo "Exported:"
ls -la "$EXPORT_PATH"

if [[ "${1:-}" == "--upload" ]]; then
  : "${ASC_KEY_ID:?set ASC_KEY_ID}"
  : "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"
  PKG=$(ls "$EXPORT_PATH"/*.pkg | head -n 1)
  xcrun altool --upload-app --type macos --file "$PKG" --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
fi
