# backup-scripts — mémoire du projet

Sauvegarde des serveurs Linux personnels (serveur principal : `ichigo`).

- **Aujourd'hui** : scripts bash lancés depuis le PC, qui tirent le disque des serveurs par `rsync` puis l'archivent en `.tar.gz` ([existant](docs/technique/existant.md)).
- **Problème** : PC obligatoirement allumé, bande passante, pas de chiffrement ni de déduplication, succès annoncé même en cas d'échec ([problèmes connus](docs/technique/problemes-connus.md)).
- **Cible proposée, pas encore validée** : restic + resticprofile sur le serveur, qui pousse chaque nuit les données utiles (dumps PostgreSQL, Bitwarden, configs, volumes Docker) vers un stockage objet gratuit (Cloudflare R2), avec supervision Healthchecks et Discord ; le PC garde une 2ᵉ copie facultative ([nouvelle solution](docs/technique/nouvelle-solution.md)).
- **Contraintes** : un seul serveur, aucun budget, ≈ 20 Go sur le disque.

Ce fichier est le point d'entrée pour tout développement, humain ou IA.

## Documentation

| Sujet | Document |
|---|---|
| Index | [docs/README.md](docs/README.md) |
| Fonctionnement actuel des scripts | [docs/technique/existant.md](docs/technique/existant.md) |
| Bugs et limites de l'existant | [docs/technique/problemes-connus.md](docs/technique/problemes-connus.md) |
| Proposition de remplacement et questions ouvertes | [docs/technique/nouvelle-solution.md](docs/technique/nouvelle-solution.md) |
| Skills Claude Code, agents | [docs/technique/outils-ia.md](docs/technique/outils-ia.md) |
| Guide d'utilisation actuel (anglais) | [README.md](README.md) |

## Commandes

```bash
sudo ./scripts/inventory.sh  # sur le serveur : inventaire en lecture seule de ce qu'il faut sauvegarder, et volume
make install       # active les hooks git
make lint          # shellcheck sur les scripts (l'existant échoue encore : voir problemes-connus.md)
make claude-skills # resynchronise les skills tiers épinglés
make help
```

## Règles non négociables

1. **Aucune commande ne touche une vraie machine** (sauvegarde, restauration, `prune`, `rsync --delete`, SSH) sans demande explicite de l'utilisateur. Tester dans un dossier temporaire ou un conteneur jetable.
2. **Pas de secret dans le dépôt** : `secrets/var.sh`, phrases de passe, clés et URL de webhook restent hors git. Ne pas lire `secrets/var.sh` ; la structure est dans `secrets/var.dev.sh`.
3. **Un échec n'est jamais annoncé comme un succès** : chaque étape critique vérifie son code retour.
4. **Toute configuration de sauvegarde nouvelle ou modifiée se termine par un test de restauration** documenté.
5. **Scripts bash** : règles du skill `bash-scripting` (strict mode, guillemets, `rm -rf` protégé) ; zéro avertissement shellcheck dans le code neuf.
6. **Documentation à jour dans la même PR** que le changement ; une question tranchée est retirée de la liste de `nouvelle-solution.md`.
7. **Commits** au format du dépôt : gitmoji + type en français (`:bug: Bug : …`, `:memo: Doc : …`), sans trailer `Co-Authored-By` d'assistant IA (bloqué par `.githooks/commit-msg` et `.claude/settings.json`).
8. **Langue** : identifiants en anglais ; commentaires, messages et documentation en français.
9. **Une branche par sujet**, PR vers `main`.

## Façon de travailler

- **Lire avant de modifier.** Ne rien deviner : options de `borg`, `borgmatic`, `restic`, `rsync`, versions et prix se vérifient dans la doc (agent `docs-researcher`).
- **Solution la plus simple qui marche** : un outil maintenu plutôt que du bash maison ; pas de fonctionnalité spéculative.
- **Débogage** : reproduire avant de supposer ; dire quand une cause n'est pas certaine.
- **Réponses dans le chat** directes. La documentation et les messages de commit, eux, expliquent le *pourquoi*.

## Outils IA

Skills copiés dans `.claude/skills/` à des versions épinglées (même base que templify et cine-da, adaptée à un projet bash et système) + deux skills propres au projet : `bash-scripting` et `linux-backup`. Agents dans `.claude/agents/` :

| Agent | Modèle | Usage |
|---|---|---|
| `explorer` | Haiku | Recherche dans le dépôt et son historique |
| `docs-researcher` | Haiku | Vérification de documentation (restic, resticprofile, R2, systemd…) |
| `implementer` | Sonnet | Scripts, configuration, documentation |
| `reviewer` | Sonnet | Relecture |
| `security-auditor` | Opus | Audit de sécurité |

Détails : [docs/technique/outils-ia.md](docs/technique/outils-ia.md).

## Consignes de compaction

Lors d'un `/compact`, conserver : la branche et la PR en cours, les décisions prises et leur raison, les fichiers modifiés, les vérifications restant à lancer, les questions en attente côté utilisateur. Abandonner le contenu des fichiers lus et les sorties de commandes.
