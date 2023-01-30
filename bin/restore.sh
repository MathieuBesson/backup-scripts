#!/bin/bash

# Script de restauration d'un serveur 
# Utilisation `restore ichigo ichigo2023-01-19-15-52-39_1674139959_.tar.gz`

source $(dirname $(realpath ${BASH_SOURCE[0]}))/../utils/pre-script.sh

#---
## DEFINITION : Restauration d'un serveur 
#---
restore(){
    local server_name="$1"
    local backup_file="$2"

    # Vérifie que les deux paramètres existent
    check_have_required_params $server_name $backup_file

    # Vérifie que le serveur spécifié est présent dans la configuration
    check_server_name_param_is_known $server_name

    # Fix la variable $SERVER (configuration du serveur) au serveur spécifié
    fix_server_var_by_server_name $server_name

    # Vérifie que le fichier de backup existe
    check_backup_file_exist $backup_file

    # Notification de début la restauration du backup
    discord_notify \
        "warning" \
        "🚧 Backup" \
        "Restauration du serveur **${SERVER[NAME]}** (${SERVER[IP]}) en cours..."

    # Restauration du backup sur le serveur
    restore_server \
        "${SERVER[FOLDER_BACKUP_SOURCE]}" \
        "${SERVER[FOLDER_BACKUP_TARGET]}" \
        $backup_file \
        "${SERVER[BACKUP_USER]}" \
        "${SERVER[IP]}"

    # Notification de succès de la restauration du backup
    discord_notify \
        "success" \
        "✅ Backup" \
        "Le serveur **${SERVER[NAME]}** à bien restauré avec le fichier de backup : __*$backup_file*__ !"
}

#---
## DEFINITION : Vérification de la présence des 2 premiers paramètres du script
## PARAMETERS : $server_name : Nom du serveur à restaurer
##              $backup_file : Nom du fichier de backup à utiliser pour la restauration
#---
check_have_required_params(){
    local server_name2="$1"
    local backup_file="$2"

    if [[ -z $server_name2 ]]; then 
        echo "Cette commande nécéssite en 1er paramètre le nom du serveur à restaurer"
        exit
    fi

    if [[ -z $backup_file ]]; then 
        echo "Cette commande nécéssite en 2nd paramètre le nom du fichier de backup à restaurer"
        exit
    fi
}

#---
## DEFINITION : Vérification de la présence du fichier de backup dans les backup du serveur en question
## PARAMETERS : $backup_file : Nom du fichier de backup à utiliser pour la restauration
#---
check_backup_file_exist(){
    local backup_file="$1"

    if [[ ! -f $backup_file ]]; then
        echo "Le fichier de backup spécifié $backup_file n'existe pas !"
        exit
    fi
}

#---
## DEFINITION : Restauration du serveur
## PARAMETERS : $backup_folder_source : Dossier source de backup du serveur à restaurer
##              $backup_folder_target : Dossier cible de backup du serveur (contenant les backups)
##              $backup_file : Nom du fichier à utiliser pour la restauration
##              $server_user : Utilisateur du serveur à utiliser pour la restauration
##              $server_ip : Ip du serveur à restaurer
#---
restore_server(){
    local backup_folder_source="$1"
    local backup_folder_target="$2" 
    local backup_file="$3" 
    local server_user="$4" 
    local server_ip="$5"
    local folder_backup_tmp="$backup_folder_target/backup-tmp/"

    # Décompression du dossier avec paramètre (nom du fichier)
    mkdir -p $folder_backup_tmp
    tar -xvf $backup_file -C $folder_backup_tmp

    # Restauration du serveur depuis le backup
    rsync -aAXHvzog \
        --delete \
        --numeric-ids $folder_backup_tmp $server_user@$server_ip:$backup_folder_source \
        --exclude={"/dev/","/proc/","/sys/","/tmp/","/run/","/mnt/","/media/","/lost+found"}

    rm -rf $folder_backup_tmp
}

# Lancement du script
restore $1 $2