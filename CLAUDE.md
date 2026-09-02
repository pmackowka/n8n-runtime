# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Czym jest to repo

Scaffold Docker Compose dla lokalnej instancji **n8n** — to nie jest kodowa aplikacja. Nie ma tu build/lint/testów; jedynym "kodem" są `docker-compose.yml` i `.env`. Instancja to pojedynczy kontener n8n z wbudowaną bazą SQLite (bez Postgresa, bez trybu queue/workerów) — cały stan (workflow, credentiale, ustawienia) siedzi w wolumenie `n8n_data`. Same workflow (nody, połączenia, credentiale) żyją wewnątrz działającej instancji, nie jako pliki w tym repo — edytuj je na żywo przez narzędzia `mcp__n8n-mcp__*` (serwer MCP n8n-mcp), nie ręcznie w plikach tutaj.

Pełna procedura instalacji/backupu/migracji (nowy Mac, zmienne środowiskowe, disaster recovery) jest w osobnym repo: `Knowledge-Base/wiki/Software/n8n/n8n-001-Instalacja-Lokalnie-Docker-Compose-Mac.md`. Ten CLAUDE.md obejmuje tylko codzienne komendy i pułapki.

## Styl dokumentacji

Cokolwiek piszesz w tym repo — Sticky Notes, pole `Notes` node'a, ten plik CLAUDE.md — opisuj wyłącznie bieżący, konkretny stan/konfigurację. Zero narracji historycznej ("wcześniej było X, potem zmieniliśmy na Y", "ta nazwa była zajęta, więc..."). Czytelnik z przyszłości ma dostać fakt, nie dziennik zdarzeń.

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
- **Trigery webhookowe z zewnętrznych usług (Telegram Trigger, Slack Trigger i podobne) wymagają publicznego adresu HTTPS** — Telegram i Slack weryfikują to przy rejestracji webhooka i odrzucają rejestrację bez niego. Ta instancja (`localhost:5678`, bez TLS) tego nie spełnia — taki workflow nie da się aktywować bez tunelu (np. ngrok) i zmiennej `WEBHOOK_URL`. Wbudowany Chat Trigger n8n tego problemu nie ma, bo przeglądarka łączy się z n8n bezpośrednio, bez pośrednika.
- **Konto n8n na tej instancji jest zarejestrowane na „Krzysztof Strand" / `codecollabsql@gmail.com`** (widoczne np. jako nazwa jedynego projektu w `search_projects`, albo jako `targetProject` przy tworzeniu workflow). To adres i dane właściciela tego repo — jego alternatywny e-mail, używany do newsletterów, reklam i testowanych narzędzi. Nie jest to cudze konto ani błąd konfiguracji instancji.

## Edycja workflow przez n8n-mcp

Workflow edytuje się na żywo w działającej instancji przez `mcp__n8n-mcp__update_workflow`, nie przez pliki w tym repo.

Konwencja nazewnictwa workflow w tej instancji: `NNN — Opis po polsku (stack/szczegóły w nawiasie)`, trzycyfrowy rosnący numer z zerami wiodącymi i myślnikiem em dash. Przed nazwaniem nowego workflow sprawdź `search_workflows` (posortowane po nazwie lub updatedAt) pod kątem aktualnie najwyższego numeru.

Zgodnie z instrukcjami samego serwera n8n-mcp: przed pisaniem kodu SDK workflow wywołaj `get_sdk_reference`, a dla każdej istotnej techniki `get_workflow_best_practices`.

Kilka nieoczywistych zachowań `update_workflow` wyłapanych w praktyce:

- **„Cannot modify workflow while it is being edited by a user in the editor"** — workflow jest otwarty w przeglądarce użytkownika. Trzeba go zamknąć/opuścić zakładkę, dopiero potem edycja przez API przejdzie.
- **Credentiale podpięte przez `setNodeCredential` (albo `newCredential()` w kodzie SDK) nigdy nie pojawiają się z powrotem w odczycie `get_workflow_details`** — to redakcja po stronie n8n, nie błąd podpięcia. Ufaj sygnałowi sukcesu (`appliedOperations`, brak `validationWarnings`), nie próbuj tego weryfikować przez odczyt.
- **n8n czasem samo „normalizuje" parametry przy zapisie przez UI** — usuwa pola typu `resource`/`operation`, gdy pasują do wartości domyślnej (widziane na nodach Pushover, Date & Time, Telegram). Efekt: walidator może później zgłosić `INVALID_PARAMETER: missing discriminator`, mimo że node wcześniej działał bez zarzutu. Fix: ustaw `resource`/`operation` jawnie przez `setNodeParameter`.
- **Triggery z zewnętrznych platform czatu (Telegram, Slack) nie mają natywnego `chatInput`** jak wbudowany Chat Trigger — pole promptu AI Agenta trzeba ręcznie przełączyć na `promptType: 'define'` i wyciągnąć właściwe dane wyrażeniem (np. `{{ $json.message.text }}` dla Telegrama, albo `{{ JSON.stringify($json) }}`, gdy wolisz oddać cały surowy JSON agentowi do samodzielnego sparsowania).
- **Te same triggery nie mają naturalnej granicy „sesji" dla pamięci agenta** — domyślny `sessionIdType: fromInput` w Simple Memory wymiesza rozmowy różnych osób/wątków w jedną pamięć. Ustaw `sessionIdType: customKey` z kluczem opartym o realny identyfikator konwersacji (`chat.id` dla Telegrama, `thread_ts`/`ts` dla wątku na Slacku).

Dokumentowanie węzłów (prawdziwe pole `Notes` per node, domyślny model OpenRouter, sticky note z podsumowaniem workflow) ma dedykowany skill: `.claude/skills/n8n/` (wywołanie: `/n8n`). Wywoływany tylko ręcznie przez użytkownika — samo słowo "n8n" w wiadomości NIE jest wywołaniem, nie uruchamiaj go samodzielnie/proaktywnie. Mechanika `removeNode`+`addNode` do ustawiania `node.notes` jest opisana w tym skillu, nie tutaj.
