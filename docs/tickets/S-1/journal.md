# Journal S-1

Chantier du cadre, hors cycle : `.sdlc-step` vaut `libre`, posé par l'humain.

## 2026-11-15 · C1 · vérification manuelle de la liste deny
- `git push --dry-run` : refusé, mais par le hook git global du poste (`~/.claude/hooks/block-git-writes.sh`), qui passe avant la liste deny. Sur ce poste, la liste deny n'est pas le premier filet pour `git push`.
- `curl --version` : refusé par Claude Code (« Permission to use Bash with command curl --version has been denied »), sans hook du projet ni du poste sur cette commande : la liste deny s'applique.
- WebFetch et WebSearch ont disparu des outils de la session dès l'enregistrement de `settings.json`.

## 2026-11-15 · C3 · vérification manuelle du reviewer, non concluante
- Sous-agent `reviewer` lancé dans la session qui venait de modifier `reviewer.md` : `git diff --stat HEAD~1` acceptée, `git status --short` acceptée alors qu'elle n'est pas dans `tools`. Outils annoncés : Read, Bash.
- `git commit --dry-run` : non lancée, le reviewer s'est abstenu de lui-même (consigne de son prompt), pas par refus de l'outil.
- Conclusion provisoire : dans cette session, les motifs `Bash(...)` de `tools` ne restreignent pas Bash. Reste à refaire le test dans une session neuve, où la définition est relue au démarrage ; si `git status` passe encore, retirer Bash du reviewer et lui passer diff et sortie de `make check` dans son prompt.
