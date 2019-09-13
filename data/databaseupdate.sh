#!/bin/bash
# where the fuck do i even put this
_script="databaseupdate.sh"
source /drive/drive/.rtorrent/scripts/v3/bot/functions.sh

#if [ "$(loginctl show-session "$(</proc/self/sessionid)" | sed -n '/^Service=/s/.*=//p')" != "crond" ]; then
#	echo "This is meant to be run by cron. This will likely take some time."
#	echo "It will also DELETE your content database before rebuilding it."
#	echo "It will also disable the bot while running."
#	echo -n "Use CTRL-C to escape or ENTER to continue..."
#	read jesusknowsyoursecrets
#fi

check_show_wishlist() {
	#this function will check if the the series wishlist has become available on thetvdb.
	for i in $(sql "SELECT imdbid from s_wishlist;"); do
		rating_key="$(ttdb "$i")"
		if [ "$rating_key" != " " ]; then
			echo "$i is still not available"
		else
			echo "$i has become available! -> ${rating_key}"
			who="$(sql SELECT who FROM s_wishlist WHERE imdbid = '$i');"
			channel="$who"
			cmd=".request $imdbid"
			load bot/core.sh
			request
		fi
	done
}

update_sqlite3() {
	exit
	bot_active="no" # This disables user input.
	grandparent_data="$(curl -s "$tt_hostname/api/v2?apikey=$tt_apikey&cmd=get_library_media_info&section_id=1&length=99999")"
	num_series="$(echo "$grandparent_data" | jq '.response.data.recordsTotal')"
	c=0 #shows
	while [ "$c" -le "$num_series" ]; do
		grandparent_rating_key="$(echo "$grandparent_data" | jq -r ".response.data.data[$c].rating_key")"
		if [ "$grandparent_rating_key" != "null" ]; then
			parent_data="$(curl -s "$tt_hostname/api/v2?apikey=$tt_apikey&cmd=get_library_media_info&rating_key=$grandparent_rating_key")"
			num_seasons="$(echo "$parent_data" | jq '.response.data.recordsTotal')"
			metadata="$(curl -s "$tt_hostname/api/v2?apikey=$tt_apikey&cmd=get_metadata&rating_key=$grandparent_rating_key")"
			name="$(echo "$metadata" | jq -r '.response.data.title' | sed "s/'//g")"
			imdbid="$(echo "$metadata" | jq -r '.response.data.guid')"
			imdbid=${imdbid##*//}
			imdbid=${imdbid%%\?*}
			imdbid="$(ttdb "$imdbid")"
			s=0 # seasons
			while [ "$s" -le "$num_seasons" ]; do
				parent_rating_key="$(echo "$parent_data" | jq -r ".response.data.data[$s].rating_key")"
				if [ "$parent_rating_key" != "null" ]; then
					episode_data="$(curl -s "$tt_hostname/api/v2?apikey=$tt_apikey&cmd=get_library_media_info&rating_key=$parent_rating_key")"
					num_episodes="$(echo "$episode_data" | jq -r '.response.data.recordsTotal')"
					e=0 # episodes
					while [ "$e" -le "$num_episodes" ]; do
						rating_key="$(echo "$episode_data" | jq -r ".response.data.data[$e].rating_key")"
						if [ "$rating_key" != "null" ]; then
							metadata="$(curl -s "$tt_hostname/api/v2?apikey=$tt_apikey&cmd=get_metadata&rating_key=$rating_key")"
							#echo "$metadata";exit
							file="$(echo "$metadata" | jq -r '.response.data.media_info[0].parts[0].file' | tr -d \')"
							name="$(echo "$metadata" | jq -r '.response.data.title' | sed s"/'//g")"
							season="$(echo "$metadata" | jq -r '.response.data.parent_media_index')"
							episode="$(echo "$metadata" | jq -r '.response.data.media_index')"
							show="$(echo "$metadata" | jq -r '.response.data.grandparent_title' | sed "s/'//g")"
							sql "INSERT INTO content (type, imdbid, grandparent_rating_key, rating_key, season, episode, filepath) VALUES ('show', '$imdbid', '$grandparent_rating_key', '$rating_key', '$season', '$episode', '$file')"
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

	# Movie

	JSON="$(curl -s "$tt_hostname/api/v2?apikey=$tt_apikey&cmd=get_library_media_info&section_id=2&length=999")"
	num="$(echo "$JSON" | jq -r '.response.data.recordsTotal')"
	echo "$num"
	COUNTER=0
	while [ "$COUNTER" -le "$num" ]; do
		rating_key="$(echo "$JSON" | jq -r ".response.data.data[$COUNTER].rating_key" 2>/dev/null)"
		metadata="$(curl -s "http://cr.wack:8181/api/v2?apikey=$tt_apikey&cmd=get_metadata&rating_key=$rating_key")"
		imdb="$(echo "$metadata" | jq -r ".response.data.guid" 2>/dev/null)"
		imdb_rating="$(echo "$metadata" | jq -r '.response.data.rating' 2>/dev/null)"
		imdb=${imdb##*//}
		imdb=${imdb%%\?*}
		file="$(echo "$metadata" | jq -r '.response.data.media_info[0].parts[0].file' | tr -d \')"
		if [ "$imdb_rating" != "null" ]; then # Entries without ratings are remnants of old content in the library
			file="$(echo "$metadata" | jq -r '.response.data.media_info[0].parts[0].file' | tr -d \' 2>/dev/null)"
			sql "INSERT INTO content (type, imdbid, rating_key, filepath) VALUES ('movie', '$imdb', '$rating_key', '$file')"
			echo "$show (${season}x${episode}) [${rating_key}]"
		fi
		let COUNTER=COUNTER+1

	done
	log n "database has been updated."
	bot_active="yes"
}

databaseupdate() {
	case "$db" in
	'sqlite3')
		update_sqlite3
		;;
	'mysql')
		update_mysql
		;;
	'oracle')
		update_oracle
		;;
	*)
		echo "$db is not a supported database. Please check your config"
		exit
		;;
	esac
}
