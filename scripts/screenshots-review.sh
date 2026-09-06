#!/bin/zsh
# Build a single-page HTML gallery of the composed screenshots for a human sign-off before upload,
# and print each file's size and SHA-256 so the upload can be verified against App Store Connect.
#
#   scripts/screenshots-review.sh [locale]     # default zh-Hans; opens the page in your browser
set -euo pipefail
cd "$(dirname "$0")/.."
LOCALE="${1:-zh-Hans}"
DIR="docs/app-store/screenshots/$LOCALE"
OUT="docs/app-store/screenshots/review-$LOCALE.html"

{
  cat <<'HTML'
<!doctype html><meta charset="utf-8"><title>Skill Hub screenshots review</title>
<style>
body{font:15px -apple-system,system-ui;margin:32px;background:#f5f5f7;color:#1d1d1f}
h1{font-size:22px}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(560px,1fr));gap:28px}
figure{margin:0;background:#fff;border-radius:12px;padding:14px;box-shadow:0 1px 3px rgba(0,0,0,.1)}
img{width:100%;border-radius:8px;display:block}figcaption{margin-top:10px;font-size:13px;color:#555;font-family:ui-monospace,Menlo}
.thumb{width:160px;float:right;margin-left:12px;border:1px solid #ddd}
</style>
HTML
  echo "<h1>Skill Hub · $LOCALE · $(date '+%Y-%m-%d %H:%M')</h1>"
  echo "<p>Order below is the App Store order. Check: headline readable at thumbnail size (small copy on the right), no truncated UI text, nothing personal visible, all 2880×1800.</p><div class=grid>"
  for f in "$DIR"/*.png; do
    name=$(basename "$f"); size=$(sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/ {printf "%s×", $2}' | sed 's/×$//')
    sha=$(shasum -a 256 "$f" | cut -c1-16)
    echo "<figure><img class=thumb src=\"$LOCALE/$name\"><img src=\"$LOCALE/$name\"><figcaption>$name · $size · sha256 $sha…</figcaption></figure>"
  done
  echo "</div>"
} > "$OUT"

echo "checksums (compare with: asc screenshots list --version-localization <ID> --output json | jq '.data[].attributes.sourceFileChecksum')"
shasum -a 256 "$DIR"/*.png
echo "review page: $OUT"
open "$OUT"
