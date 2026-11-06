.DEFAULT_GOAL := help
SHELL_SCRIPTS := $(shell git ls-files '*.sh' '.githooks/*' | grep -v '^\.claude/skills/')

.PHONY: help
help: ## Liste les commandes
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "} {printf "  %-14s %s\n", $$1, $$2}'

.PHONY: install
install: git-hooks ## Prépare le dépôt pour le développement

.PHONY: git-hooks
git-hooks: ## Active les hooks git du projet (.githooks)
	git config core.hooksPath .githooks

.PHONY: lint
lint: ## shellcheck sur tous les scripts du dépôt (hors skills tiers)
	@command -v shellcheck >/dev/null || { echo "shellcheck absent : apt install shellcheck" >&2; exit 1; }
	shellcheck -x $(SHELL_SCRIPTS)

.PHONY: claude-skills
claude-skills: ## Resynchronise les skills Claude Code épinglés (puis relire le diff)
	./scripts/claude/sync-skills.sh
