#!/usr/bin/env bash
# SessionStart : garde l'id de session dans .sdlc/session du dépôt courant, que le Makefile et guard.sh joignent à chaque événement.
input=$(cat)
cwd=$(jq -r '.cwd // empty' <<<"$input")
root=$(git -C "${cwd:-.}" rev-parse --show-toplevel 2>/dev/null) || exit 0
mkdir -p "$root/.sdlc" && jq -r '.session_id // empty' <<<"$input" >"$root/.sdlc/session"
