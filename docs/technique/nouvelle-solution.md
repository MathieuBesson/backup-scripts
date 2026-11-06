# Proposition : remplacer les scripts par une sauvegarde « push » chiffrée et dédupliquée

**Statut : proposition, rien n'est encore implémenté.** Les choix à valider sont listés à la fin.

## Ce qu'on veut

| Besoin | Aujourd'hui | Cible |
|---|---|---|
| Ne pas dépendre du PC | Le PC doit être allumé à 1 h | Le serveur se sauvegarde **lui-même**, PC éteint |
| Bande passante | Tout le disque transite à chaque fois, vers le PC | Seuls les blocs modifiés partent, du serveur vers un stockage distant ; le PC ne fait rien |
| Place disque | ~1 archive complète par jour | Déduplication : un backup quotidien coûte la taille de ce qui a changé |
| Sécurité | Archives en clair, root SSH du PC vers les serveurs | Chiffrement côté serveur ; le stockage ne voit que des données chiffrées ; plus d'accès root entrant |
| Cohérence des bases | Copie à chaud des fichiers | Dump des bases avant chaque backup |
| Alerte fiable | Le serveur s'alerte lui-même (muet s'il est en panne) | Alerte « dead man's switch » externe : on est prévenu si **aucun** backup n'arrive |
| Restauration | Écrasement à chaud du `/` | Restauration d'un fichier, d'un dossier ou de tout, avec simulation, sur la machine de son choix |
| Vérification | Aucune | Contrôle d'intégrité automatique + test de restauration régulier |

## Principe

```
 Serveur (ichigo)                                         Stockage distant (hors de chez soi)
 ────────────────                                         ──────────────────────────────────
 timer systemd (chaque nuit)                              ex. Hetzner Storage Box (borg natif)
   └─ borgmatic                                           dépôt Borg chiffré, dédupliqué
        1. dump PostgreSQL / MySQL / SQLite ─┐
        2. borg create (fichiers + dumps) ───┴── SSH ───▶ seuls les blocs nouveaux sont envoyés
        3. borg prune (rétention)
        4. borg check (intégrité, partiel)
        5. ping début / succès / échec ─────────────────▶ healthchecks.io ── alerte si rien reçu
                                                          └─ notification Discord

 PC : rien à faire. Sert seulement à restaurer, ou à garder une copie supplémentaire s'il le souhaite.
```

C'est le serveur qui **pousse** ses données ; il n'a besoin que d'un accès sortant vers le stockage. Le stockage ne détient jamais la clé de chiffrement.

## Outil recommandé : BorgBackup + borgmatic

