#!/bin/bash

# Script de backup des serveurs définis dans ./var.sh

source $(dirname $(realpath ${BASH_SOURCE[0]}))/../utils/pre-script.sh

#---
## DEFINITION : Backup des serveurs configurés sur la machine lançant le script 
#---
backup(){
    local server_name="$1"

    discord_notify \
        "warning" \
        "🚧 Backup" \
        "Backup des serveurs en cours..."

    # Dans le cas ou un serveur en particulier est spécifié
    if [[ ! -z $server_name ]] ; then
        # Vérification d'une configuration présente 
        check_server_name_param_is_known $server_name
    fi
    
    for KEY in "${!SERVERS[@]}"; do
        eval "${SERVERS["$KEY"]}"

        # Dans le cas on un seveur est spécifié et qu'il correspond à une conf, ou qu'aucun serveur est spécifié => on backup
        if [[ ! -z $server_name && $server_name == $KEY ]]  || [[ -z $server_name ]]; then

            local FOLDER_NAME_BACKUP_TMP="backup-tmp"
                        
            # Récupération du backup du serveur
            pull_backup \
                "${SERVER[BACKUP_USER]}" \
                "${SERVER[IP]}" \
                "${SERVER[FOLDER_BACKUP_SOURCE]}" \
                "${SERVER[FOLDER_BACKUP_TARGET]}/$FOLDER_NAME_BACKUP_TMP" 

            # Compression du backup
            compress_folder \
                "${SERVER[FOLDER_BACKUP_TARGET]}/$FOLDER_NAME_BACKUP_TMP" \
                "${SERVER[NAME]}-$(date +%Y-%m-%d-%H-%M-%S_%s_).tar.gz" \
                "${SERVER[FOLDER_BACKUP_TARGET]}"

            # Sauvegarde du timestamp du dernier backup 
            save_timestamp_last_backup \
                "${SERVER[BACKUP_USER]}" \
                "${SERVER[IP]}" \
                "${SERVER[FOLDER_BACKUP_PARAMETERS]}"

            # Supprime les anciens backups 
            delete_old_backup "${SERVER[FOLDER_BACKUP_TARGET]}"

            # Notification par SMS du backup terminée
            discord_notify \
                "success" \
                "✅ Backup ${SERVER[NAME]} (${SERVER[IP]})" \
                "Le serveur **${SERVER[NAME]}** (${SERVER[IP]}) à bien été sauvegardé !"
        fi
    done

    discord_notify \
        "success" \
        "✅ Backup" \
        "Backup des serveurs terminé."
}

#---
## DEFINITION : Backup des serveurs configurés sur la machine lançant le script 
## PARAMETERS : $server_user : Utilisateur avec lequel se connecter sur le serveur à sauvegarder
##              $server_ip : Ip du serveur à sauvegarder
##              $folder_source : Dossier source du backup
##              $folder_target : Dossier cible du backup
#---
pull_backup(){
    local server_user="$1"
    local server_ip="$2"
    local folder_source="$3"
    local folder_target="$4"

    # Créer les dossiers de backup si inexistants
    mkdir -p "$folder_target"

    # Récupération du contenu chaud de la machine
    rsync -aAXHzovg \
        --numeric-ids -o -g $server_user@$server_ip:$folder_source \
        --exclude={"/dev/","/proc/","/sys/","/tmp/","/run/","/mnt/","/media/","/lost+found"} \
        "$folder_target"
}

#---
## DEFINITION : Compression d'un dossier 
## PARAMETERS : $parent_folder : Dossier parent du fichier à compresser
##              $folder_name_to_compress : Nom du fichier à compresser
##              $folder_compress_name : Nom du fichier compresser final 
#---
compress_folder(){
    local folder_to_compress="$1"
    local folder_compress_name="$2"
    local folder_store_backup="$3"

    # Compression
    tar -zcf $folder_store_backup/$folder_compress_name -C $folder_to_compress .

    # Suppression du fichier d'origine de compression
    rm -rf $folder_to_compress
}

#---
## DEFINITION : Sauvegarde du timestamp de dernier backup sur le serveur sauvegardé
## PARAMETERS : $server_user : Utilisateur avec lequel se connecter sur le serveur à sauvegarder
##              $server_ip : Ip du serveur à sauvegarder
##              $FOLDER_BACKUP_PARAMETERS : Chemin du dossier de confguration du backup
#---
save_timestamp_last_backup(){
    local server_user="$1"
    local server_ip="$2"
    local FOLDER_BACKUP_PARAMETERS="$3"

    # Sauvegarde de la date de dernier backup 
    ssh $server_user@$server_ip "echo $(date +%s) > $FOLDER_BACKUP_PARAMETERS/timestamp-last-backup"
}

#---
## DEFINITION : Supression des anciens backups
## PARAMETERS : $folder_backup : Dossier des backup du serveur
#---
delete_old_backup(){
    local folder_backup="$1"

    timestamp_backup_delete=$(date -d "-9 month" +"%s")
    number_of_backups=$(ls -lR $folder_backup/ | grep ".tar.gz$" | wc -l)

    # Supprime les backup vieux de + de 9 mois si on à + de 3 fichiers
    if [[ $number_of_backups > 0 ]]; then
        for filename in $folder_backup/*.tar.gz; do
            [ -e "$filename" ] || continue

            timestampfile=$(echo $filename | cut -d"_" -f2)
            if [[ $timestamp_backup_delete > $timestampfile ]]; then
                date_backup=$(date -d @$timestampfile)
                echo "Suppression du backup du ${date_backup} : ${filename}"
                rm -rf $filename
            fi
        done
    fi
}

# Lancement du script
backup $1