# Outils IA du projet (Claude Code)

Même organisation que templify et cine-da : les skills sont **copiés dans le dépôt** (`.claude/skills/`), à des commits épinglés et relus, pour être disponibles dans Claude Code en local comme dans les sessions cloud, sans installation de plugin.

La sélection est adaptée à un projet **bash et système** : pas de skill front, ni d'architecture logicielle (DDD, hexagonale), sans objet ici.

## Skills tiers

| Outil | Source | Ce qu'il apporte | Utilisation |
|---|---|---|---|
| **Superpowers** (13 skills) | [obra/superpowers](https://github.com/obra/superpowers) | Méthode : brainstorming, plan, TDD, débogage systématique, vérification avant de déclarer terminé, revue de code, worktrees, sous-agents | Automatique selon la tâche, ou `/writing-plans`, `/systematic-debugging`… |
| **Waza** (4 skills) | [tw93/Waza](https://github.com/tw93/Waza) | `check` (revue d'un diff ou d'une PR), `hunt` (cause racine), `think` (challenger une conception), `health` (audit de la configuration Claude Code) | `/check`, `/hunt`, `/think`, `/health` |
| **security-audit** | [cloudflare/security-audit-skill](https://github.com/cloudflare/security-audit-skill) | Audit de sécurité en 6 phases, constats contre-vérifiés | `/security-audit` |
| **ci-cd** | [ahmedasmar/devops-claude-skills](https://github.com/ahmedasmar/devops-claude-skills) | GitHub Actions, DevSecOps, diagnostic de pipelines | Automatique sur les sujets CI/CD |
| **wondelai** (3 skills) | [wondelai/skills](https://github.com/wondelai/skills) | `clean-code`, `refactoring-patterns`, `working-with-legacy-code` (changer sûrement du code sans tests, tests de caractérisation) | Automatique, ou `/working-with-legacy-code` avant de toucher aux anciens scripts |

Versions et licences : [.claude/third-party/THIRD_PARTY.md](../../.claude/third-party/THIRD_PARTY.md). Les fichiers sont identiques à ceux de templify, au formatage Python près (templify reformate ses copies).

## Skills du projet

Écrits pour ce dépôt, non gérés par le script de synchronisation :

| Skill | Rôle |
|---|---|
| `bash-scripting` | Règles d'écriture et de relecture des scripts root : strict mode, guillemets, comparaisons numériques, `rm -rf` protégé, idempotence, timers systemd, shellcheck |
| `linux-backup` | Principes de sauvegarde (3-2-1, push chiffré, dumps de bases, supervision externe, test de restauration), opérations interdites sans accord, repères borgmatic/restic, démarche en cas d'incident |

## Écarté par rapport à templify

| Élément | Raison |
|---|---|
| Waza `ui` | Pas d'interface |
| `clean-architecture`, `domain-driven-design` | Pas de modèle métier ni de couches applicatives |
| Agent `adapter-writer` | Pas d'adaptateurs externes |
| CodeGraph (MCP) | Ne gère pas bash ; le dépôt est petit |
| devops `monitoring-observability` | À reconsidérer si une supervision type Prometheus apparaît |
| wondelai `release-it` | Orienté services distribués |

## Agents

| Agent | Modèle | Usage |
|---|---|---|
| `explorer` | Haiku | Recherche dans le dépôt et l'historique git |
| `docs-researcher` | Haiku | Doc officielle borg, borgmatic, restic, systemd, Healthchecks, tarifs |
| `implementer` | Sonnet | Scripts, configuration, documentation, avec `make lint` |
| `reviewer` | Sonnet | Relecture centrée sur les échecs silencieux et la destruction de données |
| `security-auditor` | Opus | Audit : accès SSH, clés de chiffrement, effacement des sauvegardes, CI |

## Configuration (`.claude/settings.json`)

- Session principale sur Opus, exécution déléguée aux agents.
- Pas d'attribution IA dans les commits et PR.
- Lecture interdite de `secrets/var.sh`, `.env`, `*.key`, `*.passphrase`.
- Sortie Bash plafonnée à 20 000 caractères.

Hook git `.githooks/commit-msg` (activé par `make install`) : refuse un trailer `Co-Authored-By` d'assistant IA.

## Mise à jour

1. Changer le commit dans `scripts/claude/sync-skills.sh`.
2. `make claude-skills`.
3. **Relire le diff** (nouveaux hooks, scripts, appels réseau, consignes inhabituelles), puis commiter dans une PR dédiée.

La sélection est alignée sur templify et cine-da : une mise à jour faite d'un côté est à reporter de l'autre.
