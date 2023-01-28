#!/bin/bash

#---
## DEFINITION : Envoi une notification par l'intermédiaire des webhook discord
## PARAMETERS : $server_user : Utilisateur du serveur à sauvegarder
##              $server_ip : Ip du serveur à sauvegarder
##              $title : Titre du message 
##              $content : Contenu du message 
##              $type : Type de message (success, danger...)
#---
discord_notify(){
    local type="$1"
    local title="$2"
    local content="$3"

    curl -H \"Content-Type: application/json" -X POST -d "$(generate_post_data $title $content $type)\" $DISCORD_WEBHOOK_URL
}

#---
## DEFINITION : Génère le contenu de la requête à transmettre à discord
## PARAMETERS : $title : Titre du message 
##              $content : Contenu du message 
##              $type : Type de message (success, danger...)
#---
generate_post_data() {
    local title="$1"
    local content="$2"
    local type="$3"

    local color="2719971"
    if $type == "success"; then
        color="45973"
    else if $type == "danger"; then
        color="14887209"
    fi 

  cat <<EOF
{
  "embeds": [{
    "title": "$title",
    "description": "$content",
    "color": "$color"
  }]
}
EOF
}