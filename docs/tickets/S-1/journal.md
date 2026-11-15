# Journal S-1

Chantier du cadre, hors cycle : `.sdlc-step` vaut `libre`, posé par l'humain.

## 2026-11-15 · C1 · vérification manuelle de la liste deny
- `git push --dry-run` : refusé, mais par le hook git global du poste (`~/.claude/hooks/block-git-writes.sh`), qui passe avant la liste deny. Sur ce poste, la liste deny n'est pas le premier filet pour `git push`.
- `curl --version` : refusé par Claude Code (« Permission to use Bash with command curl --version has been denied »), sans hook du projet ni du poste sur cette commande : la liste deny s'applique.
- WebFetch et WebSearch ont disparu des outils de la session dès l'enregistrement de `settings.json`.
