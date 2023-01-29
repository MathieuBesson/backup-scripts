#!/bin/bash

script_folder=$(dirname $(realpath ${BASH_SOURCE[0]}))

source $script_folder/../secrets/var.sh
source $script_folder/../src/function.sh

check_is_launcher_user "root"