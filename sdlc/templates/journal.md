# Journal <id>

Trace horodatée du cycle, la plus récente en bas. Chaque entrée est aussi un événement de `events.jsonl`, écrit en même temps par le Makefile ; personne n'écrit ici à la main :

| Entrée | Qui l'écrit |
| --- | --- |
| `03 Tests · P2` : résultat de `check-red`, une ligne par test | `make check-red` |
| `04 Implémenter · itération k/3` : VERT ou ROUGE, étape et erreurs | `make check` |
| `04 Implémenter · diagnostic` sous une itération rouge | l'agent, `make noter` |
| `02 Planifier`, `05 Revue · tour t/2` : plan, verdict du reviewer | l'agent, `make noter` |
| `P1`, `P4`, `escalade` : « Validation humaine (nom git) : … » | l'humain, `make valider P=… MSG="…"` |
| `06 Livrer · bilan` : totaux du cycle | `make bilan` |
