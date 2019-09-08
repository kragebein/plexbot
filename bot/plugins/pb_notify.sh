#!/bin/bash - 
#===============================================================================
#
#          FILE: pb_notify.sh
# 
#         USAGE: ./pb_notify.sh 
# 
#   DESCRIPTION: Enables a notify function, when a user requests a movie/show
# 				 the bot will notify them through private message as well as 
#				 through the announce channel.
# 				-----------------------------
#				Warn: This plugin is used in line 53 in core.sh


_script="pb_notify.sh"
regex="^[.]notify"
cmd="${cmd//.notify /}"
who="$who" cmd="${cmd#.calendar *}" channel="$channel"

notify() {
if [ -z "$cmd" ]; then
say "$who :Må ha med argument førr å kun bruk den her..";exit
fi
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

count=$(sql "SELECT count(*) FROM  notify WHERE imdbid='$imdbid' AND who='$who_orig'")
data=$(curl -s "http://www.omdbapi.com/?i=$imdbid&apikey=$omdb_key")
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
	if [ "$(sql "SELECT count(*) FROM  notify WHERE who='$who_orig'")" = "0" ]; then 
		say "$who_orig :Hei! Som en del av varslingsfunksjonen må du godta den her chatten først!"
	fi
}

notify_add() {
	if [ "$cmd" = "request" ]; then
		if [ "$make" = "movie" ]; then
			if [ "$(cat /tmp/.request.$imdbid)" = "$imdbid" ]; then
				sql "INSERT INTO notify VALUES('$who_orig', '$imdbid', '$rating_key');"
				rm /tmp/.request.$imdbid
				exit
			fi
		fi
	else

		sql "INSERT INTO notify VALUES('$who_orig', '$imdbid', '$rating_key');"
		if [ "$make" = "series" ]; then
			say "$who :Du har aktivert varsler for $title, du vil bi varlsa når neste episode e kommet på Plex."
		else
			say "$who :Du har aktivert varsel for $title, du vil bi varsla når filmen e kommet på plex."
		fi
	fi

}

notify_del() {
	sql "DELETE FROM notify WHERE imdbid='$imdbid' AND who='$who';"
	say "$RES :Du har deaktivert varsel for $title."
}

if [ "$count" = "0" ]; then
	first_time
	notify_add
else
	notify_del
fi
}

notify "$@"
