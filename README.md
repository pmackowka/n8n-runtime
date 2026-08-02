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
