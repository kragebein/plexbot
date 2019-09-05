#!/bin/bash
source /drive/drive/.rtorrent/scripts/v3/bot/functions.sh
JSON="$(curl -s "$tt_hostname/api/v2?apikey=$tt_apikey&cmd=get_library_media_info&section_id=2&length=999")"
#echo "$tt_host/api/v2?apikey=$tt_apikey&cmd=get_library_media_info&section_id=2&length=999"
num="$(echo "$JSON" |jq -r '.response.data.recordsTotal')"
echo "$num"
COUNTER=0
while [ "$COUNTER" -le "$num" ]; do
	rating_key="$(echo "$JSON" |jq -r ".response.data.data[$COUNTER].rating_key" 2>/dev/null)"
	metadata="$(curl -s "http://cr.wack:8181/api/v2?apikey=$c_api&cmd=get_metadata&rating_key=$rating_key")"
	imdb="$(echo "$metadata" |jq -r ".response.data.guid" 2>/dev/null)"
	imdb_rating="$(echo "$metadata" |jq -r '.response.data.rating' 2>/dev/null)"
	imdb=${imdb##*//};imdb=${imdb%%\?*}
	file="$(echo "$metadata" | jq '.response.data.media_info[0].parts[0].file' |tr -d \')"
	if [ "$imdb_rating" != "null" ]; then	# Entries without ratings are remnants of old content in the library
		file="$(echo "$metadata" | jq -r '.response.data.media_info[0].parts[0].file' |tr -d \' 2>/dev/null)"
		sql3 "INSERT into content VALUES('$imdb', '$rating_key', '$file')"
	fi
	let COUNTER=COUNTER+1

done

