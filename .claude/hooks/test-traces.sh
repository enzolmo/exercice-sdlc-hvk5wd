#!/usr/bin/env bash
# Rejoue les cibles de trace du Makefile dans un dépôt jetable : journal.md et events.jsonl doivent concorder.
repo=$(cd "$(dirname "$0")/../.." && pwd)
mk=$repo/Makefile
fx=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$fx"' EXIT
fail=0
vh="Validation"" humaine"
verifie() { local st=$?; if [ $st = 0 ]; then echo "ok    $1"; else echo "ÉCHEC $1"; fail=1; fi; }
m() { make -s --no-print-directory -f "$mk" "$@" T=X; }

cd "$fx" || exit 1
git init -q && git config user.name test && git config user.email test@example.com
mkdir -p docs/tickets/X && echo spec >docs/tickets/X/spec.md && : >docs/tickets/X/journal.md
git add -A && git commit -qm spec
J=docs/tickets/X/journal.md
E=docs/tickets/X/events.jsonl

m noter TITRE="02 Planifier" MSG="3 tâches" >/dev/null 2>&1
m noter TITRE="05 Revue · tour 1/2" MSG="LIVRABLE" >/dev/null 2>&1
[ "$(grep -c '^## ' $J)" = 2 ] && [ "$(jq -c 'select(.event == "journal")' $E | wc -l | tr -d ' ')" = 2 ]
verifie "C1 : noter écrit le journal et events.jsonl ensemble"
jq -e . $E >/dev/null 2>&1
verifie "C1 : events.jsonl est du JSON valide"
! m noter TITRE="P1" MSG="ok" >/dev/null 2>&1
verifie "noter refuse un titre qui n'est pas une étape"
! m noter TITRE="02 Planifier" MSG="$vh : ok" >/dev/null 2>&1
verifie "noter refuse la formule de validation"
directs=$(grep -nE '([Aa]joute|[Nn]ote|[ÉéEe]cris|[Ee]xplique|[Ss]ignale)[^.]*journal' "$repo"/sdlc/0[1-6]-*.md \
  | grep -vE 'make noter|`make [a-z-]+`[^.]*(ajoute|écrit)')
[ -z "$directs" ]
verifie "C1 : aucune étape ne fait écrire le journal hors d'une cible make"
[ -n "$directs" ] && echo "$directs"

[ $fail = 0 ] && echo "traces OK" || { echo "check-cadre : les traces ne font pas ce que disent leurs cas"; exit 1; }
