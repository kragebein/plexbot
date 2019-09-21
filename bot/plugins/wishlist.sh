#!/bin/bash - 
#===============================================================================

source /drive/drive/.rtorrent/scripts/v3/bot/functions.sh
_script="wishlist"
if [ "$channel" != "" ]; then who="$channel";fi # kommer requesten fra en kanal, gje svar i kanalen.
regex="^[.]w"
#
input="${cmd#*.w }"
case $input in 
'f'|'F')
json=$(curl -s "$cp_hostname/api/$cp_apikey/media.list/?status=active")
TOT=$(echo "$json" |jq -r '.total')
CNT=0
buffer="$(mktemp)"
say "$who :Vennligst vent, kompilerer.."
while [ "$CNT" -lt "$TOT" ]; do
	for i in $(echo "$CNT"); do

		#		IFS='|' read title imdb rating year < <(echo $json | jq -r ".data[$i] |  map([.info.original_title, .identifiers.imdb, .info.rating_imdb[0] , .info.year] | join("|")) | join("\n")")
		title=$(echo "$json" |jq -r ".movies[$i].info.original_title")
		imdb=$(echo "$json" | jq -r ".movies[$i].identifiers.imdb")
		rating=$(echo "$json" |jq -r ".movies[$i].info.rating.imdb[0]")
		if [ "$rating" = "0" ]; then rating="0.0"; fi
		year=$(echo "$json" |jq -r ".movies[$i].info.year")
		if [ "$rating" = "null" ]; then year="in";rating="development";fi
		echo "$imdb - $title ($year) [$rating]" >> "$buffer"
	done
	let CNT=CNT+1
done
while read line;do
	say "$who :$line"
done < "$buffer"
rm "$buffer"
say "$who :Totalt $CNT filma i lista" ;;

's'|'F')
k=0
	for i in $(sql "SELECT imdbid FROM s_wishlist"); do
		data="$(curl -s "http://www.omdbapi.com/?i=$i&apikey=$omdb_key&plot=full")"
		title="$(echo "$data" | jq -r '.Title')"
		year="$(echo "$data" | jq -r '.Year')"
		rating="$(echo "$data" | jq -r '.Ratings[0].Value')"
		if [ "$title"  != "null" ]; then
		say "$who :$i - $title ($year) [$rating]"
		let k=k+1
		fi
	done 
		if [ "$k" = 0 ]; then
		say "$who :Ingen seria i ønskelista" 
		elif [ "$k" != 0 ]; then
		say "$who :Totalt $k seria i lista."
		fi
;; 
*)
	say "$who : bruk .w (series|movies)"
esac

