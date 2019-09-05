#!/bin/bash - 
#===============================================================================
#
#          FILE: wishlist.sh
# 
#         USAGE: ./wishlist.sh 
# 
#   DESCRIPTION: 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 08/25/2019 09:41
#      REVISION:  ---
#===============================================================================
source /drive/drive/.rtorrent/scripts/v3/bot/functions.sh
_script="wishlist"
if [ "$channel" != "" ]; then who="$channel";fi # kommer requesten fra en kanal, gje svar i kanalen.
regex="^[.]wishlist"
#
input="${cmd#*.wishlist}"

json=$(curl -s $couchpotato/api/$sofa_api/media.list/?status=active)
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
		echo "$imdb - $title ($year) [$rating]" >> $buffer
	done
	let CNT=CNT+1
done
while read line;do
	say "$who :$line"
done < $buffer
rm $buffer
say "$who :Totalt $CNT filmer i listen"


