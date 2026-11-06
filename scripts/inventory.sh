#!/usr/bin/env bash
# Inventaire de ce qu'il faudrait sauvegarder sur ce serveur, et du volume que cela représente.
#
# LECTURE SEULE : ne modifie, n'arrête et ne supprime rien. Les seules commandes lancées dans les
# conteneurs sont des requêtes SQL de lecture (taille des bases PostgreSQL), désactivables avec --no-db.
#
# Usage : sudo ./scripts/inventory.sh [--no-db] | tee inventaire.txt
set -Eeuo pipefail
IFS=$'\n\t'

readonly SEARCH_ROOTS=(/opt /srv /var/www /home /root)
readonly SYSTEM_PATHS=(/etc /root /home /opt /srv /var/www /usr/local /var/spool/cron)
# Motifs exclus de tout le calcul : caches d'outils, recréés automatiquement à l'usage.
# Les dépendances installées (node_modules, vendor, .venv…) et les .env sont GARDÉS :
# la restauration doit remettre les applications en marche sans réinstallation.
readonly EXCLUDE_PATTERNS=(.npm __pycache__ .mypy_cache .pytest_cache .ruff_cache)
readonly DEPENDENCY_PATTERNS=(node_modules vendor .venv venv)
readonly DB_TIMEOUT=20

declare -a INCLUDES=()
declare -a EXCLUDES=()
declare -A INCLUDE_REASON=()
declare -A EXCLUDE_REASON=()
declare -a NOTES=()
DB_DUMP_BYTES=0
QUERY_DB=1

#---
## Affiche l'aide
#---
usage() {
  cat <<'EOF'
Usage : sudo ./scripts/inventory.sh [--no-db] [--help]

Liste ce qu'il faudrait sauvegarder sur ce serveur (configuration, Apache, Docker, bases, dépôts git)
et estime le volume. Lecture seule.

  --no-db   ne pas interroger les bases PostgreSQL (taille estimée par leur dossier de données)
  --help    affiche cette aide
EOF
}

#---
## Affiche un titre de section
## PARAMETERS : $1 : titre
#---
section() {
  printf '\n━━━ %s ━━━\n' "$1"
}

#---
## Convertit un nombre d'octets en taille lisible (Kio, Mio, Gio)
## PARAMETERS : $1 : octets
#---
human() {
  numfmt --to=iec-i --suffix=o --format='%.1f' "${1:-0}"
}

#---
## Taille d'un chemin en octets (0 s'il n'existe pas), sans les motifs exclus
## PARAMETERS : $1 : chemin
#---
size_of() {
  local path="$1"
  local args=()
  local pattern
  [[ -e "$path" ]] || { echo 0; return; }
  for pattern in "${EXCLUDE_PATTERNS[@]}"; do args+=("--exclude=$pattern"); done
  local out
  out=$(du -sb "${args[@]}" -- "$path" 2>/dev/null || true)
  out="${out%%$'\t'*}"
  echo "${out:-0}"
}

#---
## Ajoute un chemin à la liste des éléments à sauvegarder (sans doublon)
## PARAMETERS : $1 : chemin, $2 : raison
#---
add_include() {
  local path="$1" reason="$2"
  [[ -e "$path" ]] || return 0
  if [[ -z "${INCLUDE_REASON[$path]+x}" ]]; then
    INCLUDES+=("$path")
    INCLUDE_REASON[$path]="$reason"
  fi
}

#---
## Ajoute un chemin à exclure de la sauvegarde de fichiers (ex. données brutes d'une base, remplacées par un dump)
## PARAMETERS : $1 : chemin, $2 : raison
#---
add_exclude() {
  local path="$1" reason="$2"
  [[ -e "$path" ]] || return 0
  if [[ -z "${EXCLUDE_REASON[$path]+x}" ]]; then
    EXCLUDES+=("$path")
    EXCLUDE_REASON[$path]="$reason"
  fi
}

#---
## Affiche une ligne « taille  chemin  commentaire »
## PARAMETERS : $1 : chemin, $2 : commentaire
#---
print_size_line() {
  printf '  %10s  %-50s %s\n' "$(human "$(size_of "$1")")" "$1" "${2:-}"
}

