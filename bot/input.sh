#!/bin/bash -
#===============================================================================
#          FILE: input.sh
#         USAGE: ./input.sh
#   DESCRIPTION: Keeps everything in check while sanitizing input and forward correct params
#        AUTHOR: YOUR NAME (),
#       CREATED: 02/24/2019 14:30
#      REVISION:  ---
#===============================================================================
pb="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
#cd source "$pb/../../master.sh" # master.sh innehold endel keys som fortsatt trengs.
source "$pb/functions.sh" # TODO: erstatt master.sh
_script="plexbot_commands"
while getopts "u:c:m:" flag; do case $flag in u)who="$OPTARG";who_orig="$OPTARG";;c) channel="$OPTARG" ;; m) cmd="${OPTARG/\'/\\\'}" ;; esac done

if [ "$channel" != "" ]; then who="$channel"; fi
if [ "$bot_active" = "no" ]; then
	exit
fi
# Dynamic plugin loader. (reloadconfig will reload plugin array)
source "$pb/plugins/.loaded"
for i in "${!plug[@]}"; do
	if [[ "$cmd" =~ ${plug[$i]} ]]; then
		load "$i"
	fi
done
# CORE FUNCTIONS - These will only load the core when triggered.
if [[ "$cmd" =~ ^[.]reloadconfig ]]; then
	req_admin
	reload_plugins
fi
if [[ "$cmd" =~ ^[.]request ]]; then
	uac
	load "$pb/core.sh"
	cmd="${cmd//.request /}"
	setflags
	check_request_flags "$cmd"
	check_input
	parse_imdb
	parse_sofa

fi

if [[ "$cmd" =~ ^[.]search ]]; then
	uac
	load "$pb/core.sh"
	imdb_look "${cmd//.search /}"
fi

if [[ "$cmd" =~ ^[.]showplugins ]]; then
	uac
	say "$who :Loaded plugins and their triggers"
	for i in "${!plug[@]}"; do
		say "$who : ${i##*/} =~ ${plug[$i]}"
	done
fi
if [[ "$cmd" =~ ^[.]help ]]; then
	uac
	IFS=$'\n'
	for i in $(cat "$pb/../help/users.text"); do say "$who : $i"; done
	DEBUG=yes req_admin
	if [ "$bot_admin" = "y" ]; then
		IFS=$'\n'
		for i in $(cat "$pb/../help/admin.text"); do say "$who :$i"; done
	fi
fi
