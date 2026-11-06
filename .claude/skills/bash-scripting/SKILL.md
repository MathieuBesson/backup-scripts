---
name: bash-scripting
description: "Règles d'écriture et de relecture des scripts bash et shell de ce dépôt (scripts d'installation, de restauration, de maintenance système). À utiliser avant d'écrire, modifier ou relire un fichier .sh, une unité systemd ou une ligne cron, et pour corriger un avertissement shellcheck. Pas pour la configuration borgmatic YAML (voir linux-backup)."
---

# Scripts bash : règles du projet

Les scripts de ce dépôt tournent **en root sur des serveurs de production** et touchent aux sauvegardes. Une erreur silencieuse coûte des données. Priorité : échouer bruyamment plutôt que continuer.

## En-tête obligatoire

```bash
#!/usr/bin/env bash
# <Ce que fait le script, en une ligne, en français>
set -Eeuo pipefail
IFS=$'\n\t'
```

- `-e` : arrêt à la première erreur ; `-u` : variable non définie = erreur ; `pipefail` : l'échec d'un maillon de pipe compte ; `-E` : le `trap ERR` est hérité par les fonctions.
- Exceptions à `-e` explicites et commentées : `commande || true`, ou `if ! commande; then …`.

## Règles

1. **Toujours guillemeter** les expansions : `"$var"`, `"${tab[@]}"`, `"$(commande)"`. Seule exception : `[[ … ]]` à gauche, et un motif de glob voulu à droite de `==` (à commenter).
2. **Comparaisons numériques** avec `(( a > b ))` ou `-gt`, jamais `>` / `<` dans `[[ ]]` (comparaison de chaînes).
3. **`rm -rf` protégé** : `rm -rf -- "${dir:?}"` ; jamais sur une variable qui peut être vide ou `/`.
4. **Dossiers temporaires** avec `mktemp -d` + `trap 'rm -rf -- "$tmp"' EXIT`, jamais un chemin fixe partagé.
5. **Pas d'`eval`** sur des données ; pas de JSON construit à la main (utiliser `jq -n --arg`).
6. **Fonctions** : `local` pour toutes les variables, une responsabilité, un commentaire d'en-tête en français (rôle, paramètres, code retour).
7. **Arguments** : vérifier le nombre et afficher un `usage` sur stderr ; codes de sortie non nuls en cas d'erreur (`exit 1`, jamais un `exit` nu après une erreur).
8. **Messages** : erreurs sur stderr (`echo "…" >&2`), en français ; préfixe horodaté si le script tourne sous cron ou systemd.
9. **Idempotence** : un script d'installation peut être relancé sans dégât (`install -m`, `mkdir -p`, tests d'existence).
10. **Commandes destructrices** (restauration, suppression, `--delete`) : mode simulation par défaut (`--dry-run`) ou confirmation explicite, et jamais sans avoir vérifié la cible.
11. **SSH** : `ssh -o BatchMode=yes` dans les scripts ; ne pas interpoler de variables locales non contrôlées dans la commande distante.
12. **Planification** : préférer un timer systemd à cron (journal dans `journalctl`, `Persistent=true` rattrape un passage manqué, `OnFailure=` possible).

## Vérification

```bash
make lint         # shellcheck sur tous les scripts du dépôt
bash -n script.sh # syntaxe seule
```

- Zéro avertissement shellcheck dans le code neuf. Une désactivation (`# shellcheck disable=SCxxxx`) est locale et justifiée sur la même ligne.
- Tester un script destructeur dans un dossier temporaire ou un conteneur jetable (`docker run --rm -it debian:stable`), jamais sur un vrai serveur en premier.
- Pour du code testable, isoler la logique dans des fonctions et la tester avec [bats-core](https://github.com/bats-core/bats-core) si le dépôt en dispose.

## Relecture : points à chercher en premier

- Une commande critique (`rsync`, `borg`, `tar`, `ssh`, dump de base) dont l'échec n'arrête rien et est suivi d'un message de succès.
- Une variable vide qui transforme un chemin en `/` ou en dossier courant.
- Un `cd` sans `|| exit`.
- Un secret passé en argument de commande (visible dans `ps`) au lieu d'un fichier ou d'une variable d'environnement.
