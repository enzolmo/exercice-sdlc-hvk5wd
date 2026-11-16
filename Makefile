SHELL := /bin/bash
.PHONY: test api web install check check-red check-scope check-cadre audit valider noter bilan run-check run-check-red

# Tous les tests (API Rust puis front TypeScript).
test:
	cd api && cargo test
	cd web && npm install --silent && npm test

# L'API sur http://127.0.0.1:3000
api:
	cd api && cargo run

# Le front sur http://localhost:5173 (l'API doit tourner)
web:
	cd web && npm install --silent && npm run dev

# Ticket actif : 2e mot de .sdlc-step (écrit par les commandes /sdlc-*), ou make <cible> T=T-xxx
T ?= $(word 2,$(shell cat .sdlc-step 2>/dev/null))
STEP = $(word 1,$(shell cat .sdlc-step 2>/dev/null))
SPEC = docs/tickets/$(T)/spec.md
JOURNAL = docs/tickets/$(T)/journal.md
# Base du ticket : le commit qui a ajouté sa spec ; HEAD tant qu'elle n'est pas commitée
BASE = $(or $(shell git log --diff-filter=A --format=%H -- $(SPEC) | tail -1),HEAD)
CHANGED = { git diff --name-only $(BASE); git ls-files --others --exclude-standard; } | sort -u | grep -vE '^(sdlc/|\.claude/|Makefile$$|CLAUDE\.md$$)'
SOCLE = awk '/^```/ { f = /^```socle/; next } f && NF { print $$1 }' $(SPEC)
TESTS_RE = ^api/tests/.+\.rs$$|\.test\.ts$$
export MSG

EVENTS = docs/tickets/$(T)/events.jsonl
# Traces attendues d'un cycle : P1 vaut pour 01, une itération VERT pour P3 ; 06 est l'entrée que bilan écrit lui-même
ETAPES = P1|02 Planifier|03 Tests · P2|04 Implémenter|P3|05 Revue|P4
# Une étape sautée se signe par la porte skip, le nom de l'étape dans le message
MANQUANTES = awk -v etapes='$(ETAPES)' 'BEGIN { n = split(etapes, e, "|") } \
  /^\#\# / { skip = index($$0, "· skip ·") > 0; for (i = 1; i <= n; i++) if (index($$0, "· " e[i])) ok[i] = 1; next } \
  /^make check : VERT/ { for (i = 1; i <= n; i++) if (e[i] == "P3") ok[i] = 1 } \
  skip { for (i = 1; i <= n; i++) if (index($$0, e[i])) ok[i] = 1 } \
  END { for (i = 1; i <= n; i++) if (!ok[i]) print e[i] }' $(JOURNAL)
SESSION = $$(cat .sdlc/session 2>/dev/null)

# $(call journaliser,titre,corps,porte,résultat,itération,auteur) : une entrée au journal et le même événement dans events.jsonl, jamais l'un sans l'autre
journaliser = if [ -n "$(T)" ] && [ -d docs/tickets/$(T) ]; then \
  printf '\n\#\# %s · %s\n%s\n' "$$(date '+%Y-%m-%d %H:%M')" "$(1)" "$(2)" >> $(JOURNAL); \
  jq -nc --arg ts "$$(date -u +%FT%TZ)" --arg ticket "$(T)" --arg step "$(STEP)" --arg title "$(1)" --arg gate "$(3)" \
    --arg result "$(4)" --arg it "$(5)" --arg actor "$(6)" --arg session "$(SESSION)" \
    '{event: "journal", ts: $$ts, ticket: $$ticket, step: $$step, title: $$title, gate: $$gate, result: $$result, iteration: ($$it | tonumber? // null), actor: $$actor, session: $$session}' >> $(EVENTS); fi

