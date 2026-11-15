# S-4 · Observabilité du cycle : des traces lisibles par une machine, et chaque refus compté

> Le journal est parfait pour un humain et inutilisable pour agréger. On ne sait pas combien de fois l'agent a tenté
> de toucher aux tests, ni retrouver la session qui a produit un commit. Et une étape qui n'écrit pas dans le journal
> passe inaperçue.
>
> — Enzo, lead

---

# Spec S-4 (chantier du cadre)

## Problème
Les traces sont du Markdown produit par `printf` ; leur forme n'est pas garantie, donc S-2 et S-3 n'ont rien de fiable à lire. Les refus du hook ne laissent rien. Le lien entre un commit et la session Claude qui l'a produit n'existe pas.

## Comportement attendu
- Chaque entrée de journal est aussi écrite en JSON Lines dans `docs/tickets/<id>/events.jsonl`, par la même fonction `journaliser` : `{"event","ts","ticket","step","title","gate","result","iteration","actor","session"}`. Le Markdown reste la vue humaine, le JSONL la source des métriques. L'agent n'écrit plus d'entrée `## ` à la main : il passe par `make noter`.
- Chaque refus du hook ajoute une ligne `guard_denied` au JSONL avec l'étape, la règle, et le chemin ou le premier mot de la commande ; `make bilan` compte « refus du hook : n ».
- L'identifiant de session Claude est écrit dans `.sdlc/session` du dépôt courant par un hook `SessionStart`, et figure dans chaque événement. `make bilan` ajoute un événement `commit` par commit du ticket (sha et session) : le lien commit → session reste dans le dépôt, sans trailer dans le message.
- `make bilan` vérifie la complétude d'après la liste `ETAPES` du Makefile, sinon « trace manquante : … ».
- Le hook prend pour racine le dépôt du fichier visé (worktree compris), plus `CLAUDE_PROJECT_DIR`.

## Hypothèses (tranchées)
1. **Deux formats, une écriture** : `journaliser` écrit Markdown et JSONL ensemble ; l'agent passe par `make noter TITRE="0X …" MSG="…"` (titre commençant par une étape, jamais une porte ni une validation). `check-cadre` vérifie par grep qu'aucun `sdlc/0X-*.md` ne demande plus d'écrire directement dans le journal. Le JSONL est commité avec le journal.
2. **Session** : hook `SessionStart` qui écrit `session_id` dans `.sdlc/session` (gitignoré) à la racine du dépôt de `cwd`. Après `/clear`, nouvelle session, nouvel id : voulu. Un événement `commit` par commit de `<base>~1..HEAD`, écrit par `make bilan` ; la session enregistrée est celle qui livre, approximation si le ticket a été repris sur plusieurs sessions. Pas de trailer `Claude-Session:` (message d'une ligne).
3. **Refus du hook** : `guard.sh` ajoute l'événement avant `exit 2` ; hors cycle (`docs/tickets/<id>/` absent), il écrit dans `.sdlc/guard.log`. Règle et premier mot de la commande, jamais la commande entière.
4. **Complétude** : liste `ETAPES` dans le Makefile, que le README cite : `P1` (vaut pour 01), `02 Planifier`, `03 Tests · P2`, `04 Implémenter`, P3 (une itération VERT), `05 Revue`, `P4`. `06 Livrer` est l'entrée que `make bilan` écrit lui-même. Le journal de T-142 passe tel quel. Une étape sautée se note par la porte humaine `skip`, avec le nom de l'étape en tête du message.
5. **Vie privée** : aucun contenu de message dans les événements ; identifiants, titres d'étape, résultats et chemins seulement.

## Critères d'acceptation
- **C1** — Étant donné des entrées écrites par `make noter` et les cibles du cycle, quand on compte les lignes `"event":"journal"` de `events.jsonl` et les `## ` du `journal.md`, alors les nombres sont égaux et chaque ligne est du JSON valide (`jq -e .`) ; et aucun `sdlc/0X-*.md` ne demande d'écrire dans le journal hors d'une cible `make` (test dans `check-cadre`).
- **C2** — Étant donné `.sdlc-step` = `implementer` et une écriture tentée sous `api/tests/`, quand le hook refuse, alors `events.jsonl` reçoit une ligne `guard_denied` avec `rule: R2` et le chemin (test dans `test-guard.sh`).
- **C3** — Étant donné une session, quand le hook `SessionStart` a tourné, alors `.sdlc/session` contient son identifiant ; et après `make bilan`, `events.jsonl` contient un événement `commit` pour chaque commit de `<base>~1..HEAD`, avec cette session (test dans `check-cadre`).
- **C4** — Étant donné un journal où l'entrée `02 Planifier` manque, quand on lance `make bilan`, alors il affiche `trace manquante : 02 Planifier` et sort en échec ; sur une copie du journal de T-142, il ne signale rien (test dans `check-cadre`).
- **C5** — Étant donné une fixture `events.jsonl` avec deux lignes `guard_denied`, quand `make bilan` tourne, alors il affiche `refus du hook : 2` (test dans `check-cadre`).

## Hors périmètre
- Envoi des événements à un collecteur (OpenTelemetry, fichier partagé) ; conservation de la transcription complète ; dashboard (S-3 en fait un tableau Markdown).

## Classe de risque
élevée — le journal est une trace de décision ; en changer la production touche les contrôles.

## Fichiers
```files
Makefile
.claude/hooks/guard.sh
.claude/hooks/session.sh
.claude/hooks/test-guard.sh
.claude/hooks/test-traces.sh
.claude/settings.json
.gitignore
sdlc/01-cadrer.md
sdlc/02-planifier.md
sdlc/03-tests.md
sdlc/04-implementer.md
sdlc/05-revue.md
sdlc/06-livrer.md
sdlc/README.md
sdlc/templates/journal.md
```
