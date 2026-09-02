---
name: 11labs
description: Executes the next lesson/task from the user's ElevenLabs Conversational AI course against the live agent in this workspace (via the elevenlabs MCP server) — builds/edits the agent and its Agent Workflow based on pasted lesson content. Use ONLY when the user explicitly invokes this skill by its exact name/command (e.g. "/11labs", "użyj skilla 11labs", "jedenaście labs"). Do NOT trigger this proactively — not because a message mentions ElevenLabs, not right after building an agent, not because it seems like it would help. The user deliberately wants manual-only invocation, every time: they run `/11labs`, then paste the next course lesson's content with a new task to execute.
---

# 11labs (skill)

> **Tylko użytkownik wywołuje ten skill, wprost i w bieżącej wiadomości.** Sama wzmianka
> o ElevenLabs, agentach głosowych, czy właśnie zbudowany workflow — to nie jest
> wywołanie. Jeśli trafiłeś tutaj z innego powodu niż wyraźne `/11labs` (lub
> równoważne) w treści wiadomości użytkownika — zatrzymaj się i nic nie rób z tego
> skilla, kontynuuj rozmowę normalnie.

Ten skill nie dokumentuje — **wykonuje kolejne zadanie z kursu ElevenLabs** (agenci
głosowi / Agent Workflows), które użytkownik wkleja po wywołaniu skilla.

**Fundamentalne zasady i pułapki API ElevenLabs (kształt `workflow`, pozycje node'ów,
dwa pola na knowledge base, sprzężenie język↔model TTS, brak deep-merge w PATCH, typy
node'ów/edge'y, dobór głosu) są w `CLAUDE.md`, sekcja `## ElevenLabs` — obowiązują
zawsze, nie tylko w tym skillu. Ten plik dodaje wyłącznie zasady specyficzne dla
przechodzenia przez kolejne lekcje kursu.**

## Zasady wykonania lekcji

- **Nigdy nie odpalaj rozmowy z agentem** (Preview / Call AI Agent / test konwersacji)
  — użytkownik ma darmowy plan z limitem LLM i testuje wyłącznie sam.
- **Cała treść widoczna/słyszalna w agencie po polsku** — prompty, `first_message`,
  etykiety node'ów i edge'y, treść dokumentów knowledge base. Kurs źródłowy jest po
  angielsku (transkrypcja/dyktowanie wideo), ale finalny agent ma mówić i myśleć po
  polsku.
- **Jeden lektor (ten sam `voice_id`) na wszystkie node'y**, chyba że użytkownik
  poprosi inaczej — nie wymyślaj różnych głosów per persona.
- **Nazwy własne z transkrypcji kursu bywają zniekształcone** (głosy, czasem terminy)
  przez transkrypcję audio — np. imiona lektorów podane w lekcji mogą nie istnieć w
  bibliotece głosów tego konta. Nie blokuj się na dopasowaniu 1:1 — podstaw sensowny
  odpowiednik po charakterze persony i **napisz wprost, że to podstawienie**.
- **Jeśli użytkownik załączy zrzut ekranu z kursu — ufaj mu bardziej niż opisowi z
  audio.** Transkrypcja bywa niepełna (np. można łatwo przeoczyć osobne node'y End na
  obu gałęziach, widoczne dopiero na screenie).
- **Dane w knowledge base = syntetyczne i skromne, jeśli kurs pokazuje "zwykły
  wklejony tekst".** Nie nadinterpretuj "bazy danych" jako tabeli/SKU/cen, chyba że
  kurs/użytkownik wyraźnie tego chce — trzymaj się skali i formy z materiału
  źródłowego (kurs zwykle ma 2-3 przykładowe pozycje, nie rozbudowany katalog).
- Zanim zmienisz istniejącego agenta, sprawdź jego aktualny stan przez `agents_get`
  (albo `agents_list` z `tags: ["course-demo"]`, jeśli nie wiadomo który agent).
  Domyślnie rozwijaj istniejącego agenta z tej serii, chyba że lekcja wyraźnie każe
  zacząć od nowa.
- Jeśli treść lekcji jest niejasna co do konkretnej wartości (dokładny tekst promptu,
  konkretne dane), a koszt błędu jest niski/odwracalny — nazwij założenie i działaj,
  nie pytaj. Jeśli dotyczy czegoś kosztownego/nieodwracalnego — zapytaj.

## Reporting back

Po polsku, krótkie punkty, wniosek na górze — bez pytania na końcu, chyba że coś
faktycznie wymaga decyzji użytkownika:
- co powstało/zmieniło się (agent, node'y, dokumenty KB)
- jawnie wypisane założenia (podstawione głosy, wymyślone dane, interpretacje niejasnych
  poleceń z lekcji)
- że rozmowa nie została przetestowana i to celowe
