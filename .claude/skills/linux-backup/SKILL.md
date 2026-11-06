---
name: linux-backup
description: "Méthode et garde-fous pour concevoir, modifier, superviser ou restaurer la sauvegarde des serveurs Linux de ce dépôt (BorgBackup, borgmatic, restic, rsync, dumps de bases, rétention, healthchecks, restauration). À utiliser pour toute question « comment sauvegarder / restaurer », toute modification de configuration de backup, ou un incident de sauvegarde."
---

# Sauvegarde de serveurs Linux

Lire d'abord `docs/technique/nouvelle-solution.md` (cible et décisions) et `docs/technique/problemes-connus.md` (pièges de l'ancienne solution).

## Principes non négociables

1. **Une sauvegarde non restaurée n'existe pas.** Toute nouvelle configuration se termine par un test de restauration réel (fichier + dump de base) dans un dossier temporaire ou une VM.
2. **3-2-1** : 3 copies, 2 supports, 1 hors site. Le stockage principal est hors de chez soi.
3. **Push depuis le serveur**, chiffré côté serveur. Le stockage ne détient jamais la clé.
4. **Les bases se sauvegardent par dump** (hooks borgmatic `postgresql_databases`, `mariadb_databases`, `mysql_databases`, `sqlite_databases`, `mongodb_databases`), jamais par copie de leurs fichiers à chaud.
5. **Supervision externe** (Healthchecks ou équivalent) : l'absence de signal doit déclencher une alerte, pas seulement l'échec.
6. **Un échec ne doit jamais être annoncé comme un succès.** Le code retour de chaque étape est vérifié.
7. **Clé et phrase de passe** du dépôt exportées et stockées hors du serveur (`borg key export`). Le rappeler à chaque création de dépôt.

## Ne jamais faire sans accord explicite de l'utilisateur

- `borg delete`, `borg prune` sans `--dry-run` préalable, `borg compact` sur un dépôt dont on n'a pas vérifié l'état, `restic forget --prune`.
- Une restauration vers `/` ou vers un chemin de production ; `rsync --delete` vers un serveur.
- Changer le chiffrement, la phrase de passe ou la rétention d'un dépôt existant.
- Écrire un secret (phrase de passe, URL de webhook, clé) dans un fichier versionné.

Pour ces opérations : montrer la commande, l'effet attendu (simulation), puis attendre.

## Repères borgmatic

```bash
borgmatic config validate -c <fichier>     # valider la configuration
borgmatic --verbosity 1 --list --stats     # backup manuel
borgmatic list                             # archives
borgmatic check --force                    # contrôle d'intégrité immédiat
borgmatic extract --archive latest --path etc/hostname --destination /tmp/restore-test
borgmatic restore --archive latest         # restaurer les dumps de bases
borgmatic prune --dry-run --list           # voir ce que la rétention supprimerait (selon version)
```

Vérifier les options exactes dans la documentation de la version installée (`borgmatic --version`, https://torsion.org/borgmatic/) : les noms d'options ont changé entre 1.x et 2.x. Ne pas les deviner.

## Repères restic (si retenu)

```bash
restic snapshots ; restic check --read-data-subset=5% ; restic restore latest --target /tmp/restore-test --include /etc
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --dry-run
```

## Incident de sauvegarde : démarche

1. Lire le journal (`journalctl -u borgmatic.service -n 200`) et le dernier ping Healthchecks.
2. Distinguer : accès au stockage (SSH, réseau, quota), verrou (`borg break-lock` seulement si aucun borg ne tourne), dump de base, espace disque local, intégrité du dépôt.
3. Ne rien supprimer côté dépôt pour « débloquer ».
4. Après correction : backup manuel, puis `check`, puis vérifier que l'alerte se rétablit.
