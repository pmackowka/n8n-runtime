# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Czym jest to repo

Scaffold Docker Compose dla lokalnej instancji **n8n** — to nie jest kodowa aplikacja. Nie ma tu build/lint/testów; jedynym "kodem" są `docker-compose.yml` i `.env`. Instancja to pojedynczy kontener n8n z wbudowaną bazą SQLite (bez Postgresa, bez trybu queue/workerów) — cały stan (workflow, credentiale, ustawienia) siedzi w wolumenie `n8n_data`. Same workflow (nody, połączenia, credentiale) żyją wewnątrz działającej instancji, nie jako pliki w tym repo — edytuj je na żywo przez narzędzia `mcp__n8n-mcp__*` (serwer MCP n8n-mcp), nie ręcznie w plikach tutaj.

Ten sam katalog roboczy służy też do nauki agentów głosowych ElevenLabs (przez serwer MCP `elevenlabs`) w ramach osobnego kursu — analogicznie do n8n, cały stan (agenci, workflow, knowledge base) żyje w usłudze zewnętrznej, nie jako pliki tutaj.

Pełna procedura instalacji/backupu/migracji n8n (nowy Mac, zmienne środowiskowe, disaster recovery) jest w osobnym repo: `Knowledge-Base/wiki/Software/n8n/n8n-001-Instalacja-Lokalnie-Docker-Compose-Mac.md`. Ten CLAUDE.md obejmuje tylko codzienne komendy i pułapki.

## Styl dokumentacji

Cokolwiek piszesz w tym repo — Sticky Notes, pole `Notes` node'a, ten plik CLAUDE.md — opisuj wyłącznie bieżący, konkretny stan/konfigurację. Zero narracji historycznej ("wcześniej było X, potem zmieniliśmy na Y", "ta nazwa była zajęta, więc..."). Czytelnik z przyszłości ma dostać fakt, nie dziennik zdarzeń.

## Skille

Zadania specyficzne dla poszczególnych narzędzi mają dedykowane skille — wywoływane **wyłącznie ręcznie przez użytkownika**, nigdy proaktywnie (samo słowo "n8n"/"ElevenLabs"/"11labs" w wiadomości NIE jest wywołaniem):

- `.claude/skills/n8n/` (`/n8n`) — dopisuje dokumentację do istniejącego workflow: prawdziwe pole `Notes` per node, sticky note z podsumowaniem.
- `.claude/skills/11labs/` (`/11labs`) — wykonuje kolejne zadanie z kursu ElevenLabs (budowa/edycja agenta i Agent Workflow) na podstawie wklejonej przez użytkownika treści lekcji.

Fundamentalne zasady i pułapki obu narzędzi (sekcje `## n8n` i `## ElevenLabs` niżej) obowiązują zawsze, niezależnie od tego, czy dany skill został wywołany — bo dotyczą każdej edycji przez odpowiedni MCP, nie tylko pracy w ramach skilla.

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

## n8n — edycja workflow przez n8n-mcp

Workflow edytuje się na żywo w działającej instancji przez `mcp__n8n-mcp__update_workflow`, nie przez pliki w tym repo.

Konwencja nazewnictwa workflow w tej instancji: `NNN — Opis po polsku (stack/szczegóły w nawiasie)`, trzycyfrowy rosnący numer z zerami wiodącymi i myślnikiem em dash. Przed nazwaniem nowego workflow sprawdź `search_workflows` (posortowane po nazwie lub updatedAt) pod kątem aktualnie najwyższego numeru.

Zgodnie z instrukcjami samego serwera n8n-mcp: przed pisaniem kodu SDK workflow wywołaj `get_sdk_reference`, a dla każdej istotnej techniki `get_workflow_best_practices`.

