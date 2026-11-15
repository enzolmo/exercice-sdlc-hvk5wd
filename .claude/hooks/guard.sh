#!/usr/bin/env bash
# PreToolUse sur Edit/Write/Bash : exit 2 refuse l'action et renvoie le message à l'agent.
input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
path=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input")
root=${CLAUDE_PROJECT_DIR:-$PWD}
# Un chemin absolu peut viser un autre worktree : ses règles et son .sdlc-step sont ceux de son propre dépôt
case $path in
  /*) d=$(dirname "$path"); while [ ! -d "$d" ]; do d=$(dirname "$d"); done
    root=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null || echo "$root") ;;
esac
rel=${path#"$root"/}
read -r step ticket _ <"$root/.sdlc-step" 2>/dev/null
# Une commande n'est tracée que par son premier mot : le reste peut contenir un secret
target=${rel:-${cmd%% *}}

deny() {
  local rule dir=$root/docs/tickets/$ticket log
  rule=$(grep -oE '\(R[0-9]+\)' <<<"$1" | tail -1 | tr -d '()')
  if [ -n "$ticket" ] && [ -d "$dir" ]; then log=$dir/events.jsonl; else log=$root/.sdlc/guard.log; mkdir -p "$root/.sdlc"; fi
  jq -nc --arg ts "$(date -u +%FT%TZ)" --arg ticket "$ticket" --arg step "$step" --arg rule "$rule" --arg target "$target" \
    --arg session "$(cat "$root/.sdlc/session" 2>/dev/null)" \
    '{event: "guard_denied", ts: $ts, ticket: $ticket, step: $step, rule: $rule, target: $target, session: $session}' >>"$log"
  echo "guard.sh : $1. Voir sdlc/constitution.md." >&2
  exit 2
}

if [ -n "$cmd" ]; then
  grep -Eq 'make([[:space:]].*)?[[:space:]]valider' <<<"$cmd" && deny "make valider est la signature de l'humain (R12)"
  grep -q 'Validation humaine' <<<"$cmd" && grep -Eq '>|tee|-i' <<<"$cmd" && deny "seul l'humain écrit « Validation humaine » (R12)"
  grep -Eq 'libre.*(>|tee).*\.sdlc-step' <<<"$cmd" && deny "seul l'humain écrit « libre » dans .sdlc-step (R3)"
  exit 0
fi

[ -z "$path" ] && exit 0

case $rel in
  .env | .env.* | */.env | */.env.* | *.pem | .git/*) deny "$rel refusé : secret ou dépôt git, jamais par l'agent (R3)" ;;
  .sdlc-step) jq -r '[.tool_input.content, .tool_input.new_string] | map(select(.)) | join("\n")' <<<"$input" \
    | grep -qw libre && deny "seul l'humain écrit « libre » dans .sdlc-step (R3)" ;;
esac
if [ -z "$step" ]; then
  case $rel in
    api/* | web/*) deny "$rel refusé : pas d'étape dans .sdlc-step, pas d'écriture de code (R3)" ;;
  esac
fi

# R3 : fichiers du cadre, humain seulement — sauf en étape « libre », posée à la main pour un chantier du cadre
if [ "$step" != libre ]; then
  case $rel in
    sdlc/* | .claude/* | Makefile | CLAUDE.md) deny "$rel refusé : fichier du cadre, humain seulement (R3)" ;;
  esac
fi
if [ "$step" = implementer ]; then
  case $rel in
    api/tests/* | *.test.ts) deny "$rel refusé : tests gelés pendant 04 Implémenter (R2)" ;;
  esac
fi
jq -r '[.tool_input.content, .tool_input.new_string, (.tool_input.edits // [] | .[].new_string)] | map(select(.)) | join("\n")' <<<"$input" \
  | grep -q 'Validation humaine' && deny "seul l'humain écrit « Validation humaine » (R12)"
exit 0
