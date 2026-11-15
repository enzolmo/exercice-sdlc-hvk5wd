#!/usr/bin/env bash
# Envoie des entrées PreToolUse à guard.sh dans un projet jetable et vérifie le code de sortie (0 accepté, 2 refusé).
guard=$(cd "$(dirname "$0")" && pwd)/guard.sh
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
export CLAUDE_PROJECT_DIR=$root
fail=0
# Coupée en deux : écrite en entier, la formule ferait refuser ce fichier par le hook qu'il teste.
vh="Validation"" humaine"

cas() {
  local attendu=$1 step=$2 label=$3 json=$4 got
  if [ -n "$step" ]; then echo "$step T-1" >"$root/.sdlc-step"; else rm -f "$root/.sdlc-step"; fi
  "$guard" <<<"$json" 2>/dev/null
  got=$?
  if [ "$got" = "$attendu" ]; then echo "ok    $label"; else echo "ÉCHEC $label : attendu $attendu, obtenu $got"; fail=1; fi
}
write() { jq -nc --arg p "$1" --arg c "${2:-x}" '{tool_name: "Write", tool_input: {file_path: $p, content: $c}}'; }
bash_() { jq -nc --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c}}'; }

cas 2 implementer "sdlc/x.md refusé pendant implementer" "$(write sdlc/x.md)"
cas 2 "" "sdlc/x.md refusé sans étape" "$(write sdlc/x.md)"
cas 2 implementer "chemin absolu du cadre refusé" "$(write "$root/.claude/hooks/guard.sh")"
cas 0 libre "sdlc/x.md accepté en libre" "$(write sdlc/x.md)"
cas 2 implementer "api/tests/x.rs refusé pendant implementer" "$(write api/tests/x.rs)"
cas 0 tests "api/tests/x.rs accepté pendant tests" "$(write api/tests/x.rs)"
cas 2 implementer "web/src/x.test.ts refusé pendant implementer" "$(write web/src/x.test.ts)"
cas 2 "" "api/src/x.rs refusé sans étape" "$(write api/src/x.rs)"
cas 2 "" "web/src/x.ts refusé sans étape" "$(write web/src/x.ts)"
cas 0 implementer "api/src/x.rs accepté pendant implementer" "$(write api/src/x.rs)"
cas 0 "" "docs/x.md accepté sans étape" "$(write docs/x.md)"
cas 2 tests ".env refusé" "$(write .env)"
cas 2 libre ".env refusé même en libre" "$(write .env)"
cas 2 implementer "api/.env.local refusé" "$(write api/.env.local)"
cas 2 libre "*.pem refusé" "$(write certs/cle.pem)"
cas 2 libre ".git/ refusé" "$(write .git/config)"
cas 2 implementer "make valider refusé" "$(bash_ 'make valider P=P1 MSG=ok')"
cas 2 implementer "make -s valider refusé" "$(bash_ 'make -s valider P=P4 MSG=ok')"
cas 0 implementer "make check accepté" "$(bash_ 'make check')"
cas 2 implementer "formule de validation écrite par Bash refusée" "$(bash_ "echo '$vh' >> journal.md")"
cas 2 implementer "formule de validation dans new_string refusée" \
  "$(jq -nc --arg v "$vh" '{tool_name: "Edit", tool_input: {file_path: "NOTES.md", old_string: "a", new_string: $v}}')"
cas 2 implementer "formule de validation dans un MultiEdit refusée" \
  "$(jq -nc --arg v "$vh" '{tool_name: "MultiEdit", tool_input: {file_path: "NOTES.md", edits: [{old_string: "a", new_string: "b"}, {old_string: "c", new_string: $v}]}}')"
cas 2 implementer "libre écrit par Bash dans .sdlc-step refusé" "$(bash_ 'echo libre > .sdlc-step')"
cas 2 implementer "libre écrit par Write dans .sdlc-step refusé" "$(write "$root/.sdlc-step" libre)"
cas 0 libre "lire libre dans .sdlc-step accepté" "$(bash_ 'grep -c libre .sdlc-step')"
cas 0 cadrer "étape de cycle écrite dans .sdlc-step acceptée" "$(bash_ 'echo "tests T-1" > .sdlc-step')"

[ $fail = 0 ] && echo "check-cadre OK" || { echo "check-cadre : guard.sh ne fait pas ce que disent ses cas"; exit 1; }
