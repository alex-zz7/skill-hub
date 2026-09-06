#!/bin/zsh
# Capture the running Skill Hub window as a raw 2880x1800 Retina PNG and compose it into an
# App Store screenshot. Put the window on a Retina display and set up the view you want first.
#
#   scripts/capture-screenshot.sh 03-skill-detail "读、改、保存，一处完成" "预览渲染 Markdown，切到编辑直接改 SKILL.md" 0.08
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="${1:?name}"; HEADLINE="${2:?headline}"; SUBLINE="${3:-}"; HUE="${4:-0.62}"
RAW="docs/app-store/screenshots/raw/$NAME.png"
OUT="docs/app-store/screenshots/zh-Hans/$NAME.png"
mkdir -p "$(dirname "$RAW")" "$(dirname "$OUT")"

osascript -e 'tell application "Skill Hub" to activate' \
  -e 'tell application "System Events" to tell process "Skill Hub" to set size of window 1 to {1440, 900}'
sleep 1

WID=$(swift -e 'import AppKit
let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as! [[String: Any]]
for w in list where (w[kCGWindowOwnerName as String] as? String) == "Skill Hub" {
  if let b = w[kCGWindowBounds as String] as? [String: Any], (b["Height"] as? Int ?? 0) > 400, let n = w[kCGWindowNumber as String] as? Int { print(n); break }
}' 2>/dev/null)
screencapture -x -o -l "$WID" "$RAW"

SIZE=$(sips -g pixelWidth -g pixelHeight "$RAW" | awk '/pixel/ {printf "%s ", $2}')
echo "raw: $SIZE"
if [[ "$SIZE" != "2880 1800 " ]]; then
  echo "warning: expected 2880x1800 (window 1440x900 on a Retina display); App Store also accepts 1440x900, 1280x800, 2560x1600" >&2
fi

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift scripts/compose-screenshot.swift "$RAW" "$OUT" "$HEADLINE" "$SUBLINE" "$HUE"
