#!/usr/bin/env bash
set -euo pipefail

# Importuje definicje workflow z workflows/ do działającej instancji n8n.
# Zastosowanie: świeżo postawiona instancja (nowy wolumen n8n_data), ZANIM zaimportuje
# się właściwy backup wolumenu z Drive — te JSON-y odtwarzają logikę workflow, ale nie
# credentiale (workflow po imporcie będą miały odpięte/nieistniejące credentiale, trzeba
# je podłączyć ręcznie albo odtworzyć docelowo z backupu wolumenu, który jest jedynym
# źródłem prawdy dla credentiali).
# --activeState=fromJson zachowuje stan aktywności (włączony/wyłączony) zapisany w JSON-ie.

cd "$(dirname "$0")/.."

CONTAINER=n8n
TMP_DIR=/tmp/n8n-workflow-import
IN_DIR=workflows

if ! docker inspect -f '{{.State.Running}}' "$CONTAINER" >/dev/null 2>&1; then
  echo "Błąd: kontener '$CONTAINER' nie działa. Odpal go i spróbuj ponownie." >&2
  exit 1
fi

if [ ! -d "$IN_DIR" ] || [ -z "$(find "$IN_DIR" -maxdepth 1 -name '*.json' -print -quit)" ]; then
  echo "Błąd: brak plików JSON w $IN_DIR/." >&2
  exit 1
fi

docker exec "$CONTAINER" rm -rf "$TMP_DIR"
docker exec "$CONTAINER" mkdir -p "$TMP_DIR"
docker cp "$IN_DIR/." "$CONTAINER:$TMP_DIR/"

docker exec "$CONTAINER" n8n import:workflow --separate --input "$TMP_DIR" --activeState=fromJson

docker exec "$CONTAINER" rm -rf "$TMP_DIR"

COUNT=$(find "$IN_DIR" -maxdepth 1 -name '*.json' | wc -l | tr -d ' ')
echo "Zaimportowano $COUNT workflow z $IN_DIR/."
