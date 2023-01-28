#!/bin/bash

# Script de backup des serveurs définis dans ./var.sh

source ${BASH_SOURCE%/*}/var.sh
source ${BASH_SOURCE%/*}/function.sh
source ${BASH_SOURCE%/*}/pre-script.sh

#---
## DEFINITION : Backup des serveurs configurés sur la machine lançant le script 
#---
backup(){
    for KEY in "${!SERVERS[@]}"; do
        eval "${SERVERS["$KEY"]}"

        local FOLDER_NAME_BACKUP_TMP="backup-tmp"
        
        # Récupération du backup du serveur
        # pull_backup "${SERVER[BACKUP_USER]}" "${SERVER[IP]}" "${SERVER[FOLDER_BACKUP_SOURCE]}" "${SERVER[FOLDER_BACKUP_TARGET]}/$FOLDER_NAME_BACKUP_TMP" 

        # Compression du backup
        # compress_folder "${SERVER[FOLDER_BACKUP_TARGET]}" "${SERVER[NAME]}" "${SERVER[FOLDER_BACKUP_TARGET]}/$FOLDER_NAME_BACKUP_TMP" "${server_name}$(date +%Y-%m-%d-%H-%M-%S__%s__).tar.gz"

        # Sauvegarde du timestamp du dernier backup 
        # save_timestamp_last_backup "${SERVER[BACKUP_USER]}" "${SERVER[IP]}" "${SERVER[FOLDER_BACKUP_CONF]}"

        # Supprime les anciens backups 
        # delete_old_backup "${SERVER[FOLDER_BACKUP_TARGET]}"

        # Notification par SMS du backup terminée
        # discord_notify "success" "✅ Backup" "Le serveur ${SERVER[NAME]} à bien été sauvegardé !"
    done
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

    rsync -aAXHvzog --numeric-ids -o -g $server_user@$server_ip:$folder_source --exclude={"/dev/","/proc/","/sys/","/tmp/","/run/","/mnt/","/media/","/lost+found"} "$folder_target/backup-tmp"
}

#---
## DEFINITION : Compression d'un dossier 
## PARAMETERS : $parent_folder : Dossier parent du fichier à compresser
##              $folder_name_to_compress : Nom du fichier à compresser
##              $folder_compress_name : Nom du fichier compresser final 
#---
compress_folder(){
    local parent_folder="$1"
    local folder_name_to_compress="$2"
    local folder_compress_name="$3"

    # Compression
    cd $parent_folder
    tar -zcvf $folder_compress_name $folder_name_to_compress

    # Suppression du fichier d'origine de compression
    rm -rf $folder_name_to_compress
}

#---
## DEFINITION : Sauvegarde du timestamp de dernier backup sur le serveur sauvegardé
## PARAMETERS : $server_user : Utilisateur avec lequel se connecter sur le serveur à sauvegarder
##              $server_ip : Ip du serveur à sauvegarder
##              $folder_backup_conf : Chemin du dossier de confguration du backup
#---
save_timestamp_last_backup(){
    local server_user="$1"
    local server_ip="$2"
    local folder_backup_conf="$3"

    # Sauvegarde de la date de dernier backup 
    ssh $server_user@$server_ip "echo $(date +%s) > $folder_backup_conf/timestamp-last-backup"
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
backup