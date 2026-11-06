# Proposition : sauvegarde « push » chiffrée, sans budget

**Statut : proposition, rien n'est encore implémenté.** Les points encore ouverts sont listés à la fin.

## Contexte (décisions prises)

| Point | Réponse |
|---|---|
| Serveurs | **Un seul** : `ichigo` |
| Budget | **Aucun** : pas de serveur de backup, pas d'abonnement de stockage |
| Ce qui tourne | Docker ; PostgreSQL ; Apache (configuration) ; Bitwarden en Docker ; documentation MkDocs ; bientôt Templify |
| Volume | ≈ 20 Go au total sur le serveur (à mesurer : voir plus bas, la partie utile est probablement bien plus petite) |

## Ce qu'on veut

| Besoin | Aujourd'hui | Cible |
|---|---|---|
| Ne pas dépendre du PC | Le PC doit être allumé à 1 h | Le serveur se sauvegarde **lui-même**, PC éteint |
| Bande passante du PC | Tout le disque transite à chaque fois vers le PC | Le PC ne reçoit rien (ou seulement les nouveautés, s'il garde une copie) |
| Place | ~1 archive complète par jour | Déduplication : un backup quotidien coûte la taille de ce qui a changé |
| Sécurité | Archives en clair, root SSH du PC vers le serveur | Chiffrement sur le serveur ; le stockage ne voit que des données chiffrées ; plus d'accès root entrant |
| Bases de données | Copie à chaud des fichiers PostgreSQL | Dump avant chaque backup |
| Alerte fiable | Le serveur s'alerte lui-même (muet s'il est en panne) | Alerte externe si **aucun** backup n'arrive |
| Restauration | Écrasement à chaud du `/` | Restauration d'un fichier, d'un dossier ou de tout, sur la machine de son choix |
| Coût | Électricité et disque du PC | **0 €** |

## La clé : ne sauvegarder que ce qui ne se recrée pas

Les 20 Go du serveur sont surtout du système et des images Docker, qui se réinstallent. Ce qui est **irremplaçable** est petit :

| Élément | À sauvegarder | Taille probable |
|---|---|---|
| PostgreSQL | **Dump** (`pg_dumpall`) avant chaque backup, pas les fichiers bruts | Quelques Mo à quelques centaines de Mo |
| Bitwarden | Son dossier de données + sa base (méthode selon Bitwarden officiel ou Vaultwarden, voir questions) | Quelques Mo |
| Apache | `/etc/apache2` (ou `/etc/httpd`), certificats `/etc/letsencrypt` | < 10 Mo |
| Docker | Fichiers `docker-compose.yml`, `.env`, **volumes de données** nommés ou montés | Variable |
| MkDocs | Rien si les sources sont dans git (`MathieuBesson/mkdocs`) ; sinon le dossier source, pas le site généré | ~0 |
| Templify | `.env` et `data/` (le code est dans git) | Petit |
| Système | `/etc`, `/root`, `/home`, crontabs, liste des paquets (`dpkg --get-selections`) | < 100 Mo |

Exclus : images et couches Docker (`/var/lib/docker/overlay2`, `image`), caches, journaux, `node_modules`, swap, sites générés.

Avec la compression et la déduplication, la sauvegarde complète tient très probablement sous **2 à 3 Go**, et chaque nuit n'ajoute que quelques Mo. **Cela rentre dans un stockage gratuit.**

En cas de perte du serveur : installer un système propre + Docker, restaurer `/etc` choisis, les compose et les volumes, réimporter les dumps. Plus fiable qu'écraser un `/` complet.

## Outil recommandé : restic + resticprofile

Sans budget, le stockage sera un **stockage objet gratuit compatible S3** (voir ci-dessous). Borg ne sait pas écrire directement dessus ; **restic** si.