**Domyślny node dla każdego kroku wymagającego LLM to OpenRouter Chat Model (`@n8n/n8n-nodes-langchain.lmChatOpenRouter`) z modelem `openai/gpt-oss-120b` i istniejącym credentialem `OpenRouter account` — niezależnie od tego, jakiego providera sugeruje materiał źródłowy (kurs, lekcja, dokumentacja).** Kurs regularnie każe użyć konkretnego innego providera (Google Gemini, OpenAI wprost, Anthropic itd.) — ignoruj to bez pytania i zamiast tego podłącz OpenRouter z darmowym modelem. Nie zakładaj nowych credentiali dla innych providerów tylko dlatego, że lekcja tak pokazuje. Wyjątek: użytkownik w tej samej wiadomości wyraźnie prosi o konkretny inny provider/model — wtedy rób tak, jak prosi.

**Model na node'ie OpenRouter Chat Model musi być zawsze darmowy — płatne modele nie działają na koncie użytkownika.** Przy każdym tworzeniu, poprawianiu, naprawianiu lub edycji workflow zawierającego `@n8n/n8n-nodes-langchain.lmChatOpenRouter`, zweryfikuj pole `model` i ustaw/zostaw je na `openai/gpt-oss-120b` (sprawdzony, darmowy model używany w tej instancji, np. w workflow 009). Nie zakładaj, że inny, płatny model (np. `openai/gpt-4.1`) jest w porządku tylko dlatego, że materiał źródłowy (kurs, dokumentacja modelu) go poleca — u tego użytkownika taki model i tak się nie wykona, więc trzeba go zamienić na darmowy zamiennik za każdym razem, bez pytania.

Kilka nieoczywistych zachowań `update_workflow` wyłapanych w praktyce:

