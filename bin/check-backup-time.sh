#!/bin/bash

# Script de vérification de date du dernier backup (+ notification)

source $(dirname $(realpath ${BASH_SOURCE[0]}))/../utils/pre-script.sh

check_backup_time(){
    for KEY in "${!SERVERS[@]}"; do
        eval "${SERVERS["$KEY"]}"
        if [[ ${SERVERS[NAME]} == $HOST ]]; then 
            break
        fi
    done

    timestamp_last_backup=$(cat ${SERVER[FOLDER_BACKUP_PARAMETERS]}/timestamp-last-backup)
    timestamp_backup_warning=$(date -d "-${SERVER[NUMBER_OF_DAYS_WITHOUT_WARNING]} days" +"%s")

    if [[ $timestamp_last_backup < $timestamp_backup_warning ]]; then
        discord_notify "danger" "🚨 Backup" "▶️  Pas de backup de ${SERVER[NAME]} (${SERVER[IP]}) depuis ${SERVER[NUMBER_OF_DAYS_WITHOUT_WARNING]} jours, bouge toi !"
    fi
}

check_backup_time