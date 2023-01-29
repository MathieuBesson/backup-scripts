# Outil de sauvegarde de serveur

Ce projet à pour objectif de permettre de sauvegarder un ou plusieurs serveurs sur une machine dédié.

## Pré-requis

Avant de pouvoir utiliser les différents script (backup, restauration et vérification de la date de dernier backup) il est nécéssaire de configurer les serveurs à sauvegarder.

### Configurer un accès par clé SSH (root) sur les serveurs à sauvegarder

Ainsi, il est nécéssaire d'avoir un accès par clé SSH avec l'utilisateur root configuré sur la machine lançant les sauvegardes : [Explication](https://www.cyberciti.biz/faq/how-to-set-up-ssh-keys-on-linux-unix/)

### Établir la configuration de backup des serveurs à sauvegarder

Pour déterminer la configuration des serveurs à sauvegarder il est nécéssaire de dupliquer le fichier ./secrets/var.dev.sh et de le renommer en ./secrets/var.sh.

Il faut ensuite définir pour chaque serveur à sauvegarder les informations suivantes :

-   `NAME` : Nom du serveur
-   `IP` : Adresse ip du serveur
-   `BACKUP_USER` : Utilisateur à utiliser pour le backup (root conseillé pour ne pas perdre les propriétaires des dossier et fichiers)
-   `FOLDER_BACKUP_SOURCE` : Dossier à sauvegarder sur le serveur
-   `FOLDER_BACKUP_TARGET` : Dossier de destination des sauvegardes sur le serveur de backup (lançant la sauvegarde) pour le serveur courant
-   `FOLDER_BACKUP_GLOBAL` : Dossier de sauvegarde parent (permettant de grouper les sauvegardes)
-   `FOLDER_BACKUP_PARAMETERS` : Dossier de parametrage
-   `NUMBER_OF_DAYS_WITHOUT_WARNING` : Nombre de jours sans backup sans reçevoir des notifications

Il est ensuite nécéssaire de renseigner l'url d'un [webhook Discord](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks) permettant de notifier l'administrateur au cours d'un backup avec la variable `DISCORD_WEBHOOK_URL`

## Informations complémentaires

Il est possible de lancer les scripts plus simplement qu'en précisant le chemin d'accès du script. Il faut pour cela, créer des liens symboliques pour les scripts :

```bash
sudo ln -s {project-path}/bin/backup.sh /usr/bin/backup
sudo ln -s {project-path}/bin/check-backup-time.sh /usr/bin/check-backup-time
sudo ln -s {project-path}/bin/restore.sh /usr/bin/restore
```

## Utiliser les scrips

Les 3 scripts suivants sont maintenant utilisable :

```bash
# Sauvegarde d'un serveur
sudo backup
# OU
sudo backup pluton

# Restauration d'un serveur
sudo restore pluton pluton pluton-2023-01-29-22-34-28_1675028068_.tar.gz

# Vérifiaction de la date de dernière mise à jour du serveur
sudo check-backup-time
```

## Configuration des crons

Il peut être utile d'executer les scripts de manière automatique à intervale régulier. Les taches planifiés ou cron job répondent parfaitement à ce besoin

Vous pouvez les configurer sur le serveur de backup :

```conf
0 1 * * * root backup
```

Et sur le serveur à sauvegarder :

```conf
0 1 * * * root check-backup-time
```

L'outil [Crontab Guru](https://crontab.guru/) peux permettre de configurer vos crons plus facilement.