#---
## Joint des mots avec des espaces (IFS vaut retour à la ligne + tabulation dans ce script)
## PARAMETERS : $@ : mots
#---
join_words() {
  local IFS=' '
  echo "$*"
}

#---
## Masque d'éventuels identifiants dans une URL git (https://user:token@host → https://***@host)
## PARAMETERS : $1 : URL
#---
mask_url() {
  sed -E 's#(://)[^/@]+@#\1***@#' <<< "$1"
}

#---
## Informations générales sur la machine et ses disques
#---
inspect_system() {
  section "Machine"
  echo "  Nom        : $(hostname)"
  echo "  Système    : $(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-inconnu}")"
  echo "  Date       : $(date '+%Y-%m-%d %H:%M')"
  echo
  df -h --output=target,size,used,avail,pcent -x tmpfs -x devtmpfs -x overlay -x squashfs 2>/dev/null | sed 's/^/  /' || true

  section "Configuration et données système"
  local path
  for path in "${SYSTEM_PATHS[@]}"; do
    if [[ -e "$path" ]]; then
      add_include "$path" "système"
      print_size_line "$path"
    fi
  done
  if [[ -d /etc/letsencrypt ]]; then
    print_size_line /etc/letsencrypt "certificats (inclus dans /etc)"
  fi
  if command -v dpkg >/dev/null; then
    echo "  Paquets installés : $(dpkg --get-selections | wc -l) (liste à générer avant chaque backup : dpkg --get-selections)"
  fi
}

#---
## Détail des plus gros sous-dossiers, pour repérer ce qui se réinstalle (logiciels, outils) et peut être exclu
#---
inspect_largest_subdirs() {
  section "Détail des plus gros sous-dossiers (à trier : logiciel réinstallable ou donnée ?)"
  local args=()
  local pattern path
  for pattern in "${EXCLUDE_PATTERNS[@]}"; do args+=("--exclude=$pattern"); done
  for path in /opt /srv /home /root /usr/local /var/www; do
    [[ -d "$path" ]] || continue
    echo "  $path"
    du -xb -d1 "${args[@]}" -- "$path" 2>/dev/null | sort -rn | awk -v top="$path" '$2 != top' | head -8 \
      | while IFS=$'\t' read -r bytes sub; do
          printf '    %10s  %s\n' "$(human "$bytes")" "$sub"
        done || true
  done
}

#---
## Configuration Apache et dossiers des sites
#---
inspect_apache() {
  local conf_dir=""
  [[ -d /etc/apache2 ]] && conf_dir=/etc/apache2
  [[ -z "$conf_dir" && -d /etc/httpd ]] && conf_dir=/etc/httpd
  [[ -n "$conf_dir" ]] || return 0

  section "Apache"
  print_size_line "$conf_dir" "configuration (incluse dans /etc)"

  local sites_dir="$conf_dir/sites-enabled"
  [[ -d "$sites_dir" ]] || sites_dir="$conf_dir/conf.d"
  echo "  Sites actifs : $(find "$sites_dir" -maxdepth 1 \( -type f -o -type l \) -printf '%f ' 2>/dev/null)"

  local root
  while IFS= read -r root; do
    [[ -n "$root" ]] || continue
    add_include "$root" "DocumentRoot Apache"
    print_size_line "$root" "DocumentRoot"
  done < <(grep -rhoiE '^\s*DocumentRoot\s+\S+' "$sites_dir"/ 2>/dev/null \
           | awk '{print $2}' | tr -d '"' | sort -u || true)
}

