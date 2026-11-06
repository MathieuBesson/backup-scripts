#!/bin/bash
# Installe (ou met à jour) les skills Claude Code tiers du projet dans .claude/skills/.
#
# Les skills sont copiés dans le dépôt (et non installés comme plugins) : c'est la seule façon qu'ils
# soient disponibles à la fois dans Claude Code en local et dans les sessions Claude Code cloud,
# qui ne chargent pas les plugins déclarés dans .claude/settings.json.
#
# Chaque source est épinglée sur un commit relu. Pour mettre à jour : changer le SHA, relancer le
# script, relire le diff (hooks, scripts, accès réseau) avant de commiter.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILLS_DIR="$ROOT/.claude/skills"
THIRD_PARTY_DIR="$ROOT/.claude/third-party"
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

# dépôt | commit | licence | "chemin_source:nom_du_skill" séparés par des espaces
SOURCES=(
  "obra/superpowers|2ce8aa15d05bd57213e6f746f953aafb7ded7a8b|MIT|skills/brainstorming:brainstorming skills/dispatching-parallel-agents:dispatching-parallel-agents skills/executing-plans:executing-plans skills/finishing-a-development-branch:finishing-a-development-branch skills/receiving-code-review:receiving-code-review skills/requesting-code-review:requesting-code-review skills/subagent-driven-development:subagent-driven-development skills/systematic-debugging:systematic-debugging skills/test-driven-development:test-driven-development skills/using-git-worktrees:using-git-worktrees skills/using-superpowers:using-superpowers skills/verification-before-completion:verification-before-completion skills/writing-plans:writing-plans"
  "tw93/Waza|840f926af48c98e0b36a3a64658a9ddc4cf7e716|MIT|skills/check:check skills/hunt:hunt skills/think:think skills/health:health"
  "cloudflare/security-audit-skill|c1c8a8c1471069fb0e188eeaff69b8e8db6564a8|MIT|skills/security-audit:security-audit"
  "ahmedasmar/devops-claude-skills|1489c33ad8829a11219e423327d6b59f8339cee4|MIT (README)|ci-cd/skills:ci-cd"
  "wondelai/skills|c172996495bed0fcd26896a9416b2093fd7073f0|MIT|clean-code:clean-code refactoring-patterns:refactoring-patterns working-with-legacy-code:working-with-legacy-code"
)

mkdir -p "$SKILLS_DIR" "$THIRD_PARTY_DIR/licenses"
{
  echo "# Skills tiers"
  echo
  echo "Généré par \`scripts/claude/sync-skills.sh\` : ne pas modifier ces dossiers à la main."
  echo
  echo "| Skill | Source | Commit | Licence |"
  echo "|---|---|---|---|"
} > "$WORK_DIR/THIRD_PARTY.md"

for entry in "${SOURCES[@]}"; do
  IFS='|' read -r repo sha license mappings <<< "$entry"
  checkout="$WORK_DIR/$(echo "$repo" | tr / _)"
  git clone --quiet --filter=blob:none "https://github.com/$repo" "$checkout"
  git -C "$checkout" checkout --quiet "$sha"
  if [ -f "$checkout/LICENSE" ]; then
    cp "$checkout/LICENSE" "$THIRD_PARTY_DIR/licenses/$(echo "$repo" | tr / _).LICENSE"
  fi

  for mapping in $mappings; do
    src="${mapping%%:*}"
    name="${mapping##*:}"
    rm -rf "${SKILLS_DIR:?}/$name"
    cp -R "$checkout/$src" "$SKILLS_DIR/$name"
    # Tests des auteurs inutiles à l'exécution
    find "$SKILLS_DIR/$name" -name '*.test.cjs' -delete
    echo "| \`$name\` | [$repo](https://github.com/$repo) | \`${sha:0:7}\` | $license |" >> "$WORK_DIR/THIRD_PARTY.md"
  done
done

cp "$WORK_DIR/THIRD_PARTY.md" "$THIRD_PARTY_DIR/THIRD_PARTY.md"
echo "Skills synchronisés dans $SKILLS_DIR"