[BorgBackup](https://www.borgbackup.org/) fait la déduplication, la compression et le chiffrement. [borgmatic](https://torsion.org/borgmatic/) l'enveloppe avec un fichier YAML par serveur et apporte, sans code à écrire :
- les sources, exclusions et rétention (`keep_daily`, `keep_weekly`, `keep_monthly`…) ;
- les **dumps de bases** PostgreSQL, MySQL/MariaDB, SQLite, MongoDB, streamés dans l'archive puis restaurables par `borgmatic restore` ;
- les contrôles d'intégrité planifiés (`checks`, avec fréquence) ;
- la supervision : hook [Healthchecks](https://healthchecks.io/) natif, et hook Apprise (présent depuis borgmatic 1.8.4) qui sait poster sur Discord ;
- des unités systemd (service + timer) fournies par le projet.

Résultat : les ~250 lignes de bash actuelles sont remplacées par un fichier de configuration d'environ 40 lignes par serveur, avec un outil maintenu et largement utilisé.

### Alternatives sérieuses

| Outil | Pour | Contre | Quand le préférer |
|---|---|---|---|
| **Borg + borgmatic** (recommandé) | Configuration YAML complète, dumps de bases intégrés, supervision intégrée, Storage Box compatible nativement | Le serveur distant doit parler Borg (ou SSH + borg installé) | Cas général, un ou quelques serveurs Linux |
| **restic** (+ [resticprofile](https://creativeprojects.github.io/resticprofile/) ou [Backrest](https://github.com/garethgeorge/backrest)) | Binaire unique, nombreux stockages (S3, Backblaze B2, SFTP, rest-server), version 0.19 en 2026 | Dumps de bases et notifications à scripter soi-même (ou via resticprofile) | Si on veut un stockage objet type S3/B2 |
| **Kopia** | Interface graphique, S3/B2/SFTP, politiques fines | Moins répandu en serveur sans interface | Si une UI compte |
| Snapshots de l'hébergeur (VPS) | Restauration complète en un clic | Lié au fournisseur, souvent payant, pas de restauration fine, même datacenter | En **complément**, pas à la place |
| rsnapshot / rsync + liens physiques | Proche de l'existant | Pas de chiffrement ni de vraie déduplication ; reste un modèle pull | À éviter |

### Où stocker

| Stockage | Prix indicatif | Remarque |
|---|---|---|
| **Hetzner Storage Box BX11** (1 To) | ≈ 3,20 € HT/mois, sans engagement (à revérifier sur la page Hetzner) | Borg et restic supportés (SSH/SFTP), snapshots côté Storage Box, en Allemagne/Finlande |
| Backblaze B2 / autre S3 | Au Go stocké | Pour restic ou Kopia ; prévoir les frais de téléchargement à la restauration |
| Un 2ᵉ serveur / NAS à soi | Matériel | Possible comme 2ᵉ dépôt, mais on retrouve la dépendance « machine allumée » |

Règle 3-2-1 visée : les données sur le serveur, une copie chiffrée sur la Storage Box, et une troisième copie au choix (snapshots de l'hébergeur, ou 2ᵉ dépôt borgmatic, ou copie occasionnelle du dépôt sur le PC).

## Ce qu'on sauvegarde

Plutôt que tout `/`, on sauvegarde **ce qui ne se réinstalle pas** :
- `/etc`, `/root`, `/home`, `/opt`, `/srv`, `/var/www`, `/usr/local` ;
- les données des applications (`/var/lib/<appli>`, volumes Docker) ;
- les **dumps** des bases (pas les fichiers bruts des bases) ;
- la liste des paquets installés (`dpkg --get-selections`), générée avant chaque backup.

On exclut caches, journaux volumineux, `/var/lib/docker/overlay2`, swap, `node_modules`, etc.

En cas de perte du serveur : réinstallation d'un système propre, puis restauration de la configuration et des données. C'est plus fiable que d'écraser un `/` complet, et plus rapide si la configuration du serveur est un jour décrite par Ansible.

## Sécurité

- La **phrase de passe Borg** (mode `repokey-blake2`) et une **export de la clé** (`borg key export`) sont gardées hors du serveur : gestionnaire de mots de passe + copie papier. Sans elles, les sauvegardes sont illisibles.
- Clé SSH dédiée au backup sur le serveur, autorisée uniquement sur la Storage Box. Plus aucun accès root entrant venant du PC.
- Protection contre un serveur compromis qui effacerait ses sauvegardes : snapshots de la Storage Box, ou dépôt en mode *append-only* si le stockage le permet (à vérifier pour la Storage Box).
- Fichier de configuration lisible par root seulement (`chmod 600`), secrets dans un fichier séparé chargé par borgmatic.

## Supervision

- **Healthchecks.io** (gratuit jusqu'à 20 contrôles) : borgmatic envoie « début », « succès » ou « échec ». Si aucun signal n'arrive dans le délai prévu (serveur éteint, timer cassé…), Healthchecks alerte par e-mail ou Discord. Cela corrige le défaut B6 de la solution actuelle.
- **Discord** : notification d'échec (et éventuellement de succès) via Apprise, en gardant le webhook actuel.
- Contrôle d'intégrité `borg check` hebdomadaire (dépôt) et mensuel avec relecture des données (`--verify-data` sur un échantillon).
- **Test de restauration** tous les trimestres : restaurer un dossier et un dump dans un dossier temporaire, vérifier, documenter.

## Ce que devient ce dépôt

Le dépôt ne contient plus de logique de backup, mais :

```
borgmatic/
  ichigo.yaml            # configuration borgmatic du serveur (sans secret)
  common.yaml            # options partagées (rétention, checks, supervision)
systemd/                 # éventuels ajustements du timer
scripts/
  install.sh             # installe borg/borgmatic, la config, le timer, la clé SSH (idempotent)
  restore-test.sh        # test de restauration guidé
docs/
  exploitation.md        # installer un serveur, restaurer, changer de stockage, en cas de sinistre
```

Avec une CI légère : `shellcheck` sur les scripts et `borgmatic config validate` sur les YAML. Le déploiement par `git pull` via SSH disparaît : la configuration est installée par `scripts/install.sh` (ou un playbook Ansible, comme sur templify).

Les anciens scripts restent consultables dans l'historique git.

## Migration proposée

1. **Décider** : outil, stockage, liste des serveurs et des données (questions ci-dessous).
2. Créer la Storage Box, la clé SSH du serveur, initialiser le dépôt (`borg init --encryption=repokey-blake2`), exporter la clé.
3. Écrire la configuration borgmatic d'`ichigo`, la valider, lancer un premier backup à la main.
4. Activer le timer systemd et Healthchecks ; vérifier l'alerte en coupant volontairement un backup.
5. Faire un **test de restauration** complet dans une VM ou un dossier temporaire.
6. Laisser l'ancien système et le nouveau tourner en parallèle deux semaines.
7. Retirer les crons, les scripts bash, l'accès root SSH du PC et le workflow de déploiement ; garder une dernière archive `.tar.gz` le temps de la transition.

## Questions à trancher

1. Combien de serveurs, et chez quel hébergeur ? (Cela décide si les snapshots de l'hébergeur servent de 3ᵉ copie.)
2. Volume de données à sauvegarder (ordre de grandeur) ?
3. Qu'est-ce qui tourne sur `ichigo` : Docker, quelles bases de données ?
4. Budget accepté pour un stockage externe (≈ 3 à 5 €/mois) ?
5. Le PC doit-il garder une copie locale, ou peut-il sortir complètement du dispositif ?
6. Borg + borgmatic (recommandé) ou restic ?

Sources : [borgmatic](https://torsion.org/borgmatic/) et ses [notes de version 2.1.6](https://projects.torsion.org/borgmatic-collective/borgmatic/releases/tag/2.1.6), [BorgBackup](https://www.borgbackup.org/), [restic](https://restic.net/), [Hetzner Storage Box](https://www.hetzner.com/storage-box), [Healthchecks.io](https://healthchecks.io/).
