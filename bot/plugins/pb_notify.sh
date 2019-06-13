#!/bin/bash - 
#===============================================================================
#
#          FILE: pb_notify.sh
# 
#         USAGE: ./pb_notify.sh 
# 
#   DESCRIPTION: TODO: wondering if this is better suited for sqlite3
source $pb/../../master.sh
_script="pb_notify.sh"
#regex="^[.]notify.+$"
cmd="${cmd//.notify /}"

if [[ "$cmd" =~ ^[0-9]{1,3}(.*)$ ]]; then
	imdbid="$(cat /tmp/.sbuf |grep -w "$cmd" |awk -F ' ' '{print $2}')"
else
    imdbid="$(echo "$cmd" | egrep -wo "tt[0-9]{1,19}")"
fi


rating_key="${RANDOM}"
if [ "$imdbid" = "null" ]; then
	say "$who : wtf? Glitch in the matrix. Getting a bug from higher up"
    log e "pb_notify, imdbid unset."
fi

count=$(myq "plexbot SELECT count(*) FROM  notify WHERE imdbid='$imdbid' AND who='$who'")
data=$(curl -s "http://www.omdbapi.com/?i=$imdbid&apikey=$o_key")
make=$(echo "$data" |jq -r '.Type')
if [ "$make" = "null" ]; then
	if [ "$2" = ".notify" ]; then
		say "$who :Skrev du rett nå?"
		say "$who :>$who .notify $imdbid"
	fi
	exit
fi
title=$(echo "$data" |jq -r '.Title')

first_time() {
	if [ "$(myq "plexbot SELECT count(*) FROM  notify WHERE who='$who'")" = "0" ]; then 
		say "$orig_who :Hei! Som en del av varslingsfunksjonen må du godta den her chatten først!"
	fi
}

notify_add() {
	if [ "$cmd" = "request" ]; then
		if [ "$make" = "movie" ]; then
			if [ "$(cat /tmp/.request.$imdbid)" = "$imdbid" ]; then
				myq "plexbot INSERT INTO notify VALUES('$orig_', '$imdbid', '$rating_key');"
				rm /tmp/.request.$imdbid
				exit
			fi
		fi
	else
		myq "plexbot INSERT INTO notify VALUES('$orig_who', '$imdbid', '$rating_key');"
		if [ "$make" = "series" ]; then
			say "$who :Du har aktivert varsler for $title, du vil bi varlsa når neste episode e kommet på Plex."
		else
			say "$who :Du har aktivert varsel for $title, du vil bi varsla når filmen e kommet på plex."
		fi
	fi

}

notify_del() {
	myq "plexbot DELETE FROM notify WHERE imdbid='$imdbid' AND who='$who';"
	say "$RES :Du har deaktivert varsel for $title."
}

if [ "$count" = "0" ]; then
	first_time
	notify_add
else
	notify_del
fi

