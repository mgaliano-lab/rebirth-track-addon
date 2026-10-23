#!/usr/bin/env bash
# Sube el zip del addon a CurseForge (proyecto 1757092) con lo de «Para todos» de CHANGELOG.md como notas.
# Las versiones del juego salen de "## Interface:" del .toc (120001 → 12.0.1, 20505 → 2.5.5…) y se
# buscan en la API de CurseForge; las que todavía no existan allá se saltean con un aviso.
#   CF_API_TOKEN=… scripts/curseforge.sh dist/RebirthTrack-0.0.8.zip
set -euo pipefail
cd "$(dirname "$0")/.."
ZIP="${1:?zip}"
: "${CF_API_TOKEN:?falta CF_API_TOKEN (token de https://legacy.curseforge.com/account/api-tokens)}"
PROJECT_ID="${CF_PROJECT_ID:-1757092}"
API=https://wow.curseforge.com/api

TOC=RebirthTrack/RebirthTrack.toc
VERSION=$(sed -n 's/^## Version: *//p' "$TOC" | tr -d '\r')
INTERFACES=$(sed -n 's/^## Interface: *//p' "$TOC" | tr -d '\r ')

# 120001 → 12.0.1 · 50501 → 5.5.1 · 11508 → 1.15.8 · 16001 → 1.60.1 (WoW Forever: en CurseForge es
# el tipo «WoW Forever», con la versión 1.60.1; ver el workflow curseforge-versions).
names=$(echo "$INTERFACES" | tr ',' '\n' | awk '{ n = $1 + 0; printf "%d.%d.%d\n", int(n / 10000), int(n / 100) % 100, n % 100 }')
versions=$(curl -sS --fail-with-body -H "X-Api-Token: $CF_API_TOKEN" "$API/game/versions")
ids=$(jq -n --argjson all "$versions" --arg names "$names" '
  ($names | split("\n") | map(select(length > 0))) as $want
  | [$all[] | select(.name as $n | $want | index($n)) | .id] | unique')
for n in $names; do
  jq -e --arg n "$n" 'any(.[]; .name == $n)' <<<"$versions" >/dev/null || echo "aviso: CurseForge todavía no tiene la versión $n; se omite" >&2
done
[[ $(jq length <<<"$ids") -gt 0 ]] || { echo "ninguna versión del juego reconocida por CurseForge: $names" >&2; exit 1; }

metadata=$(jq -n --arg log "$(scripts/changelog-section.sh "$VERSION" public)" --arg name "$VERSION" --argjson ids "$ids" \
  '{ changelog: $log, changelogType: "markdown", displayName: $name, gameVersions: $ids, releaseType: "release" }')
curl -sS --fail-with-body -X POST -H "X-Api-Token: $CF_API_TOKEN" \
  --form-string "metadata=$metadata" -F "file=@$ZIP" \
  "$API/projects/$PROJECT_ID/upload-file"
echo
echo "Subido a CurseForge: Rebirth Track $VERSION"