# P3 · Vert ; journalisée seulement pendant 04, où elle numérote l'itération de B2 (remise à zéro par une revue)
check:
	@log=$$(mktemp); $(MAKE) -s --no-print-directory -f $(firstword $(MAKEFILE_LIST)) run-check 2>&1 | tee $$log; st=$${PIPESTATUS[0]}; \
	lab=$$(grep '^== ' $$log | tail -1 | cut -c4-); body="make check : VERT"; \
	[ $$st = 0 ] || body="make check : ROUGE à l'étape $${lab:-scope}"$$'\n'"$$(grep -E -A5 'error|FAILED|panicked|warning:|check :|check-scope :' $$log | head -12)"; \
	if [ "$(STEP)" = implementer ]; then \
	  k=$$(awk '/^## .*· 05 Revue/ { n = 0 } /^## .*· itération/ { n++ } END { print n + 1 }' $(JOURNAL) 2>/dev/null); k=$${k:-1}; \
	  titre="04 Implémenter · itération $$k/3"; [ "$$k" -le 3 ] || echo "B2 : borne de 3 itérations dépassée, escalade vers l'humain"; \
	  $(call journaliser,$$titre,$$body,P3,$$([ $$st = 0 ] && echo VERT || echo ROUGE),$$k,make); \
	fi; rm -f $$log; exit $$st

run-check: check-scope check-cadre
	@echo "== fmt" && cd api && cargo fmt --check
	@echo "== clippy" && cd api && cargo clippy --all-targets -- -D warnings
	@echo "== cargo test" && cd api && cargo test
	@echo "== npm test" && cd web && npm install --silent && npm test
	@echo "== tests gelés" && git diff --quiet HEAD -- api/tests '*.test.ts' && test -z "$$(git ls-files --others --exclude-standard api/tests '*.test.ts')" \
	  || { echo "check : tests gelés modifiés depuis le dernier commit"; exit 1; }
	@echo "check OK"

# P2 · Rouge, journalisée
check-red:
	@log=$$(mktemp); $(MAKE) -s --no-print-directory -f $(firstword $(MAKEFILE_LIST)) run-check-red 2>&1 | tee $$log; st=$${PIPESTATUS[0]}; \
	body="make check-red : $$([ $$st = 0 ] && echo OK || echo ÉCHEC)"$$'\n'"$$(grep -E '^test |test result|check-red|check-scope :' $$log | grep -v ' 0 passed; 0 failed')"; \
	$(call journaliser,03 Tests · P2,$$body,P2,$$([ $$st = 0 ] && echo OK || echo ÉCHEC),,make); rm -f $$log; exit $$st

