#!/usr/bin/env bash
# Imprime la sección de CHANGELOG.md de una versión (sin el título). Falla si no existe:
# así no se publica una versión sin decir qué trae.
#   scripts/changelog.sh 0.0.8
set -euo pipefail
cd "$(dirname "$0")/.."
v="${1:?versión}"
out=$(awk -v v="$v" '
  $0 ~ "^## " { if (on) exit; on = ($2 == v); next }
  on { print }
' CHANGELOG.md | sed -e '/./,$!d')
[[ -n "${out//[$'\n ']/}" ]] || { echo "CHANGELOG.md no tiene la sección '## $v'" >&2; exit 1; }
printf '%s\n' "$out"
