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

# Sanityzacja: n8n wpisuje w każdy plik prawdziwy email właściciela projektu
# (pole shared[].project.name) — zamieniamy go na placeholder, żeby eksport
# był bezpieczny do publikacji/publicznego repo bez ręcznej redakcji.
OWNER_PATTERN='Krzysztof Strand <codecollabsql@gmail.com>'
if grep -rl "$OWNER_PATTERN" "$OUT_DIR"/*.json >/dev/null 2>&1; then
  sed -i '' "s/$OWNER_PATTERN/Personal <redacted@example.com>/g" "$OUT_DIR"/*.json
fi

COUNT=$(find "$OUT_DIR" -maxdepth 1 -name '*.json' | wc -l | tr -d ' ')
echo "Wyeksportowano $COUNT workflow do $OUT_DIR/"

# Ostrzeżenie (nie blokuje): inne kategorie danych, których nie da się bezpiecznie
# zautomatyzować (dowolne przyszłe typy zasobów) — sprawdź ręcznie przed commitem/publikacją.
HITS=$(grep -lE 'docs\.google\.com/spreadsheets|drive\.google\.com/drive/folders|airtable\.com/app[A-Za-z0-9]+' "$OUT_DIR"/*.json 2>/dev/null || true)
if [ -n "$HITS" ]; then
  echo "UWAGA: znaleziono zahardkodowane linki do realnych zasobów Google/Airtable w:" >&2
  echo "$HITS" >&2
  echo "Sprawdź ręcznie przed commitem, czy to bezpieczne do publikacji (patrz CLAUDE.md)." >&2
fi
