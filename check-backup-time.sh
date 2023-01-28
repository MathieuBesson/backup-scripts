#!/bin/bash

source ${BASH_SOURCE%/*}/var.sh
source ${BASH_SOURCE%/*}/function.sh

$timestamp_last_backup=$(cat $BACKUP_FOLDER_CONF/timestamp-last-backup)
$timestamp_backup_warning=$(date -d "-3 month" +"%s")

# Cron => Si la date est supérieur à un mois on envoi une notification avec https://docs.ntfy.sh/
if [[ $timestamp_backup_warning < $timestamp_last_backup ]]; then
    discord_notify "danger" "🚨 Backup" "▶️  Pas de backup depuis 3 mois, bouge toi !"
fi