#---
## Taille des bases d'un conteneur PostgreSQL (requête de lecture seule)
## PARAMETERS : $1 : id du conteneur, $2 : nom du conteneur
#---
inspect_postgres_container() {
  local id="$1" name="$2"
  local pg_user
  pg_user=$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$id" \
            | sed -n 's/^POSTGRES_USER=//p' | head -1)
  pg_user="${pg_user:-postgres}"

  local rows
  if ! rows=$(timeout "$DB_TIMEOUT" docker exec "$id" psql -U "$pg_user" -d postgres -Atc \
      "SELECT datname, pg_database_size(datname) FROM pg_database WHERE NOT datistemplate ORDER BY 2 DESC" 2>/dev/null); then
    echo "      ⚠ bases non interrogeables (utilisateur « $pg_user » ?) : taille estimée par le dossier de données"
    return 1
  fi

  local db bytes
  while IFS='|' read -r db bytes; do
    [[ -n "$db" ]] || continue
    printf '      base %-28s %10s\n' "$db" "$(human "$bytes")"
    DB_DUMP_BYTES=$(( DB_DUMP_BYTES + bytes ))
  done <<< "$rows"
  NOTES+=("PostgreSQL ($name) : dump à faire avant chaque backup, ex. docker exec $name pg_dumpall -U $pg_user (sans gzip, restic compresse)")
}

#---
## Indique si un point de montage contient les fichiers bruts d'une base de données
## PARAMETERS : $1 : destination dans le conteneur, $2 : image
#---
is_database_data_mount() {
  local destination="$1" image="$2"
  case "$destination" in
    /var/lib/postgresql*|/var/lib/mysql*|/var/opt/mssql*|/data/db|/bitnami/postgresql*) return 0 ;;
  esac
  [[ "$image" == *mssql* && "$destination" == */data* ]]
}

