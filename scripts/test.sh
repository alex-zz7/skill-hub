#!/bin/zsh
# Run the unit tests.
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
cd "$(dirname "$0")/.."

xcodegen generate
xcodebuild \
  -project SkillHub.xcodeproj \
  -scheme SkillHub \
  -destination 'platform=macOS' \
  -derivedDataPath ./DerivedData \
  -quiet \
  test
