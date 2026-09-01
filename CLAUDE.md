# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Czym jest to repo

Scaffold Docker Compose dla lokalnej instancji **n8n** — to nie jest kodowa aplikacja. Nie ma tu build/lint/testów; jedynym "kodem" są `docker-compose.yml` i `.env`. Instancja to pojedynczy kontener n8n z wbudowaną bazą SQLite (bez Postgresa, bez trybu queue/workerów) — cały stan (workflow, credentiale, ustawienia) siedzi w wolumenie `n8n_data`. Same workflow (nody, połączenia, credentiale) żyją wewnątrz działającej instancji, nie jako pliki w tym repo — edytuj je na żywo przez narzędzia `mcp__n8n-mcp__*` (serwer MCP n8n-mcp), nie ręcznie w plikach tutaj.

Pełna procedura instalacji/backupu/migracji (nowy Mac, zmienne środowiskowe, disaster recovery) jest w osobnym repo: `Knowledge-Base/wiki/Software/n8n/n8n-001-Instalacja-Lokalnie-Docker-Compose-Mac.md`. Ten CLAUDE.md obejmuje tylko codzienne komendy i pułapki.

## Komendy

| Akcja | Komenda |
|---|---|
| Start | `docker compose up -d` |
| Stop | `docker compose down` |
| Logi na żywo | `docker compose logs -f` |
| Aktualizacja obrazu | `docker compose pull && docker compose up -d` |

Edytor UI: http://localhost:5678

Backup (ręczny):
```bash
docker run --rm -v n8n_data:/data -v $(pwd):/backup alpine tar czf /backup/n8n_backup.tar.gz -C /data .
```

Przywrócenie:
```bash
docker volume rm n8n_data
docker volume create n8n_data
docker run --rm -v n8n_data:/data -v $(pwd):/backup alpine tar xzf /backup/n8n_backup.tar.gz -C /data
```

## Pułapki konfiguracji

- Wolumen `n8n_data` jest zadeklarowany jako `external: true` — musi istnieć PRZED `docker compose up`. Budowa od zera: najpierw `docker volume create n8n_data`, dopiero potem `up`.
- `.env` trzyma sekrety (m.in. klucz szyfrujący) — gitignorowany, nigdy nie commitować.
- **Backup = wolumen `n8n_data` i klucz szyfrujący razem, nigdy osobno.** Rozdzielenie ich przy odtwarzaniu daje błąd "Mismatching encryption keys".

## Edycja workflow przez n8n-mcp

Workflow edytuje się na żywo w działającej instancji przez `mcp__n8n-mcp__update_workflow`, nie przez pliki w tym repo. Dwa nieoczywiste zachowania wyłapane w tej sesji:

- **Prawdziwe pole `Notes` node'a (zakładka Settings w UI n8n) to właściwość node'a na najwyższym poziomie (`node.notes`, siostrzana do `type`/`position`/`parameters`), nieosiągalna na istniejącym nodzie.** `setNodeParameter` i `updateNodeParameters` zawsze piszą wewnątrz `node.parameters`, niezależnie od podanej ścieżki JSON Pointer — `path: "/notes"` po cichu tworzy fałszywe pole `parameters.notes` zamiast ustawić prawdziwe. Jedyna operacja, której schemat udostępnia pole `notes` na najwyższym poziomie, to `addNode`. Żeby ustawić/zmienić Notes na istniejącym nodzie, trzeba `removeNode`, a potem dodać go z powrotem `addNode`-em (te same `id`, `type`, `typeVersion`, `parameters`, `position`) z `notes` w obiekcie node'a.
- **`removeNode` usuwa wszystkie połączenia (connections) danego node'a, zarówno jako źródła, jak i celu.** Po remove+re-add trzeba ręcznie odtworzyć jego connections przez `addConnection` (source, target, connectionType, indeksy) — nie są zachowywane automatycznie.

Konwencja nazewnictwa workflow w tej instancji: `NNN — Opis po polsku (stack/szczegóły w nawiasie)`, trzycyfrowy rosnący numer z zerami wiodącymi i myślnikiem em dash. Przed nazwaniem nowego workflow sprawdź `search_workflows` (posortowane po nazwie lub updatedAt) pod kątem aktualnie najwyższego numeru.

Zgodnie z instrukcjami samego serwera n8n-mcp: przed pisaniem kodu SDK workflow wywołaj `get_sdk_reference`, a dla każdej istotnej techniki `get_workflow_best_practices`.
