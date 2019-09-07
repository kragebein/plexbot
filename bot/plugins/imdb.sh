#!/bin/bash  

_script="imdbadd.sh"  # name of this file. For log reasons.
source /drive/drive/.rtorrent/scripts/v3/bot/functions.sh # always call this lib
if [ "$channel" != "" ]; then who="$channel";fi # Ska vi svar i gruppechat eller privat?
uac
regex="^[.]imdb"
input="${cmd#*.imdb }"
id_key="$input"
if [ "$id_key" = ".imdb" ]; then
	id_key="$(cat $imdbidfile)"
fi
data="$(curl -s "http://www.omdbapi.com/?i=$id_key&apikey=$omdb_key&plot=full")"
# general data
title="$(echo "$data" | jq -r '.Title')"
released="$(echo "$data" | jq -r '.Released')"
year="$(echo "$data" | jq -r '.Year')"
rating="$(echo "$data" | jq -r '.Ratings[0].Value')"
actors="$(echo "$data" | jq -r '.Actors')"
plot="$(echo "$data" | jq -r '.Plot')"
seasons="$(echo "$data" | jq -r '.totalSeasons')"
_type="$(echo "$data" | jq -r '.Type')"
runtime="$(echo "$data" | jq -r '.Runtime')"
ratingkey="$(/drive/drive/.rtorrent/scripts/imdbconv.sh $id_key | awk -F ":" '{print $4}')"
meta="$(curl -s "$tt_hostname/api/v2?apikey=$tt_apikey&cmd=get_metadata&rating_key=$ratingkey")"
echo "id_key=$id_key - $title"
case $_type in
	'series')
		say "$who :*$title*, released $released ($rating)."
		say "$who :*Active years*: $year (seasons: $seasons)"
		say "$who :*Actors*: $actors"
		say "$who :*plot*: $plot";;
	'movie'|'documentary'|'anime')
		file="$(echo $meta |jq -r '.response.data.media_info[0].parts[0].file')"
		video_bit="$(echo "$meta" |jq -r '.response.data.media_info[0].parts[0].streams[0].video_bitrate')"
		video_width="$(echo "$meta"  |jq -r '.response.data.media_info[0].parts[0].streams[0].video_width')"
		video_height="$(echo "$meta"  |jq -r '.response.data.media_info[0].parts[0].streams[0].video_height')"
		video_codec="$(echo "$meta"  |jq -r '.response.data.media_info[0].parts[0].streams[0].video_codec')"
		video_fps="$(echo "$meta" |jq -r '.response.data.media_info[0].parts[0].streams[0].video_frame_rate' |awk -F "." '{print $1}')"
		say "$who :$title, released $released ($rating)."
		say "$who :Active years: $year (runtime: $runtime)"
		say "$who :Actors: $actors"
		say "$who :plot: $plot"
		if [ "$ratingkey" != "" ]; then
			if [ "$ratingkey" != "null" ]; then
				say "$who :Plex: ${video_width}x${video_height}@${video_fps}fps($video_codec/${video_bit}kbps)"
				echo "debug: $ratingkey"
			fi
		fi
		;;
esac
