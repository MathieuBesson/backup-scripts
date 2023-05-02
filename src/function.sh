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

  local body=$(generate_post_data "$title" "$content" "$type")

  echo "$title : $content"

  curl -H "Content-Type: application/json" -X POST -d "$body" $DISCORD_WEBHOOK_URL
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
  if [[ $type == "success" ]]; then
      color="45973"
  elif [[ $type == "danger" ]]; then
      color="14887209"
  elif [[ $type == "warning" ]]; then
      color="15130951"
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

#---
## DEFINITION : Vérifie que l'utilisateur lançant la commande est le bon
## PARAMETERS : $user : Utilisateur autorisé à lancer la commande
#---
check_is_launcher_user(){
  local user="$1"

  if [[ $(whoami) != $user ]]; then
    echo "Ce script est à lancer avec l'utilisateur $user"
    exit
  fi
}

#---
## DEFINITION : Vérification de la présence du nom du serveur dans la configuration
## PARAMETERS : $server_name : Nom du serveur à restaurer
#---
check_server_name_param_is_known(){
    local server_name="$1"

    if ! check_serve_exist $server_name; then
        echo "Le serveur $server_name n'existe pas dans la configuration de var.sh"
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
        if [[ ${SERVER[NAME]} == $server_name ]]; then 
            server_exist=0
        fi
    done

    return $server_exist
}

#---
## DEFINITION : Fixe la variable $SERVER (configuration du serveur) au serveur spécifié
## PARAMETERS : $server_name : Nom du serveur spécifié
#---
fix_server_var_by_server_name(){
  local server_name="$1"

  for KEY in "${!SERVERS[@]}"; do
    eval "${SERVERS["$KEY"]}"
    if [[ ${SERVER[NAME]} == $server_name ]]; then
        break
    fi
  done
}