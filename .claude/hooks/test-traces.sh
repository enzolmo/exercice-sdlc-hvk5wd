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

mY() { make -s --no-print-directory -f "$mk" "$@" T=Y; }
mkdir -p docs/tickets/Y && echo spec >docs/tickets/Y/spec.md && git add -A && git commit -qm "spec Y"
cp "$repo/docs/tickets/T-142/journal.md" docs/tickets/Y/journal.md && git add -A && git commit -qm "journal Y"
EY=docs/tickets/Y/events.jsonl
jq -nc --arg cwd "$fx/docs" '{session_id: "sess-1", cwd: $cwd, hook_event_name: "SessionStart"}' | "$repo/.claude/hooks/session.sh" 2>/dev/null
[ "$(cat .sdlc/session 2>/dev/null)" = sess-1 ]
verifie "C3 : SessionStart écrit l'id de session dans .sdlc/session du dépôt"
base=$(git log --diff-filter=A --format=%H -- docs/tickets/Y/spec.md | tail -1)
attendus=$(git log --format=%H "$base~1..HEAD" | sort)
mY bilan >/dev/null 2>&1
mY bilan >/dev/null 2>&1
obtenus=$(jq -r 'select(.event == "commit" and .session == "sess-1") | .sha' $EY 2>/dev/null | sort)
[ -n "$attendus" ] && [ "$attendus" = "$obtenus" ]
verifie "C3 : un événement commit par commit du ticket, avec la session, sans doublon"

out=$(mY bilan 2>&1)
! grep -q 'trace manquante' <<<"$out"
verifie "C4 : le journal de T-142 est complet tel quel"
mkdir -p docs/tickets/Z
awk '/^## / { skip = /· 02 Planifier/ } !skip' "$repo/docs/tickets/T-142/journal.md" >docs/tickets/Z/journal.md
out=$(make -s --no-print-directory -f "$mk" bilan T=Z 2>&1)
[ $? != 0 ] && grep -qx 'trace manquante : 02 Planifier' <<<"$out"
verifie "C4 : une étape absente est signalée et le bilan échoue"
printf '\n## 2026-01-01 00:00 · skip · validation humaine\n%s (test) : 02 Planifier, ticket trivial\n' "$vh" >>docs/tickets/Z/journal.md
out=$(make -s --no-print-directory -f "$mk" bilan T=Z 2>&1)
! grep -q 'trace manquante' <<<"$out"
verifie "C4 : une étape sautée par la porte skip n'est pas manquante"

[ $fail = 0 ] && echo "traces OK" || { echo "check-cadre : les traces ne font pas ce que disent leurs cas"; exit 1; }