run-check-red: check-scope
	@! grep -rnE 'SystemTime::now|Local::now|Utc::now|sleep\(' api/tests || { echo "check-red : horloge ou sleep dans api/tests"; exit 1; }
	@out=$$($(CHANGED) | grep -v '^docs/tickets/$(T)/' | grep -vE '$(TESTS_RE)' | grep -vxF -f <($(SOCLE))); \
	test -z "$$out" || { echo "check-red : seuls des tests et le bloc socle de la spec peuvent bouger à cette étape :"; echo "$$out"; exit 1; }
	@cd api && cargo test --no-run
	@cd api && cargo fmt --check
	@cd api && cargo clippy --all-targets -- -D warnings
	@new=$$($(CHANGED) | grep -E '$(TESTS_RE)'); \
	test -n "$$new" || { echo "check-red : aucun test nouveau"; exit 1; }; \
	old=""; for f in api/tests/*.rs; do echo "$$new" | grep -qxF "$$f" || old="$$old --test $$(basename $$f .rs)"; done; \
	(cd api && cargo test --lib --bins $$old) || { echo "check-red : un ancien test casse"; exit 1; }; \
	for f in $$new; do out=""; case $$f in \
	  api/*) out=$$(cd api && cargo test --test $$(basename $$f .rs) 2>&1); echo "$$out" | grep -q 'test result: FAILED. 0 passed' ;; \
	  web/*) ! (cd web && npx vitest run $${f#web/}) ;; \
	esac || { echo "$$out"; echo "check-red : $$f doit être entièrement rouge"; exit 1; }; \
	echo "$$out" | grep -E '^test |test result'; done; \
	echo "check-red OK : nouveaux tests rouges, anciens verts"

# R13 · Le hook et les cibles de trace rejouent leurs cas : entrées connues, sorties attendues
check-cadre:
	@echo "== cadre"; st=0; for t in .claude/hooks/test-guard.sh .claude/hooks/test-traces.sh; do \
	  $$t | grep -v '^ok'; [ $${PIPESTATUS[0]} = 0 ] || st=1; done; exit $$st

# Vulnérabilités connues des dépendances ; hors de make check car elle interroge le réseau
audit:
	@echo "== audit"
	@if command -v cargo-audit >/dev/null; then cd api && cargo audit; else echo "audit : cargo-audit absent (cargo install cargo-audit), API non auditée"; fi
	@cd web && npm audit --audit-level=high

# N'écrire que dans le bloc Fichiers de la spec (plus docs/tickets/<T>/ et NOTES.md)
check-scope:
	@test -n "$(T)" || { echo "check-scope : ticket inconnu, lancer une commande /sdlc-* ou make $@ T=T-xxx"; exit 1; }
	@test -f $(SPEC) || { echo "check-scope : $(SPEC) absent"; exit 1; }
	@out=$$($(CHANGED) | awk -v t="docs/tickets/$(T)/" \
	  'FNR == NR { if (/^```/) f = /^```files/; else if (f && NF) ok[$$1] = 1; next } \
	   !($$0 in ok) && index($$0, t) != 1 && $$0 != "NOTES.md"' $(SPEC) -); \
	test -z "$$out" || { echo "check-scope : hors du bloc Fichiers de $(SPEC) :"; echo "$$out"; exit 1; }
	@echo "check-scope OK ($(T), base $(BASE))"

# Décision humaine à une porte : make valider P=P1 MSG="hypothèses 1 et 2 validées, 3 corrigée en 422"
valider:
	@test -n "$(P)" -a -n "$$MSG" || { echo 'usage : make valider P=P1|P4|escalade|skip MSG="décision et motif"'; exit 1; }
	@test -d docs/tickets/$(T) || { echo "valider : docs/tickets/$(T) absent"; exit 1; }
	@body="Validation humaine ($$(git config user.name)) : $$MSG"; $(call journaliser,$(P) · validation humaine,$$body,$(P),validé,,$$(git config user.name))
	@tail -3 $(JOURNAL)

# Totaux du cycle, ajoutés au journal à l'étape 06 ; un événement commit par commit du ticket, avec la session qui livre
bilan:
	@test -d docs/tickets/$(T) || { echo "bilan : docs/tickets/$(T) absent"; exit 1; }
	@miss=$$($(MANQUANTES)); [ -z "$$miss" ] || { sed 's/^/trace manquante : /' <<<"$$miss"; exit 1; }
	@for sha in $$(git log --reverse --format=%H $(BASE)~1..HEAD 2>/dev/null); do grep -qs "\"sha\":\"$$sha\"" $(EVENTS) || \
	  jq -nc --arg ts "$$(date -u +%FT%TZ)" --arg ticket "$(T)" --arg sha "$$sha" --arg session "$(SESSION)" \
	    '{event: "commit", ts: $$ts, ticket: $$ticket, sha: $$sha, session: $$session}' >> $(EVENTS); done
	@b="itérations B2 : $$(grep -c '^## .*· itération' $(JOURNAL)) · tours B3 : $$(grep -c '^## .*· 05 Revue · tour' $(JOURNAL)) · escalades : $$(grep -c '^## .*· escalade ·' $(JOURNAL)) · validations humaines : $$(grep -c '^Validation humaine' $(JOURNAL))"; \
	b="$$b · refus du hook : $$(jq -c 'select(.event == "guard_denied")' $(EVENTS) 2>/dev/null | wc -l | tr -d ' ')"; \
	$(call journaliser,06 Livrer · bilan,$$b,,,,make); echo "$$b"

# Entrée de l'agent au journal : make noter TITRE="02 Planifier" MSG="4 tâches ; critères couverts : C1…C5"
noter:
	@case "$(TITRE)" in 0[1-6]\ *) ;; *) echo 'noter : TITRE commence par une étape (01 à 06), jamais une porte'; exit 1 ;; esac
	@! printf '%s %s' "$(TITRE)" "$$MSG" | grep -qi 'validation humaine' || { echo "noter : seul l'humain signe une porte (R12)"; exit 1; }
	@test -n "$$MSG" -a -d docs/tickets/$(T) || { echo 'usage : make noter TITRE="0X …" MSG="…", ticket actif requis'; exit 1; }
	@$(call journaliser,$(TITRE),$$MSG,,,,agent)
