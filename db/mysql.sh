#!/bin/bash - 
#===============================================================================
#
#          FILE: db.sh
# 
#         USAGE: ./db.sh <arbitrary id>
#	  ABOUT: Sett opp array av resultat fra sql (db_data[tablename])
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 03/17/2019 03:33
#      REVISION:  ---
#===============================================================================

#set -o nounset                              # Treat unset variables as an error
source /drive/drive/.rtorrent/scripts/master.sh
_script="db.sh"
declare -A db_data
db_get_movie_data() {
	while IFS=$'\t' read -r -a _data; do
		for i in {0..4}; do
			db_data[${movie_data[$i]//,/}]="${_data[$i]}"
		done
		db_data[desc]="${!db_data[@]}"
	done < <(myq plexbot "select ${movie_data[@]} from pb_movies where id=$id;")
}

db_get_series_data() {
	while IFS=$'\t' read -r -a _data; do
		for i in {0..4}; do
			db_data[${series_data[$i]//,/}]="${_data[$i]}"
		done
	done < <(myq plexbot "select ${series_data[@]} from pb_series where id=$id;")
	db_get_episode_data

}

db_get_episode_data() {
	while IFS=$'\t' read -r -a _data; do
		for i in {3 4}; do
			ep_count[${pb_episodes[$i]//,/}]="${_data[$i]}"
		done
	done < <(myq plexbot "select count(season), count(episode) from pb_episodes where service_id=${db_data[service_id]};")
	if [[ "${#ep_count[episode]}" = "0" ]]; then
		log n "Empty show queried: ${db_data[name]}";exit # no need to continue if db doesnt have data on it.
	fi
	sc=0
	se=0
	query="$(myq plexbot "SELECT season, episode, episode_name, FROM pb_episodes WHERE service_id=${db_data[service_id]}")"

	while IFS=$'\t' read -r -a _data; do
		for i in $[!${_data[@]}]; do
			ep_data[${_data[$i]}]="${_data[@]}"
		done

	done
done < <(myq plexbot "SELECT season, episode, episode_name, FROM pb_episodes WHERE service_id=${db_data[service_id]};")

}

db_get_data() {
	while IFS=$'\t' read -r -a _data; do
		for i in {0..4}; do
			db_data[${pb_data[$i]//,/}]="${_data[$i]}"
		done
	done < <(myq plexbot "select ${pb_data[@]} from pb where plexid=$input OR service_id=$input OR imdbid=$input;")
	id="${db_data[id]}"
	case ${db_data[type]} in
		movie) db_get_movie_data ;;
		series)
			declare -A episodes
			declare -A seasons
			db_get_series_data;;
	esac

}
db_put_data() {
	: #
} 
write_movie_data() {
	: #
}
write_series_data() {
	: #
}
write_episode_data() {
	: #
}
input="48813"
db_get_data
for i in "${!db_data[@]}"; do echo "$i: ${db_data[$i]}"; done
