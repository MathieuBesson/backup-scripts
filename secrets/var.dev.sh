#!/bin/bash

declare -A SERVERS
declare -A SERVER

SERVER=(
  [NAME]="pluton"
  [IP]="0.0.0.0"
  [BACKUP_USER]="root"
  [FOLDER_BACKUP_SOURCE]="/"
  [FOLDER_BACKUP_TARGET]="/backup/pluton"
  [FOLDER_BACKUP_GLOBAL]="/backup"
  [FOLDER_BACKUP_PARAMETERS]="/etc/backup"
  [NUMBER_OF_DAYS_WITHOUT_WARNING]="90"
)
SERVERS["pluton"]=$(declare -p SERVER)

DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/{id}/{token}"

# Pour boucler sur les infos de SERVERS : 
# for KEY in "${!SERVERS[@]}"; do
#    eval "${SERVERS["$KEY"]}"
#    for KEY in "${!SERVER[@]}"; do
#       printf "INSIDE $KEY - ${SERVER["$KEY"]}\n"
#    done
#    echo ''
# done