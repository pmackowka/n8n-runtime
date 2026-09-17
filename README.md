# n8n — lokalna instancja (Docker Compose)

Krótka ściąga do codziennej obsługi. Pełny opis instalacji, zmiennych środowiskowych, backupu i migracji na nowy Mac: `Knowledge-Base/wiki/Software/n8n/n8n-001-Instalacja-Lokalnie-Docker-Compose-Mac.md` (osobne repo, ten sam Mac).

## Uruchamianie

| Akcja | Komenda |
|---|---|
| Start | `docker compose up -d` |
| Stop | `docker compose down` |
| Logi na żywo | `docker compose logs -f` |
| Aktualizacja obrazu | `docker compose pull && docker compose up -d` |

Edytor: http://localhost:5678

## Ważne dla tego configu

- Wolumen `n8n_data` jest zadeklarowany jako `external: true` — musi istnieć PRZED `docker compose up` (tu już istnieje, instancja działa od czerwca 2026). Odtwarzanie od zera: `docker volume create n8n_data` najpierw, dopiero potem `up`.
- `.env` trzyma sekrety (m.in. klucz szyfrujący) — gitignorowany, nigdy nie commitować.
- Backup = wolumen `n8n_data` **i** klucz szyfrujący razem, nie osobno — rozdzielenie tych dwóch przy odtwarzaniu daje błąd "Mismatching encryption keys". Pełna procedura backup/restore w notatce wyżej.

## Workflow-as-code (definicje w git)

Osobna warstwa od backupu wolumenu niżej — **nie zastępuje go**. Eksport bierze tylko definicje
workflow (JSON, `workflows/*.json`, jeden plik na workflow, nazwany po ID). Nie dotyka credentiali
(referencje `{id, name}`, nigdy sekretów) ani reszty stanu instancji (ustawienia, historia wykonań).
Jedynym źródłem prawdy do disaster recovery pozostaje pełny backup wolumenu `n8n_data` + `.env`
(sekcja niżej) — ten eksport daje tylko diff/historię zmian logiki workflow w git.

| Akcja | Komenda |
|---|---|
| Eksport wszystkich workflow do `workflows/` | `./scripts/export-workflows.sh` |
| Import workflow z `workflows/` do instancji | `./scripts/import-workflows.sh` |

Eksport nadpisuje cały katalog `workflows/` (pełny sync) — usunięty w n8n workflow zniknie też
z repo, będzie widoczny jako `deleted` w `git status`.

**Kiedy odpalać:** ręcznie, po sesji edycji workflow w n8n — `./scripts/export-workflows.sh`,
przejrzyj `git diff`, dopiero potem `git add workflows/ && git commit`. Bez crona/automatyzacji.

**Import** ma sens na świeżo postawionej instancji (nowy wolumen `n8n_data`), ZANIM zaimportuje się
właściwy backup wolumenu z Drive — odtwarza logikę workflow, ale credentiale trzeba podłączyć
ręcznie albo docelowo odtworzyć z backupu wolumenu.

## Backup (szybki, ręczny)

```bash
docker run --rm -v n8n_data:/data -v $(pwd):/backup alpine tar czf /backup/n8n_backup.tar.gz -C /data .
```

Przywrócenie:

```bash
docker volume rm n8n_data
docker volume create n8n_data
docker run --rm -v n8n_data:/data -v $(pwd):/backup alpine tar xzf /backup/n8n_backup.tar.gz -C /data
```