- **„Cannot modify workflow while it is being edited by a user in the editor"** — workflow jest otwarty w przeglądarce użytkownika. Trzeba go zamknąć/opuścić zakładkę, dopiero potem edycja przez API przejdzie.
- **Credentiale podpięte przez `setNodeCredential` (albo `newCredential()` w kodzie SDK) nigdy nie pojawiają się z powrotem w odczycie `get_workflow_details`** — to redakcja po stronie n8n, nie błąd podpięcia. Ufaj sygnałowi sukcesu (`appliedOperations`, brak `validationWarnings`), nie próbuj tego weryfikować przez odczyt.
- **n8n czasem samo „normalizuje" parametry** — usuwa pola typu `resource`/`operation`, gdy pasują do wartości domyślnej (widziane na nodach Pushover, Date & Time, Telegram, Form Trigger `fieldType`, Google Sheets Tool, Marketstack Tool). Efekt: walidator może później zgłosić `INVALID_PARAMETER: missing discriminator`, mimo że node wcześniej działał bez zarzutu. Pierwotnie widziane tylko przy zapisie przez UI, ale zaobserwowane też przy kolejnych wywołaniach `update_workflow` przez API, na nodach, których dana operacja w ogóle nie dotykała — więc nie zakładaj, że ustawienie tego raz wystarczy. Fix: po każdej istotnej edycji workflow (nie tylko po edycji tego konkretnego node'a) zrób świeży `get_workflow_details` i sprawdź, czy `resource`/`operation`/`fieldType` wciąż tam są; jeśli nie, ustaw je ponownie przez `setNodeParameter`.
- **Na node'ach Google Sheets Tool (`operation: update`) z nierozwiązanym `documentId`/`sheetName` (placeholder, brak realnego dokumentu) n8n potrafi wyzerować cały obiekt `columns` (resourceMapper: `mappingMode`, `value`, `schema`, `matchingColumns`)** — nie tylko pojedyncze pola jak w gotchu wyżej, i z tym samym zastrzeżeniem: obserwowane zarówno po otwarciu/zapisaniu workflow w UI, jak i po kolejnych `update_workflow` przez API, które tego node'a wcale nie dotykały. Efekt: narzędzie AI traci całą konfigurację mapowania kolumn po cichu, bez ostrzeżenia (`appliedOperations`/brak `validationWarnings` tego nie wyłapie — to nie błąd tamtej operacji, tylko efekt uboczny przy innym node'ie). Dopóki dokument/arkusz nie jest realnie podłączony, po każdej edycji tego workflow rób świeży odczyt i traktuj `columns` jako coś do zweryfikowania na nowo, nie coś ustawionego raz na zawsze.
- **Triggery z zewnętrznych platform czatu (Telegram, Slack) nie mają natywnego `chatInput`** jak wbudowany Chat Trigger — pole promptu AI Agenta trzeba ręcznie przełączyć na `promptType: 'define'` i wyciągnąć właściwe dane wyrażeniem (np. `{{ $json.message.text }}` dla Telegrama, albo `{{ JSON.stringify($json) }}`, gdy wolisz oddać cały surowy JSON agentowi do samodzielnego sparsowania).
- **Te same triggery nie mają naturalnej granicy „sesji" dla pamięci agenta** — domyślny `sessionIdType: fromInput` w Simple Memory wymiesza rozmowy różnych osób/wątków w jedną pamięć. Ustaw `sessionIdType: customKey` z kluczem opartym o realny identyfikator konwersacji (`chat.id` dla Telegrama, `thread_ts`/`ts` dla wątku na Slacku).

Dokumentowanie węzłów (prawdziwe pole `Notes` per node, domyślny model OpenRouter, sticky note z podsumowaniem workflow) ma dedykowany skill: `.claude/skills/n8n/` (wywołanie: `/n8n`). Mechanika `removeNode`+`addNode` do ustawiania `node.notes` jest opisana w tym skillu, nie tutaj.

## ElevenLabs — agenci i Agent Workflows przez elevenlabs MCP

Agent i jego Agent Workflow (nody + edge'e routingu) edytuje się na żywo przez `mcp__elevenlabs__agents_create` / `agents_update`, nie przez pliki w tym repo. Konto jest na darmowym planie z limitem zużycia LLM — **nigdy nie odpalaj rozmowy z agentem (Preview / Call AI Agent / test konwersacji)**, testuje wyłącznie użytkownik.

Agenci budowani w ramach kursu ElevenLabs (skill `11labs`) są tagowani `course-demo` (parametr `tags` w `agents_create`/`agents_update`) — analogicznie do konwencji nazewnictwa workflow w n8n, to sposób na odnalezienie właściwego agenta z serii przez `agents_list` zamiast zgadywania czy tworzenia duplikatu.

**Nie ufaj bezkrytycznie stronie docs.elevenlabs.io w kwestii dokładnego kształtu API** — strona `eleven-agents/customization/agent-workflows` pokazuje `workflow` błędnie zagnieżdżone w `conversation_config.workflow`. Prawdziwy kształt requestu (PATCH `/v1/convai/agents/{id}`, potwierdzony w źródle `elevenlabs-python`) ma `workflow` jako pole **równorzędne** z `conversation_config`, `platform_settings`, `name`, `tags`. Gdy nazwa pola budzi wątpliwość, sprawdzaj w źródle SDK zamiast zgadywać: `gh api repos/elevenlabs/elevenlabs-python/contents/src/elevenlabs/types/<plik>.py --jq '.content' | base64 -d` (pliki `workflow_*.py`, `agent_workflow_*.py`, `*_workflow_override_*.py`).

Kilka nieoczywistych zachowań schematu Agent Workflow wyłapanych w praktyce:

- **Node'y muszą mieć różne `position: {x, y}`.** Pominięcie `position` albo identyczne współrzędne (np. wszystkie `{0,0}`) powodują, że node'y nakładają się w edytorze i widać tylko jeden.
- **Knowledge base per node trzeba ustawić w DWÓCH miejscach jednocześnie:** `conversation_config.agent.prompt.knowledge_base` (realnie używane przez LLM w tym node'ie — pełny override, nie dodaje do globalnej bazy, tak osiąga się "brak dziedziczenia") oraz `additional_knowledge_base` (pole na poziomie node'a, obok `label`) — to drugie czyta panel UI ("Additional Documents"). Ustawienie tylko pierwszego działa dla modelu, ale w edytorze wygląda, jakby node nie miał żadnej bazy wiedzy.
- **`entry_behavior: "generate_immediately"` + brak `first_message` na node'ie specjalisty** = node dynamicznie odpowiada na pytanie, które już padło u poprzednika (nie powtarza go, nie recytuje sztywnej linijki). `first_message` ustawiaj tylko tam, gdzie ma paść naprawdę stały tekst (zwykle start/main agent).
- **Język a model TTS są sprzężone.** `eleven_flash_v2` i `eleven_turbo_v2` (bez `_5`) są tylko angielskie — `language` inny niż `en` przy takim modelu kończy się błędem 400 (`"Non-english Agents must use turbo or flash v2_5"`). Dla polskiego (i innych języków) używaj `eleven_flash_v2_5` / `eleven_turbo_v2_5` / `eleven_multilingual_v2` / `eleven_v3_conversational` — zarówno w bazowym `conversation_config`, jak i w każdym node'ie.
- **PATCH na `conversation_config` i na `workflow.nodes`/`workflow.edges` nie robi bezpiecznego deep-merge z tym, co już tam jest** — traktuj to jak pełny replace tej gałęzi. Przed zmianą jednego pola głęboko w środku pobierz pełny aktualny obiekt (z ostatniej odpowiedzi `agents_update` albo świeżego `agents_get`), zmień w nim tylko to, co trzeba, i odeślij całość. To samo dotyczy `workflow.nodes`/`edges`: zawsze wysyłaj kompletny słownik wszystkich node'ów/edge'y, nie tylko te, które zmieniasz.
- **Wybór głosu:** z `creative_list_voices` bierz tylko pozycje z `"category": "premade"` i `"is_library_voice": false` — to głosy gwarantowane na każdym planie, w tym darmowym. Głosy z `"is_library_voice": true` (Voice Library) mogą wymagać dodania do workspace'u i nie są pewne na koncie darmowym — próba użycia takiego głosu przez API (np. domyślny Rachel, `21m00Tcm4TlvDq8ikWAM`) na darmowym planie kończy się błędem 402 `paid_plan_required` ("Free users cannot use library voices via the API").
- **Domyślny głos to Sarah (`EXAVITQu4vr4xnSDxMaL`)** — premade, `is_library_voice: false`, ciepły/uspokajający ton. Używaj go domyślnie wszędzie, gdzie potrzebny jest głos ElevenLabs (agent, node TTS w n8n, dowolna synteza mowy) w tej instancji, niezależnie od tego, jaki głos sugeruje materiał źródłowy (kurs, dokumentacja) — bez pytania, chyba że użytkownik w tej samej wiadomości wyraźnie prosi o inny konkretny głos.
- **Typy node'ów widziane w praktyce:** `start` (tylko `position`/`edge_order`), `override_agent` (`label`, `entry_behavior`, `conversation_config.agent.{language,first_message,prompt}`, `conversation_config.tts.{voice_id,model_id}`, `additional_knowledge_base`, `additional_prompt` — to ostatnie DODAJE do promptu, do pełnego zastąpienia służy `conversation_config.agent.prompt.prompt`), `end` (tylko `position`). `phone_number`, `standalone_agent`, `tool` istnieją w schemacie, ale nieprzetestowane — sprawdź pola w źródle SDK przed użyciem.
- **Edge `forward_condition.type`:** `"unconditional"` (bez warunku), `"llm"` (naturalny język: `condition` + opcjonalny `label`), `"expression"` (deterministyczne AST), `"result"` (sukces/porażka narzędzia). `edge_order` na node'ie źródłowym ustala kolejność sprawdzania warunków LLM.

Wykonywanie kolejnych zadań/lekcji kursu (budowa/edycja konkretnego agenta na podstawie wklejonej treści, w tym reguły "jeden lektor po polsku", "dane w KB syntetyczne i skromne", "ufaj screenowi bardziej niż transkrypcji audio") ma dedykowany skill: `.claude/skills/11labs/` (wywołanie: `/11labs`).
