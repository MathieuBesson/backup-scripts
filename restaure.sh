#!/bin/bash

source ${BASH_SOURCE%/*}/var.sh
source ${BASH_SOURCE%/*}/pre-script.sh


#---
## DEFINITION : Restauration du serveur 
#---
backup(){
    
}

# Vérifier que le serveur spécifier existe
# Vérifier que le fichier de backup spécifier existe dans le dossier de backup config opur ce serveur


for KEY in "${!SERVERS[@]}"; do
   eval "${SERVERS["$KEY"]}"
   for KEY in "${!SERVER[@]}"; do
      printf "INSIDE $KEY - ${SERVER["$KEY"]}\n"
   done
   echo ''
done

if [[ -z "$1" ]] then; 
    echo "Cette commande nécéssite en paramètre le nom du fichier de backup à restaurer"
    exit
fi


if [[ ! test -f $BACKUP_FOLDER_CIBLE/$1 ]]; then
    echo "Le fichier de backup spécifié $1 n'existe pas !"
    exit
fi

# Décompression du dossier avec paramètre (nom du fichier)
cd $BACKUP_FOLDER_CIBLE
tar -xvf $1

# Restauration
rsync -aAXHvzog --numeric-ids $BACKUP_FOLDER_CIBLE $BACKUP_SERVER_USER@$BACKUP_SERVER_IP:$BACKUP_FOLDER_SOURCE --exclude={"/dev/","/proc/","/sys/","/tmp/","/run/","/mnt/","/media/","/lost+found"}

discord_notify "success" "✅ Backup" "Le serveur ${SERVER[NAME]} à bien été sauvegardé !"