- [restic](https://restic.net/) : chiffrement, déduplication, compression, un seul binaire, version 0.19 en 2026, nombreux stockages (S3, B2, SFTP, dossier local, rclone).
- [resticprofile](https://creativeprojects.github.io/resticprofile/) : fichier de configuration (TOML/YAML) qui décrit sources, exclusions, rétention, **commandes à lancer avant** (les dumps), **appels HTTP après succès ou échec** (Healthchecks, Discord), et génère le **timer systemd**.

Résultat : les ~250 lignes de bash actuelles sont remplacées par un profil d'une cinquantaine de lignes et un petit script de dumps.

> borgmatic reste un excellent choix si un jour un stockage Borg payant (Hetzner Storage Box, ~3,20 € HT/mois pour 1 To) devient acceptable : la structure de cette proposition ne change pas.

## Où stocker gratuitement

| Stockage | Gratuit | Remarque |
|---|---|---|
| **Cloudflare R2** (recommandé) | 10 Go/mois de stockage, sortie (téléchargement) gratuite, 1 M d'écritures et 10 M de lectures par mois ; offre permanente | Compatible S3, donc restic directement. L'activation demande d'enregistrer un moyen de paiement (à vérifier) ; au-delà de 10 Go, ≈ 0,015 $/Go/mois |
| Backblaze B2 | 10 premiers Go (selon la plupart des sources, à confirmer sur la page officielle) | Compatible S3 et backend natif restic ; téléchargements gratuits jusqu'à 3× le volume stocké |
| Google Drive / OneDrive via rclone | 15 Go / 5 Go avec le compte perso | Fonctionne (`restic -r rclone:…`) mais plus lent et quotas d'API ; solution de secours |
| Le PC | Disque existant | En **2ᵉ copie** seulement, voir ci-dessous |

### Règle 3-2-1 sans payer

1. **Les données** sur `ichigo`.
2. **Copie hors site, toujours à jour** : dépôt restic chiffré sur Cloudflare R2, alimenté chaque nuit par le serveur.
3. **Copie locale, quand le PC est allumé** (optionnelle) : le PC récupère seulement les nouveaux morceaux depuis R2 (`rclone sync` ou `restic copy`), par un timer qui rattrape le retard au démarrage. Quelques Mo par jour, plus de dépendance : si le PC reste éteint une semaine, rien n'est perdu.

## Sécurité

- **Mot de passe restic** : sans lui, les sauvegardes sont illisibles. Le garder **hors de Bitwarden aussi** (copie papier ou second gestionnaire), sinon il est perdu en même temps que le serveur qui héberge Bitwarden.
- Clés R2 limitées au seul bucket de backup ; fichier de configuration et secrets en `chmod 600`, root seulement.
- Protection contre un serveur compromis qui effacerait ses sauvegardes : la copie sur le PC sert de copie hors ligne ; à étudier, les règles de verrouillage d'objets de R2.
- Plus aucun accès SSH root depuis le PC ; le workflow de déploiement par `git pull` disparaît.

## Supervision

- **Healthchecks.io** (gratuit jusqu'à 20 contrôles) : resticprofile signale début, succès ou échec. Si rien n'arrive dans le délai (serveur éteint, timer cassé…), Healthchecks alerte par e-mail ou Discord. Corrige le défaut B6 de l'existant.
- **Discord** : le webhook actuel, appelé en cas d'échec (et éventuellement de succès).
- `restic check` chaque semaine, `restic check --read-data-subset=10%` chaque mois (attention aux quotas de lecture si le volume grossit).
- **Test de restauration** tous les trimestres : un dump PostgreSQL restauré dans un conteneur jetable, un dossier Bitwarden, une config Apache.

## Ce que devient ce dépôt

```
resticprofile/
  profiles.yaml          # profil d'ichigo : sources, exclusions, rétention, hooks, planification (sans secret)
scripts/
  dump-databases.sh      # dumps PostgreSQL (docker exec … pg_dumpall), Bitwarden, liste des paquets
  install.sh             # installe restic/resticprofile, la config, le timer (idempotent)
  restore-test.sh        # test de restauration guidé, dans un dossier temporaire
  pc-sync.sh             # optionnel : copie du dépôt R2 sur le PC
docs/
  exploitation.md        # installer, restaurer, changer de stockage, en cas de sinistre
```

CI légère : `shellcheck` sur les scripts. Les anciens scripts restent consultables dans l'historique git.

## Migration proposée

1. **Mesurer** ce qui est vraiment à sauvegarder : `sudo ./scripts/inventory.sh` (voir ci-dessous).
2. Créer le bucket R2 et une clé d'accès limitée à ce bucket ; créer le contrôle Healthchecks.
3. Écrire `dump-databases.sh` et le profil resticprofile ; `restic init` ; noter le mot de passe hors du serveur.
4. Premier backup à la main, puis activer le timer.
5. **Test de restauration** complet (dump PostgreSQL dans un conteneur jetable, Bitwarden, Apache).
6. Faire tourner l'ancien et le nouveau en parallèle deux semaines ; vérifier l'alerte en coupant volontairement un backup.
7. Retirer les crons, les anciens scripts, l'accès root SSH du PC et le workflow de déploiement.

## Mesurer avant de choisir

Le script `scripts/inventory.sh` fait l'inventaire, **en lecture seule**, de ce qui serait à sauvegarder sur le serveur, et en estime le volume :

```bash
sudo ./scripts/inventory.sh | tee inventaire.txt      # --no-db : sans interroger PostgreSQL
```

Il affiche :
- les disques et les dossiers système (`/etc`, `/root`, `/home`, `/opt`, `/srv`, `/var/www`, `/usr/local`, crontabs), avec le détail des plus gros sous-dossiers pour repérer ce qui se réinstalle ;
- la configuration Apache, les sites actifs et leurs `DocumentRoot` ;
- chaque conteneur Docker (y compris arrêté) : son dossier compose, ses volumes et montages. Les dossiers de données brutes des bases sont **exclus au profit d'un dump**, et Vaultwarden / Bitwarden officiel sont repérés avec la bonne méthode de sauvegarde ;
- la taille de chaque base PostgreSQL (une requête `SELECT` de lecture), dans Docker ou sur la machine ;
- les dépôts git, avec leur remote (identifiants masqués), le volume de leurs fichiers non versionnés (`.env`, `data/`…) et une alerte en cas de modifications non commitées ;
- ce qui est à exclure (`/var/lib/docker`, journaux, caches, `node_modules`…) ;
- une **synthèse** : la liste des chemins retenus et exclus, le total sans doublon, et une estimation compressée.

Le rapport ne contient aucun secret (pas de variables d'environnement, URL git masquées), mais des noms de chemins et de conteneurs : le relire avant de le partager.

## Questions encore ouvertes

1. Bitwarden **officiel** (base MSSQL, sauvegarde intégrée dans `bwdata/mssql/backups`) ou **Vaultwarden** (SQLite) ? La méthode de dump en dépend.
2. Où sont les données Docker : volumes nommés ou dossiers montés (et lesquels) ?
3. Les sources MkDocs sont-elles toutes dans git ?
4. Un compte Cloudflare (pour R2) est-il acceptable, sachant qu'un moyen de paiement est probablement demandé même pour l'offre gratuite ? Sinon : Backblaze B2.
5. Le PC garde-t-il une 2ᵉ copie (recommandé, gratuit) ?

Sources : [restic](https://restic.net/), [resticprofile](https://creativeprojects.github.io/resticprofile/), [tarifs Cloudflare R2](https://developers.cloudflare.com/r2/pricing/), [calculateur R2](https://r2-calculator.cloudflare.com/), [tarifs Backblaze B2 (oct. 2026)](https://upstash.com/blog/backblaze-b2-pricing-explained-2026.md), [restic + R2](https://rohitkumarankam.pages.dev/blog/r2-restic-backups), [Healthchecks.io](https://healthchecks.io/), [borgmatic](https://torsion.org/borgmatic/).
