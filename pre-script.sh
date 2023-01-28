#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Ce script est à lancer avec l'utilisateur root"
  exit
fi
