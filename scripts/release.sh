#!/usr/bin/env bash
# Empaqueta el addon y lo publica en el CDN (ast.rebirthknights.fun/addon/), de donde lo descarga
# la pantalla de Raids. La versión sale de "## Version:" del .toc; una versión publicada no se pisa.
#   scripts/release.sh            → arma y sube (latest.json: lo baja la app de todos)
#   scripts/release.sh --beta     → versión de prueba: sube el zip y beta.json, que solo le toca a la
#                                   app de los que prueban (admins y GM; ver shared/addonChannel.ts del sitio)
#   scripts/release.sh --dry-run  → solo arma los zip en addon/dist
# Si la versión ya se subió como prueba, el release no la vuelve a armar: pasa a latest.json el mismo
# zip que ya bajaron los que probaron.
set -euo pipefail
cd "$(dirname "$0")/.."

BUCKET=rebirthknights-assets
DIST_ID=E360BSSXQTTMVZ
CDN=https://ast.rebirthknights.fun
# Local: perfil mgaliano. En CI vienen las claves del usuario rebirthknights-addon-ci por env.
[[ -n "${AWS_ACCESS_KEY_ID:-}" ]] || export AWS_PROFILE=mgaliano

CHANNEL=latest
[[ "${1:-}" == "--beta" ]] && CHANNEL=beta
TOC=RebirthTrack/RebirthTrack.toc
VERSION=$(sed -n 's/^## Version: *//p' "$TOC" | tr -d '\r')
INTERFACES=$(sed -n 's/^## Interface: *//p' "$TOC" | tr -d '\r ')
[[ -n "$VERSION" ]] || { echo "No encontré '## Version:' en $TOC" >&2; exit 1; }

OUT=dist
ADDON_ZIP="RebirthTrack-$VERSION.zip"          # listo para instalar: RebirthTrack/ en la raíz
TOOLS_ZIP="RebirthTrack-tools-$VERSION.zip"     # guía + herramientas de medición (F0)
rm -rf "$OUT" && mkdir -p "$OUT"
(zip -qrX "$OUT/$ADDON_ZIP" RebirthTrack -x '*.DS_Store') # Plans.lua va vacío: lo reemplaza la app
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

publish_json() { # $1 = archivo local, $2 = latest | beta
  aws s3 cp --only-show-errors "$1" "s3://$BUCKET/addon/$2.json" \
    --content-type application/json --cache-control "public, max-age=60"
  aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/addon/$2.json" --query Invalidation.Id --output text
}
if aws s3api head-object --bucket "$BUCKET" --key "addon/$ADDON_ZIP" >/dev/null 2>&1; then
  # Ya está subida: solo vale pasar a release la que se subió como prueba.
  if [[ "$CHANNEL" == latest ]] && aws s3 cp --only-show-errors "s3://$BUCKET/addon/beta.json" "$OUT/beta.json" 2>/dev/null \
    && grep -q "\"version\": \"$VERSION\"" "$OUT/beta.json"; then
    sed "s/\"publishedAt\": \"[^\"]*\"/\"publishedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"/" "$OUT/beta.json" > "$OUT/latest.json"
    publish_json "$OUT/latest.json" latest
    echo "Pasó a release el zip de prueba: $CDN/addon/$ADDON_ZIP"
    exit 0
  fi
  echo "La versión $VERSION ya está publicada: subí '## Version:' en $TOC" >&2; exit 1
fi
# Los zip versionados no cambian nunca; latest.json se refresca enseguida.
for f in "$ADDON_ZIP" "$TOOLS_ZIP"; do
  aws s3 cp --only-show-errors "$OUT/$f" "s3://$BUCKET/addon/$f" \
    --content-type application/zip --cache-control "public, max-age=31536000, immutable" \
    --content-disposition "attachment; filename=\"$f\""
done
publish_json "$OUT/latest.json" "$CHANNEL"
echo "Publicado ($CHANNEL): $CDN/addon/$ADDON_ZIP"
