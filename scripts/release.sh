#!/usr/bin/env bash
# Empaqueta el addon y lo publica en el CDN (ast.rebirthknights.fun/addon/), de donde lo descarga
# la pantalla de Raids. La versión sale de "## Version:" del .toc; una versión publicada no se pisa.
#   scripts/release-addon.sh            → arma y sube
#   scripts/release-addon.sh --dry-run  → solo arma los zip en addon/dist
set -euo pipefail
cd "$(dirname "$0")/.."

BUCKET=rebirthknights-assets
DIST_ID=E360BSSXQTTMVZ
CDN=https://ast.rebirthknights.fun
export AWS_PROFILE=mgaliano

TOC=RebirthTrack/RebirthTrack.toc
VERSION=$(sed -n 's/^## Version: *//p' "$TOC" | tr -d '\r')
INTERFACES=$(sed -n 's/^## Interface: *//p' "$TOC" | tr -d '\r ')
[[ -n "$VERSION" ]] || { echo "No encontré '## Version:' en $TOC" >&2; exit 1; }

OUT=dist
ADDON_ZIP="RebirthTrack-$VERSION.zip"          # listo para instalar: RebirthTrack/ en la raíz
TOOLS_ZIP="RebirthTrack-tools-$VERSION.zip"     # guía + herramientas de medición (F0)
rm -rf "$OUT" && mkdir -p "$OUT"
(zip -qrX "$OUT/$ADDON_ZIP" RebirthTrack -x '*.DS_Store' 'RebirthTrack/Plans.lua') # Plans.lua lo escribe la app
(zip -qrX "$OUT/$TOOLS_ZIP" README.md tools -x '*.DS_Store')

SIZE=$(stat -f%z "$OUT/$ADDON_ZIP" 2>/dev/null || stat -c%s "$OUT/$ADDON_ZIP")
SHA=$(shasum -a 256 "$OUT/$ADDON_ZIP" | cut -d' ' -f1)
cat > "$OUT/latest.json" <<JSON
{
  "version": "$VERSION",
  "interfaces": "$INTERFACES",
  "file": "$ADDON_ZIP",
  "url": "$CDN/addon/$ADDON_ZIP",
  "size": $SIZE,
  "sha256": "$SHA",
  "toolsUrl": "$CDN/addon/$TOOLS_ZIP",
  "publishedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSON
echo "Armado $OUT/$ADDON_ZIP ($SIZE bytes) y $OUT/$TOOLS_ZIP"
[[ "${1:-}" == "--dry-run" ]] && exit 0

if aws s3api head-object --bucket "$BUCKET" --key "addon/$ADDON_ZIP" >/dev/null 2>&1; then
  echo "La versión $VERSION ya está publicada: subí '## Version:' en $TOC" >&2; exit 1
fi
# Los zip versionados no cambian nunca; latest.json se refresca enseguida.
for f in "$ADDON_ZIP" "$TOOLS_ZIP"; do
  aws s3 cp --only-show-errors "$OUT/$f" "s3://$BUCKET/addon/$f" \
    --content-type application/zip --cache-control "public, max-age=31536000, immutable" \
    --content-disposition "attachment; filename=\"$f\""
done
aws s3 cp --only-show-errors "$OUT/latest.json" "s3://$BUCKET/addon/latest.json" \
  --content-type application/json --cache-control "public, max-age=60"
aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths /addon/latest.json --query Invalidation.Id --output text
echo "Publicado: $CDN/addon/$ADDON_ZIP"
