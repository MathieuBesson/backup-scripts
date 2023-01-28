#!/bin/bash

# Script de restauration d'un serveur 
# Utilisation `restore pluton pluton2023-01-19-15-52-39_1674139959_.tar.gz`

source ${BASH_SOURCE%/*}/../secrets/var.sh
source ${BASH_SOURCE%/*}/../src/function.sh
source ${BASH_SOURCE%/*}/../utils/pre-script.sh

#---
## DEFINITION : Restauration d'un serveur 
#---
restore(){
    local server_name="$1"
    local backup_file="$2"

    # Vérifie que les deux paramètres existent
    check_have_required_params $server_name $backup_file

    # Vérifie que le serveur spécifié est présent dans la configration
    check_server_name_param_is_known $server_name

    # Récupère la configuration du serveur à restaurer
    local SERVER=SERVERS[$server_name]

    # Vérifie que le fichier de backup existe
    check_backup_file_exist $SERVER[FOLDER_BACKUP_TARGET]/$backup_file

    # Restauration du backup sur le serveur
    restore_server \
        $SERVER[FOLDER_BACKUP_SOURCE] \
        $SERVER[FOLDER_BACKUP_TARGET] \
        $backup_file \
        $SERVER[BACKUP_USER] \
        $SERVER[IP]

    # Notification de succès de la restauration du backup
    discord_notify \
        "success" \
        "✅ Backup" \
        "Le serveur ${SERVER[NAME]} à bien été sauvegardé !"
}

#---
## DEFINITION : Vérification de la présence des 2 premiers paramètres du script
## PARAMETERS : $server_name : Nom du serveur à restaurer
##              $backup_file : Nom du fichier de backup à utiliser pour la restauration
#---
check_have_required_params(){
    local server_name="$1"
    local backup_file="$1"

    if [[ -z $server_name ]] then; 
        echo "Cette commande nécéssite en paramètre le nom du serveur à restaurer en premier paramètre"
        exit
    fi

    if [[ -z $backup_file ]] then; 
        echo "Cette commande nécéssite en paramètre le nom du fichier de backup à restaurer en second paramètre"
        exit
    fi
}

#---
## DEFINITION : Vérification de la présence du nom du serveur dans la configuration
## PARAMETERS : $server_name : Nom du serveur à restaurer
#---
check_server_name_param_is_known(){
    local server_name="$1"

    if [[ $(check_serve_exist $server_name) == false ]] ; then
        echo "Le serveur $server_name n'existe pas dans la configuration de var.sh"
        exit
    fi
}

#---
## DEFINITION : Vérification de la présence du fichier de backup dans les backup du serveur en question
## PARAMETERS : $backup_file : Nom du fichier de backup à utiliser pour la restauration
#---
check_backup_file_exist(){
    local backup_file="$1"

    if [[ ! test -f $backup_file ]]; then
        echo "Le fichier de backup spécifié $backup_file n'existe pas !"
        exit
    fi
}

#---
## DEFINITION : Vérification de l'existance du serveur dans la configuration de backup
## PARAMETERS : $server_name : Nom du serveur à restaurer
#---
check_serve_exist(){
    local server_name="$1"
    local server_exist=1;

    for KEY in "${!SERVERS[@]}"; do
        eval "${SERVERS["$KEY"]}"
        if [[ ${SERVERS[NAME]} == $server_name ]]; then 
            server_exist=0
        fi
    done

    return server_exist
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

    # Décompression du dossier avec paramètre (nom du fichier)
    cd $backup_folder_target
    tar -xvf $backup_file

    # Restauration du serveur depuis le backup
    rsync -aAXHvzog \
        --numeric-ids $backup_folder_target/$backup_file $server_user@$server_ip:$backup_folder_source \
        --exclude={"/dev/","/proc/","/sys/","/tmp/","/run/","/mnt/","/media/","/lost+found"}
}

# Lancement du script
restore