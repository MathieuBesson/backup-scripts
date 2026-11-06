# Fonctionnement actuel (scripts bash)

État du dépôt au 6 novembre 2026 (dernier changement de code : 31 août 2024). Ce document décrit **ce qui existe**, sans le juger ; les défauts sont listés dans [problemes-connus.md](problemes-connus.md).

## En une phrase

Une machine « de sauvegarde » (en pratique le PC personnel) se connecte en SSH root à chaque serveur, copie son système de fichiers avec `rsync`, en fait une archive `.tar.gz` datée, supprime les archives de plus de 9 mois et prévient sur Discord. Sur chaque serveur sauvegardé, une tâche cron vérifie la date du dernier backup et alerte s'il est trop ancien.

## Schéma

```
 Machine de sauvegarde (PC)                       Serveur sauvegardé (ex. « ichigo »)
 ─────────────────────────                        ───────────────────────────────────
 cron : backup                                    cron : check-backup-time
   │                                                │
   │ 1. rsync -aAXHz root@IP:/  ──── SSH (pull) ───▶│ lecture de tout le disque
   │    → FOLDER_BACKUP_TARGET/backup-tmp/          │
   │ 2. tar -zcf <nom>-<date>_<epoch>_.tar.gz       │
   │    puis rm -rf backup-tmp/                     │
   │ 3. ssh root@IP "echo <epoch> > …" ────────────▶│ FOLDER_BACKUP_PARAMETERS/timestamp-last-backup
   │ 4. suppression des archives > 9 mois           │
   │ 5. webhook Discord                             │ si timestamp trop vieux → webhook Discord
   ▼                                                ▼
 FOLDER_BACKUP_TARGET/*.tar.gz                    (rien d'autre n'est stocké sur le serveur)
```

## Arborescence

| Chemin | Rôle |
|---|---|
| `bin/backup.sh` | Sauvegarde de tous les serveurs configurés, ou d'un seul (`backup <clé>`) |
| `bin/restore.sh` | Restauration d'un serveur à partir d'une archive |
| `bin/check-backup-time.sh` | À lancer **sur le serveur sauvegardé** : alerte si le dernier backup est trop ancien |
| `src/function.sh` | Fonctions partagées : notification Discord, contrôle de l'utilisateur, recherche de la configuration d'un serveur |
| `utils/pre-script.sh` | Chargé en tête de chaque script : charge `secrets/var.sh` et `src/function.sh`, impose l'utilisateur `root` |
| `secrets/var.dev.sh` | Modèle de configuration (versionné) ; la vraie configuration `secrets/var.sh` est ignorée par git |
| `.github/workflows/main.yml` | « CD » : à chaque push sur `main`, `git pull` dans `/opt/backup-scripts` sur une machine distante, par SSH |
| `README.md` | Guide d'utilisation (en anglais) |
| `LICENSE` | GPL v3 |

## Configuration (`secrets/var.sh`)

Fichier bash sourcé par tous les scripts. Il doit exister **sur la machine de sauvegarde et sur chaque serveur sauvegardé** (le serveur en a besoin pour `check-backup-time` et le webhook).

Structure :

```bash
declare -A SERVERS     # clé = nom court du serveur, valeur = sérialisation `declare -p SERVER`
declare -A SERVER      # configuration d'un serveur (tableau associatif)

SERVER=(
  [NAME]="ichigo"
  [IP]="…"
  [BACKUP_USER]="root"
  [FOLDER_BACKUP_SOURCE]="/"
  [FOLDER_BACKUP_TARGET]="/chemin/des/archives/ichigo"
  [FOLDER_BACKUP_GLOBAL]="/chemin/des/archives"
  [FOLDER_BACKUP_PARAMETERS]="/chemin/de/config/sur/le/serveur"
  [NUMBER_OF_DAYS_WITHOUT_WARNING]="7"
)
SERVERS["ichigo"]=$(declare -p SERVER)   # répété pour chaque serveur

DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/…"
NAME_CURRENT_SERVER="ichigo"             # utilisé uniquement sur le serveur sauvegardé
```

Pour lire la configuration d'un serveur, les scripts parcourent `SERVERS` et font `eval "${SERVERS[$KEY]}"`, ce qui redéfinit la variable globale `SERVER`.

| Clé | Utilisée par | Rôle |
|---|---|---|
| `NAME` | tous | Nom du serveur, doit valoir `NAME_CURRENT_SERVER` côté serveur |
| `IP` | backup, restore, messages | Adresse SSH du serveur |
| `BACKUP_USER` | backup, restore | Utilisateur SSH (root recommandé pour garder propriétaires et droits) |
| `FOLDER_BACKUP_SOURCE` | backup, restore | Dossier sauvegardé sur le serveur (en pratique `/`) |
| `FOLDER_BACKUP_TARGET` | backup, restore | Dossier des archives sur la machine de sauvegarde |
| `FOLDER_BACKUP_GLOBAL` | **aucun script** | Prévu pour regrouper les sauvegardes, jamais lu |
| `FOLDER_BACKUP_PARAMETERS` | backup, check | Dossier sur le serveur où est écrit `timestamp-last-backup` |
| `NUMBER_OF_DAYS_WITHOUT_WARNING` | check | Nombre de jours sans backup avant l'alerte |

