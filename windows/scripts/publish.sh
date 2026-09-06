#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export PATH="${DOTNET_ROOT:-$HOME/.dotnet}:$PATH"
rid="${1:-win-x64}"
out="$root/dist/${rid}"
rm -rf "$out"
dotnet publish "$root/windows/src/SkillHub.App/SkillHub.App.csproj" \
  -c Release \
  -r "$rid" \
  --self-contained true \
  -p:PublishSingleFile=false \
  -p:IncludeNativeLibrariesForSelfExtract=true \
  -p:EnableWindowsTargeting=true \
  -o "$out"
(cd "$root/dist" && zip -qr "SkillHub-${rid}.zip" "$(basename "$out")")
echo "Packed $root/dist/SkillHub-${rid}.zip"
