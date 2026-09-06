#!/bin/zsh
# Regenerate the Xcode project, build a Debug app signed with your Apple Development
# certificate (the sandbox only works when the binary is signed), and launch it.
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
cd "$(dirname "$0")/.."

xcodegen generate
xcodebuild \
  -project SkillHub.xcodeproj \
  -scheme SkillHub \
  -configuration Debug \
  -derivedDataPath ./DerivedData \
  -quiet \
  build

open "./DerivedData/Build/Products/Debug/Skill Hub.app"