## Scripts en détail

### Prélude commun (`utils/pre-script.sh`)

1. Calcule le dossier du script (suit les liens symboliques avec `realpath`, ce qui permet `ln -s …/bin/backup.sh /usr/bin/backup`).
2. Source `secrets/var.sh` puis `src/function.sh`.
3. `check_is_launcher_user root` : quitte si l'utilisateur courant n'est pas root (via `whoami` depuis le commit `0804742`, car `$USER` est vide sous cron).

Aucun `set -e` / `set -u` / `pipefail` : une commande qui échoue n'arrête pas le script.

### `backup [clé]`

1. Notification Discord « Backup des serveurs en cours… ».
2. Si une clé est passée, vérifie qu'un serveur de ce `NAME` existe (sinon quitte).
3. Pour chaque serveur (ou seulement celui dont la **clé** `SERVERS[...]` vaut l'argument) :
   1. `pull_backup` : `mkdir -p TARGET/backup-tmp` puis
      `rsync -aAXHzovg --numeric-ids USER@IP:SOURCE --exclude={/dev/,/proc/,/sys/,/tmp/,/run/,/mnt/,/media/,/lost+found} TARGET/backup-tmp` ;
   2. `compress_folder` : `tar -zcf TARGET/<NAME>-<AAAA-MM-JJ-HH-MM-SS>_<epoch>_.tar.gz -C backup-tmp .`, puis `rm -rf backup-tmp` ;
   3. `save_timestamp_last_backup` : `ssh USER@IP "echo <epoch> > PARAMETERS/timestamp-last-backup"` (l'epoch est calculé côté machine de sauvegarde) ;
   4. `delete_old_backup` : supprime chaque `TARGET/*.tar.gz` dont l'epoch (2ᵉ champ séparé par `_` du chemin) est antérieur à « maintenant − 9 mois » ;
   5. notification Discord de succès pour ce serveur.
4. Notification Discord « Backup des serveurs terminé ».

Format du nom d'archive : `ichigo-2023-01-29-22-34-28_1675028068_.tar.gz`. L'epoch entre `_` sert à la rétention.

### `restore <nom> <archive>`

1. Vérifie la présence des deux arguments, que le serveur existe dans la configuration et que le fichier d'archive existe (chemin relatif au dossier courant ou absolu).
2. Notification Discord « Restauration … en cours ».
3. `restore_server` :
   1. décompresse l'archive dans `TARGET/backup-tmp/` ;
   2. `rsync -aAXHvzog --delete --numeric-ids backup-tmp/ USER@IP:SOURCE --exclude={…mêmes exclusions…}` : **le serveur est écrasé à chaud, et les fichiers absents de l'archive sont supprimés** ;
   3. `rm -rf backup-tmp/`.
4. Notification Discord de succès.

> Le README montre `restore ichigo ichigo <archive>` (3 arguments) ; le script n'en lit que 2 : `restore ichigo <archive>`.

### `check-backup-time` (sur le serveur sauvegardé)

1. Sélectionne la configuration dont `NAME` vaut `NAME_CURRENT_SERVER`.
2. Lit `PARAMETERS/timestamp-last-backup`.
3. Si ce timestamp est plus ancien que `NUMBER_OF_DAYS_WITHOUT_WARNING` jours, envoie une alerte Discord.

### Notifications (`src/function.sh`)

`discord_notify <type> <titre> <contenu>` affiche le message puis le poste en *embed* sur `DISCORD_WEBHOOK_URL` avec `curl`. Couleurs : `success` vert, `danger` rouge, `warning` orange, sinon bleu. Le JSON est construit par un heredoc, sans échappement.

## Installation et planification (d'après le README)

```bash
sudo ln -s /opt/backup-scripts/bin/backup.sh /usr/bin/backup
sudo ln -s /opt/backup-scripts/bin/check-backup-time.sh /usr/bin/check-backup-time
sudo ln -s /opt/backup-scripts/bin/restore.sh /usr/bin/restore
```

`/etc/crontab` :
- machine de sauvegarde : `0 1 * * * root backup` ;
- serveur sauvegardé : `0 1 * * * root check-backup-time`.

Prérequis : clé SSH de la machine de sauvegarde autorisée pour root sur chaque serveur ; `rsync`, `tar`, `curl`, `ssh`, bash ≥ 4 (tableaux associatifs) et GNU `date` sur les deux côtés.

## Déploiement (`.github/workflows/main.yml`)

À chaque push sur `main`, GitHub Actions lance `appleboy/ssh-action@master` avec les secrets `HOST`, `USERNAME`, `PRIVATE_KEY`, `PORT`, et exécute `git -C /opt/backup-scripts/ pull origin main` sur cette machine. Il n'y a ni lint ni test. La machine visée par `HOST` n'est pas documentée (probablement le serveur sauvegardé, qui doit être joignable depuis Internet).

## Historique

Projet démarré le 28 janvier 2023, refactorisé dans la foulée (architecture `bin/ src/ utils/`), corrections en 2023-2024, dernier commit de code le 31 août 2024. Les commits suivent le format gitmoji en français (`:bug: Bug : …`).
