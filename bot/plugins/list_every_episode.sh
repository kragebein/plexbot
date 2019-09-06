#!/bin/bash - 
#===============================================================================
#
#          FILE: writetodb.sh
# 
#         USAGE: ./writetodb.sh 
# 
#   DESCRIPTION: Hent ut data fra alle tjenstan, sett inn i databasen.
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 03/18/2019 13:00
#      REVISION:  ---
#===============================================================================

#set -o nounset                              # Treat unset variables as an error
source /drive/drive/.rtorrent/scripts/v3/bot/functions.sh
grandparent_data="$(curl -s "$tt_hostname/api/v2?apikey=$tt_apikey&cmd=get_library_media_info&section_id=1&length=99999")"
num_series="$(echo "$grandparent_data" | jq '.response.data.recordsTotal')"
c=0	#shows
while [ "$c" -le "$num_series" ]; do
	grandparent_rating_key="$(echo "$grandparent_data" | jq -r ".response.data.data[$c].rating_key")"
	if [ "$grandparent_rating_key" != "null" ]; then
		parent_data="$(curl -s "$tt_hostname/api/v2?apikey=$tt_apikey&cmd=get_library_media_info&rating_key=$grandparent_rating_key")"
		num_seasons="$(echo "$parent_data" |jq '.response.data.recordsTotal')"
		metadata="$(curl -s "$tt_hostname/api/v2?apikey=$tt_apikey&cmd=get_metadata&rating_key=$grandparent_rating_key")"
		name="$(echo "$metadata" | jq -r '.response.data.title' | sed "s/'//g")"
		imdbid="$(echo "$metadata" |jq -r '.response.data.guid')"
		imdbid=${imdbid##*//};imdbid=${imdbid%%\?*}
		imdbid="$(/drive/drive/.rtorrent/scripts/ttdb.sh "$imdbid")"
		s=0	# seasons
		while [ "$s" -le "$num_seasons" ]; do
			parent_rating_key="$(echo "$parent_data" |jq -r ".response.data.data[$s].rating_key")"
			if [ "$parent_rating_key" != "null" ]; then
				episode_data="$(curl -s "$tt_hostname/api/v2?apikey=$tt_apikey&cmd=get_library_media_info&rating_key=$parent_rating_key")"
				num_episodes="$(echo "$episode_data" |jq -r '.response.data.recordsTotal')"	
				e=0	# episodes
				while [ "$e" -le "$num_episodes" ]; do
					rating_key="$(echo "$episode_data" | jq -r ".response.data.data[$e].rating_key")"
					if [ "$rating_key" != "null" ]; then
						metadata="$(curl -s "$tt_hostname/api/v2?apikey=$tt_apikey&cmd=get_metadata&rating_key=$rating_key")"
						#echo "$metadata";exit
						file="$(echo "$metadata" | jq -r '.response.data.media_info[0].parts[0].file' |tr -d \')"
						name="$(echo "$metadata" | jq -r '.response.data.title' |sed s"/'//g")"
						season="$(echo "$metadata" | jq -r '.response.data.parent_media_index')"
						episode="$(echo "$metadata" | jq -r '.response.data.media_index')"
						show="$(echo "$metadata" |jq -r '.response.data.grandparent_title' |sed "s/'//g")"
						sql3 "INSERT INTO content (type, imdbid, grandparent_rating_key, rating_key, season, episode, filepath) VALUES ('show', '$imdbid', '$grandparent_rating_key', '$rating_key', '$season', '$episode', '$file')"
						echo "$show (${season}x${episode}) [${rating_key}]"
					fi
					let e=e+1

				done
			fi
			let s=s+1

		done
	fi
	let c=c+1


done


