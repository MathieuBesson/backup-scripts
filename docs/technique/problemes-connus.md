# Problèmes connus de la solution actuelle

Constats tirés de la lecture du code et de `shellcheck 0.11` (1 erreur, 11 avertissements, une cinquantaine de notes, surtout des variables non guillemetées). Classés par gravité.

## 1. Conception

| # | Problème | Conséquence |
|---|---|---|
| C1 | **Modèle « pull » depuis le PC** | La sauvegarde n'a lieu que si le PC est allumé à 1 h du matin, et elle consomme sa bande passante et son disque. |
| C2 | **Copie complète à chaque fois** : `backup-tmp/` est supprimé après compression, donc `rsync` repart de zéro | Tout le disque du serveur traverse le réseau à chaque backup ; l'avantage incrémental de rsync est perdu. |
| C3 | **Archives complètes `.tar.gz`, sans déduplication** | Chaque archive pèse la taille du serveur. 9 mois de backups quotidiens = ~270 copies complètes. |
| C4 | **Aucun chiffrement** | Les archives contiennent `/etc/shadow`, clés SSH, certificats, `.env`, bases de données, en clair sur le PC. |
| C5 | **Une seule copie, chez soi** | Pas de règle 3-2-1 : un vol, un incendie ou une panne du disque du PC fait tout perdre. |
| C6 | **Copie « à chaud » des fichiers** | Les bases de données (PostgreSQL, MySQL, SQLite…) copiées pendant qu'elles écrivent peuvent être incohérentes, donc impossibles à restaurer. |
| C7 | **Accès SSH root du PC vers les serveurs** | Une compromission du PC donne le root sur tous les serveurs. |
| C8 | **Restauration = écrasement à chaud du serveur avec `rsync --delete`** | Méthode risquée : système en marche écrasé, fichiers récents supprimés, aucune restauration partielle (un fichier, un dossier), aucune simulation. |
| C9 | **Aucune vérification d'intégrité ni test de restauration** | On ne sait pas si les archives sont lisibles avant d'en avoir besoin. |

## 2. Bugs

| # | Où | Problème | Conséquence |
|---|---|---|---|
| B1 | `bin/backup.sh` | Aucun contrôle d'erreur (`rsync`, `tar`, `ssh`) ni `set -e` | Un rsync en échec produit une archive vide ou partielle, **puis le timestamp est quand même écrit et Discord annonce un succès** : `check-backup-time` est trompé. |
| B2 | `bin/backup.sh:132-135` | `[[ $number_of_backups > 0 ]]` compare des chaînes (shellcheck SC2071) | Fonctionne par hasard ; le commentaire « si on a + de 3 fichiers » ne correspond à aucun code : aucun nombre minimal d'archives n'est conservé. |
| B3 | `bin/backup.sh:139` | L'epoch est extrait par `cut -d"_" -f2` sur le **chemin complet** | Si `FOLDER_BACKUP_TARGET` contient un `_`, mauvais champ : archives supprimées à tort ou jamais. |
| B4 | `bin/backup.sh:28` vs `src/function.sh:90` | La vérification de l'argument compare `SERVER[NAME]`, la sélection compare la clé de `SERVERS` | Si la clé diffère du nom, `backup <nom>` passe la vérification mais ne sauvegarde rien, et annonce un succès. |
| B5 | `bin/check-backup-time.sh:14-17` | Fichier `timestamp-last-backup` absent → valeur vide ; comparaison de chaînes `<` | Serveur jamais sauvegardé : pas d'alerte fiable. |
| B6 | `bin/check-backup-time.sh` | L'alerte part du serveur lui-même | Si le serveur est éteint ou planté, aucune alerte, alors que c'est le cas le plus grave. |
| B7 | `src/function.sh:43-51` | JSON construit sans échappement | Un `"` ou un retour à la ligne dans un message casse la notification (échec silencieux). |
| B8 | `bin/restore.sh` / README | Le README donne 3 arguments, le script en lit 2 | La commande documentée restaure avec le mauvais fichier ou échoue. |
| B9 | `bin/restore.sh:95` | `backup-tmp/` partagé entre backup et restauration | Une restauration pendant un backup mélange les deux, puis l'un efface le dossier de l'autre. |
| B10 | `bin/backup.sh:87` | Les exclusions ne couvrent ni `/var/cache`, ni `/swapfile`, ni les volumes de conteneurs en cours d'écriture | Archives plus grosses que nécessaire, fichiers potentiellement incohérents. |
| B11 | tous | Variables non guillemetées (SC2086, SC2046) | Chemins avec espaces cassés ; `rm -rf $dossier` dangereux si la variable est vide. |
| B12 | `secrets/var.dev.sh` | `FOLDER_BACKUP_GLOBAL` défini, jamais utilisé | Configuration trompeuse. |

## 3. Sécurité et exploitation

| # | Problème |
|---|---|
| S1 | `.github/workflows/main.yml` utilise `appleboy/ssh-action@master` (non épinglé) avec une clé privée : une compromission de l'action donne un accès SSH à la machine. |
| S2 | Le « déploiement » fait un `git pull` sur une machine accessible depuis Internet, sans contrôle préalable (lint, tests). |
| S3 | `secrets/var.sh` contient le webhook Discord et doit être copié à la main sur chaque machine. |
| S4 | Aucune journalisation hors de la sortie cron (souvent perdue) : pas d'historique des durées ni des tailles. |
| S5 | Aucun test automatisé ; aucun lint en CI. |

## Conclusion

Les bugs B1 à B12 sont corrigibles, mais les problèmes de conception C1 à C9 tiennent au principe même (pull depuis un PC + tar complet). Corriger le code bash ne réglerait ni la dépendance au PC, ni la bande passante, ni l'absence de chiffrement et de déduplication. D'où la proposition de remplacement : [nouvelle-solution.md](nouvelle-solution.md).
