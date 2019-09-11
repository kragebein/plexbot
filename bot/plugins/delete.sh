#!/bin/bash -
_script="delete.sh"
source /drive/drive/.rtorrent/scripts/v3/bot/functions.sh
if [ "$channel" != "" ]; then who="$channel"; fi
regex="^!delete"
req_admin
y=0
imdbid="${cmd#*\!delete }"
if [ "$imdbid" = '!delete' ]; then
	say "$who :Den her funksjonen krev et imdb-id argument. F.eks !delete tt123456"
	exit
fi

sleepdo() {
	sleep 30s
	sql "DELETE from deletewarn WHERE who='$who_orig' AND imdbid='$imdbid'"
}
sqlwho="$(sql "SELECT who FROM deletewarn WHERE imdbid='$imdbid'")"
ojson=$(curl -s "http://www.omdbapi.com/?i=$imdbid&apikey=$omdb_key&type=series")
title="$(echo "$ojson" | jq -r '.Title')"
type="$(echo "$ojson" | jq -r .Type)"
ttdb "$imdbid" # this creates $rating_key

case "$type" in
'series')
	if [ "$who_orig" = "$sqlwho" ]; then
		#This is the second run, go ahead and delete this.
		for i in $(sql "SELECT filepath from content WHERE imdbid='$imdbid'"); do
			array[$y]=$i
			let y=y+1
			rm -rf "$filepath"
			sql "DELETE from content WHERE imdbid='$imdbid'"
		done
		curl -s "$sr_hostname/api/$sr_apikey/?cmd=show.delete&tvdbid=$rating_key"
		say "$who :$title og dens ${#array[@]} episoda e fjerna fra Plex."
	else

		for i in $(sql "SELECT filepath from content WHERE imdbid='$imdbid'"); do
			array[$y]=$i
			let y=y+1
			debug "${array[$y]}"
		done
		if [ "$(echo ${#array[@]})" = "0" ]; then
		# Show not found in local database, so files not present.. Lets check SR.
		_check=$(curl -s "$sr_hostname/api/$sr_apikey/?cmd=show.cache&tvdbid=$rating_key")
			case $(echo "$_check" |jq -r '.result') in
				'success')
				say "$who :Serien ligg i wishlist, men fant den ikke på Plex! Gjenta kommandoen om den ska slættes fra wishlist."
				sleepdo &
				exit
				;;
				'failure') 
				say "$who :Den her serien e ikke på plex."
				exit
			esac
		fi

		say "$who :Det her bi å å slett ${#array[@]} episoda av \"$title\"."
		say "$who :førr å faktisk slett, gjenta kommandoen innen 30 sekunda."
		sql "INSERT INTO deletewarn VALUES('$who_orig','$imdbid')"
		sleepdo &
		exit

	fi
	;;
'movie')
	if [ "$who_orig" = "$sqlwho" ]; then
		#This is the second run, go ahead and delete this.
		case "$(curl -s "$cp_hostname/api/$cp_apikey/media.get/?id=$imdbid" | jq -r '.media.status')" in
		'active')
			say "$who :Filmen lå kun i wishlist. Fjerna den derfra."
			;;
		'false')
			say "$who :Filmen fins ikke på Plex."
			;;
		'done') # Actually delete the file(s) requested.
			filepath="$(sql "SELECT filepath FROM content WHERE imdbid='$imdbid'")"
			rm -rf "$filepath"
			sql "DELETE from content WHERE imdbid='$imdbid'"
			curl -s "$cp_hostname/api/$cp_apikey/media.delete/?id=$imdbid"
			echo "$title e sletta fra Plex."
			;;
		esac
	else
		say "$who :Det her bi å slett $title fra Plex. Gjenta kommando førr å slett."
		sql "INSERT INTO deletewarn VALUES('$who_orig','$imdbid')"
		sleepdo &
		exit
	fi
	;;
*)
	say "$who :Den IDen der ga ikke nå meining."
	;;
esac
