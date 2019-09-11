#!/bin/bash  

_script="imdbadd.sh"  # name of this file. For log reasons.
source /drive/drive/.rtorrent/scripts/v3/bot/functions.sh # always call this lib
if [ "$channel" != "" ]; then who="$channel";fi # Ska vi svar i gruppechat eller privat?
regex="^(https?\:\/\/)?(www\.)?imdb\.com\/.+$"
input="${cmd#*/title/}" # strip urlen førr data
input="${input//\//}"   # fjern unødvendige ting
# debug mutes the the output from from this v2-script 
DEBUG="yes" /drive/drive/.rtorrent/scripts/irssi.sh .request $input # kjør requesten
request_response="$(cat /tmp/$input.response)" # Hent responsen
rm /tmp/$input.response # removes the temp file
case $request_response in
	# notfound, added, alreadyadded, errortryagain,ttdbnull
	'added')
	say "$who :Thx, la den tel"
	put.last;;
'alreadyadded')
	say "$who :Allerede i Plex.";put.last ;; 
'notfound')
	: ;;
'errortryagain')
	: ;; 
'ttdbnull')
	: ;;
esac
