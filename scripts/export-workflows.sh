#!/usr/bin/env bash
set -euo pipefail

# Eksportuje definicje wszystkich workflow z działającej instancji n8n do workflows/ w repo.
# Pełny sync: katalog workflows/ jest za każdym razem nadpisywany, więc usunięty w n8n
# workflow zniknie też z repo (i będzie widoczny jako delete w `git status`).
# Nie dotyka credentiali (export:workflow eksportuje tylko referencje {id, name} do nich,
# nigdy sekretów) ani bazy SQLite — to osobna warstwa od pełnego backupu wolumenu na Drive.

cd "$(dirname "$0")/.."

CONTAINER=n8n
TMP_DIR=/tmp/n8n-workflow-export
OUT_DIR=workflows

if ! docker inspect -f '{{.State.Running}}' "$CONTAINER" >/dev/null 2>&1; then
  echo "Błąd: kontener '$CONTAINER' nie działa. Odpal go i spróbuj ponownie." >&2
  exit 1
fi

docker exec "$CONTAINER" rm -rf "$TMP_DIR"
docker exec "$CONTAINER" mkdir -p "$TMP_DIR"
docker exec "$CONTAINER" n8n export:workflow --all --separate --pretty --output "$TMP_DIR"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
docker cp "$CONTAINER:$TMP_DIR/." "$OUT_DIR/"
docker exec "$CONTAINER" rm -rf "$TMP_DIR"

COUNT=$(find "$OUT_DIR" -maxdepth 1 -name '*.json' | wc -l | tr -d ' ')
echo "Wyeksportowano $COUNT workflow do $OUT_DIR/"
