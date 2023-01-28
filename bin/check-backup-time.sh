#!/bin/bash

source ${BASH_SOURCE%/*}/../secrets/var.sh
source ${BASH_SOURCE%/*}/../src/function.sh
source ${BASH_SOURCE%/*}/../utils/pre-script.sh

$timestamp_last_backup=$(cat $BACKUP_FOLDER_CONF/timestamp-last-backup)
$timestamp_backup_warning=$(date -d "-3 month" +"%s")

# Cron => Si la date est supérieur à un mois on envoi une notification avec https://docs.ntfy.sh/
if [[ $timestamp_backup_warning < $timestamp_last_backup ]]; then
    discord_notify "danger" "🚨 Backup" "▶️  Pas de backup depuis 3 mois, bouge toi !"
fi