#---
## Conteneurs Docker : projets compose, montages, bases de données, Bitwarden
#---
inspect_docker() {
  command -v docker >/dev/null || return 0
  section "Docker"

  local ids
  ids=$(docker ps -aq 2>/dev/null || true)
  if [[ -z "$ids" ]]; then
    echo "  Aucun conteneur."
    return 0
  fi

  local id name image status project workdir
  local type source destination
  for id in $ids; do
    IFS=$'\t' read -r name image status project workdir < <(docker inspect -f \
      '{{slice .Name 1}}{{"\t"}}{{.Config.Image}}{{"\t"}}{{.State.Status}}{{"\t"}}{{index .Config.Labels "com.docker.compose.project"}}{{"\t"}}{{index .Config.Labels "com.docker.compose.project.working_dir"}}' "$id")
    echo
    echo "  ● $name  ($image, $status${project:+, projet compose « $project »})"

    if [[ -n "$workdir" && -d "$workdir" && -z "${INCLUDE_REASON[$workdir]+x}" ]]; then
      add_include "$workdir" "dossier compose ($project)"
      print_size_line "$workdir" "dossier compose (docker-compose.yml, .env)"
    fi

    local is_postgres=0
    [[ "$image" == *postgres* || "$image" == *postgis* || "$image" == *timescale* ]] && is_postgres=1
    local db_queried=0
    if (( is_postgres && QUERY_DB )) && [[ "$status" == running ]]; then
      inspect_postgres_container "$id" "$name" && db_queried=1
    fi

    case "$image" in
      *vaultwarden*)
        NOTES+=("Vaultwarden ($name) : base SQLite, copie cohérente avec sqlite3 db.sqlite3 \".backup …\" ou arrêt bref ; garder aussi rsa_key*, attachments/, config.json") ;;
      *bitwarden/*|*bitwarden-*)
        NOTES+=("Bitwarden officiel ($name) : sauvegarder bwdata/ (hors bwdata/mssql/data) ; la base MSSQL a ses sauvegardes nocturnes dans bwdata/mssql/backups") ;;
    esac

    while IFS=$'\t' read -r type source destination; do
      [[ -n "$type" ]] || continue
      if [[ "$type" != volume && "$type" != bind ]]; then continue; fi
      if [[ "$source" == /var/run/docker.sock || "$source" == /etc/localtime || "$source" == /etc/timezone ]]; then continue; fi
      if is_database_data_mount "$destination" "$image"; then
        if (( db_queried )); then
          add_exclude "$source" "données brutes de base ($name), remplacées par un dump"
          print_size_line "$source" "→ $destination  [EXCLU : dump à la place]"
        else
          add_include "$source" "données de base ($name), à remplacer par un dump"
          print_size_line "$source" "→ $destination  [base : prévoir un dump]"
        fi
      else
        add_include "$source" "montage $type de $name"
        print_size_line "$source" "→ $destination  ($type)"
      fi
    done < <(docker inspect -f '{{range .Mounts}}{{.Type}}{{"\t"}}{{.Source}}{{"\t"}}{{.Destination}}{{"\n"}}{{end}}' "$id")
  done

  section "Docker : ce qui n'a pas besoin d'être sauvegardé"
  docker system df 2>/dev/null | sed 's/^/  /' || true
  echo "  Images, conteneurs et cache se recréent depuis les docker-compose.yml : exclus."
}

#---
## PostgreSQL installé directement sur la machine (hors Docker)
#---
inspect_postgres_host() {
  command -v psql >/dev/null || return 0
  systemctl is-active --quiet postgresql 2>/dev/null || return 0
  section "PostgreSQL (hors Docker)"

  add_exclude /var/lib/postgresql "données brutes PostgreSQL, remplacées par un dump"
  print_size_line /var/lib/postgresql "[EXCLU : dump à la place]"
  (( QUERY_DB )) || return 0

  local rows db bytes
  if rows=$(timeout "$DB_TIMEOUT" runuser -u postgres -- psql -Atc \
      "SELECT datname, pg_database_size(datname) FROM pg_database WHERE NOT datistemplate ORDER BY 2 DESC" 2>/dev/null); then
    while IFS='|' read -r db bytes; do
      [[ -n "$db" ]] || continue
      printf '      base %-28s %10s\n' "$db" "$(human "$bytes")"
      DB_DUMP_BYTES=$(( DB_DUMP_BYTES + bytes ))
    done <<< "$rows"
  fi
  NOTES+=("PostgreSQL hôte : dump avant chaque backup avec runuser -u postgres -- pg_dumpall")
}

#---
## Dépôts git : dépôts trouvés, fichiers non versionnés (gardés : .env, data/, dépendances) et modifications non commitées
#---
inspect_git_repos() {
  section "Dépôts git (gardés en entier pour une restauration automatique)"
  local gitdir repo remote untracked_bytes dirty env_files
  local found=0
  while IFS= read -r -d '' gitdir; do
    found=1
    repo=$(dirname "$gitdir")
    remote=$(git -c safe.directory='*' -C "$repo" remote get-url origin 2>/dev/null || echo "aucun remote")
    dirty=$(git -c safe.directory='*' -C "$repo" status --porcelain 2>/dev/null | grep -vc '^??' || true)
    untracked_bytes=$(git -c safe.directory='*' -C "$repo" ls-files -z --others 2>/dev/null \
      | (cd "$repo" && du -cb --files0-from=- 2>/dev/null) | tail -1 | cut -f1 || true)
    env_files=$(find "$repo" -maxdepth 3 -name '.env*' -type f -not -path '*/node_modules/*' -printf '%P ' 2>/dev/null || true)
    echo "  ● $repo"
    echo "      remote : $(mask_url "$remote")"
    echo "      fichiers non versionnés (inclus : .env, data/, dépendances…) : $(human "${untracked_bytes:-0}")"
    [[ -n "$env_files" ]] && echo "      fichiers d'environnement (inclus) : $env_files"
    if (( dirty > 0 )); then
      echo "      ⚠ $dirty fichier(s) modifié(s) non commité(s) : à pousser, ou à sauvegarder"
    fi
  done < <(find "${SEARCH_ROOTS[@]}" -maxdepth 5 -name .git -type d -prune -print0 2>/dev/null || true)
  (( found )) || echo "  Aucun dépôt trouvé."
}

#---
## Taille cumulée des dossiers dont le nom correspond à l'un des motifs, sous SEARCH_ROOTS
## PARAMETERS : $@ : noms de dossiers (ex. node_modules vendor)
#---
dirs_size() {
  local find_args=()
  local name
  for name in "$@"; do find_args+=(-name "$name" -o); done
  unset 'find_args[-1]'
  local out
  out=$(find "${SEARCH_ROOTS[@]}" -type d \( "${find_args[@]}" \) -prune -print0 2>/dev/null \
        | du -cb --files0-from=- 2>/dev/null | tail -1 | cut -f1 || true)
  echo "${out:-0}"
}

#---
## Ce qui est exclu (se recrée seul) et ce qui est gardé pour une restauration automatique
#---
inspect_heavy_excluded() {
  local roots
  roots=$(join_words "${SEARCH_ROOTS[@]}")

  section "Gardé pour une restauration sans réinstallation"
  printf '  %10s  %s\n' "$(human "$(dirs_size "${DEPENDENCY_PATTERNS[@]}")")" \
    "dépendances installées ($(join_words "${DEPENDENCY_PATTERNS[@]}")) dans $roots"
  echo "  Déjà comptées dans le total. Restic les déduplique : elles ne pèsent qu'au premier backup et quand elles changent."

  section "Exclu (se recrée seul, ou retéléchargé à la restauration)"
  local path
  for path in /var/lib/docker /var/log /var/cache /swapfile /swap.img; do
    [[ -e "$path" ]] && print_size_line "$path"
  done
  printf '  %10s  %s\n' "$(human "$(dirs_size "${EXCLUDE_PATTERNS[@]}")")" "caches d'outils ($(join_words "${EXCLUDE_PATTERNS[@]}"))"
  echo "  /var/lib/docker : images et conteneurs, retéléchargés par docker compose pull (les volumes de données, eux, sont inclus)."
  NOTES+=("Images Docker : pour une restauration automatique, chaque image doit rester téléchargeable (versions épinglées, pas « latest ») ; une image construite localement doit être poussée sur un registre ou reconstructible")
}

#---
## Synthèse : liste des chemins retenus et volume total estimé
#---
print_summary() {
  section "Synthèse : à sauvegarder"
  local path
  for path in "${INCLUDES[@]}"; do
    printf '  + %-50s %s\n' "$path" "${INCLUDE_REASON[$path]}"
  done
  for path in "${EXCLUDES[@]}"; do
    printf '  - %-50s %s\n' "$path" "${EXCLUDE_REASON[$path]}"
  done

  local du_args=()
  local pattern
  for pattern in "${EXCLUDE_PATTERNS[@]}"; do du_args+=("--exclude=$pattern"); done
  for path in "${EXCLUDES[@]}"; do du_args+=("--exclude=$path"); done
  # du ne compte qu'une fois les dossiers imbriqués (ex. un montage sous /opt)
  local files_bytes=0
  if (( ${#INCLUDES[@]} > 0 )); then
    local out
    out=$(du -scb "${du_args[@]}" -- "${INCLUDES[@]}" 2>/dev/null || true)
    out=$(tail -1 <<< "$out")
    files_bytes="${out%%$'\t'*}"
    files_bytes="${files_bytes:-0}"
  fi
  local total=$(( files_bytes + DB_DUMP_BYTES ))

  echo
  printf '  Fichiers (sans doublon ni exclusions) : %10s\n' "$(human "$files_bytes")"
  printf '  Bases (taille sur disque, dump ≤)     : %10s\n' "$(human "$DB_DUMP_BYTES")"
  printf '  TOTAL brut                            : %10s\n' "$(human "$total")"
  printf '  Estimation compressée (restic, ÷2 à ÷3): %10s à %s\n' "$(human $(( total / 3 )))" "$(human $(( total / 2 )))"
  echo "  Chaque backup suivant n'ajoute que ce qui a changé."

  if (( ${#NOTES[@]} > 0 )); then
    section "Points d'attention"
    local note
    for note in "${NOTES[@]}"; do echo "  • $note"; done
  fi
  echo
  echo "Pour une restauration automatique, tout ce qui est listé est gardé (dont .env et dépendances installées)."
  echo "Ne retirer que ce qui est vraiment inutile (anciens projets, outils abandonnés : voir « Détail des plus gros"
  echo "sous-dossiers »), ajouter ce qui manque, puis reporter la liste dans le profil de backup."
}

main() {
  while (( $# > 0 )); do
    case "$1" in
      --no-db) QUERY_DB=0 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Option inconnue : $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
  done
  if (( EUID != 0 )); then
    echo "À lancer en root (sudo), sinon les tailles sont incomplètes." >&2
    exit 1
  fi

  inspect_system
  inspect_largest_subdirs
  inspect_apache
  inspect_docker
  inspect_postgres_host
  inspect_git_repos
  inspect_heavy_excluded
  print_summary
}

main "$@"
