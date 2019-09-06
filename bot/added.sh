#!/bin/bash
export _script="addedtoplex.sh";
#source /drive/drive/.rtorrent/scripts/master.sh
source /drive/drive/.rtorrent/scripts/.plexbot.conf
source /drive/drive/.rtorrent/scripts/v3/bot/functions.sh

notify() {
	if [ "$otitle" != "null" ]; then
		if [ "$title" = "$otitle" ]; then 
			for i in $( myq "plexbot SELECT who FROM notify WHERE imdbid='$imdbid';"); do
				if [ "$genre" = "tv" ]; then
					say "$i :Hei, ny episode av $title (${season}x${episode}) e tilgjengelig på plex no"
				else
					say "$i :Hei, $title e tilgjengelig på plex no"
				fi
			done
		fi
	fi
}

to_db() {
	imdbid="$imdb"
	rating_key="$key"
	case "$db" in
		'sqlite3')
		query="$(sql3 "SELECT rating_key FROM content WHERE rating_key='$rating_key'")"
			if [ "$query" != "$rating_key" ]; then
				#Insert into database.
				case "$genre" in
				'movie')
				sql3 "INSERT INTO content (type, imdbid, rating_key, filepath) VALUES ('movie', '$imdbid', '$rating_key', '$path')";;
				'tv')
				sql3 "INSERT INTO content (type, imdbid, grandparent_rating_key, rating_key, season, episode, filepath) VALUES ('show', '$imdbid', '$grandparent_rating_key', '$rating_key', '$season', '$episode', '$file')";;
				esac
			fi ;;
		'oracle')
			# oracle will figure out where in the database this goes, no need to do anything else with the data.
			payload() { # 
				oracle_login 
				payload="$(cat ../q/addedtoplex.sql)"
				payload="${payload/\%showname\%/$title}"
				payload="${payload/\%imdbid\%/$imdbid}"
				payload="${payload/\%grandparent_key\%/$grandparent_key}"
				payload="${payload/\%rating_key\%/$key}"
				payload="${payload/\%episode_name\%/${episode_name/\'/}}"
				payload="${payload/\%season\%/$season}"
				payload="${payload/\%episode\%/$episode}"
				payload="${payload/\%request\%/$request}"
				payload="${payload/\%status\%/added}"
				payload="${payload/\%path\%/$path}"
				payload="${payload/\%type\%/$showtype}"
				echo "$payload"
			}
			payload | sqlplus -S /NOLOG ;;
		'mysql')
			:
			# TODO
			;;
	esac

}

numbermagic() {
	xtitle="$(echo "$title" | xxd -plain | tr -d '\n' | sed 's/\(..\)/%\1/g')"
	if [ "$genre" = "tv" ]; then
		parent_key="$(echo "$JSON_ORIG" |jq -r '.response.data.grandparent_rating_key')"
		rel_year="$(curl -s "$tt_hostname/api/v2?apikey=$tt_apikey&cmd=get_metadata&rating_key=$parent_key" |jq -r '.response.data.year')"
	fi
	json="$(curl -s "http://www.omdbapi.com/?t=$xtitle&y=$rel_year&apikey=$omdb_key")"
	otitle="$(echo "$json" |jq -r '.Title')"
	imdbid="$(echo "$json" |jq -r '.imdbID')"
	export imdbid=$imdbid

	if [ "$section" = "TV Shows" ]; then
		if [ "$rating" = "" ]; then #Plex så ikke ut tell å ha data på episode, prøv med top level rating key istedet
			JSON_GP="$(curl -s "$tt_hostname/api/v2?apikey=$tt_apikey&cmd=get_metadata&rating_key=$(echo "$JSON_ORIG" -r |jq '.response.data.grandparent_rating_key')")"
			rating="$(echo "$JSON_GP" |jq '.response.data.rating' | sed 's/"//g')"
		fi
	fi
	if ! [[ "$rating" =~ ^[0-9](\.)[0-9] ]]; then # Om plex ikke har, rating, prøv imdb istedetfor. 
		season_data="$(curl -s "https://www.omdbapi.com/?i=$imdbid&Season=$season&apikey=$omdb_key")"
		rating="$(echo "$season_data" |jq -r ".Episodes[$episode].imdbRating")" # rating
		released="$(echo "$season_data" | jq -r ".Episodes[$episode].Released")" # release
	fi
	if ! [[ "$rating" =~ ^[0-9](\.)[0-9] ]]; then 
		rating="0.0*" #førr tidlig tell å få rating på episoden.
	fi


	year="$(echo "$release" |awk -F "-" '{print $1}')"
	month="$(echo "$release" |awk -F "-" '{print $2}')"
	day="$(echo "$release" |awk -F "-" '{print $3}')"
	released="$day/$month/$year"
	if [ "$released" = "//" ]; then
		day="$(date +%d)";month="$(date +%m)";year="$(date +%Y)";
		released="$day/$month/$year*"
	fi

}


tvshows() {
	genre="tv"
	episode="$(echo "$JSON_ORIG" |jq '.response.data.media_index' |sed 's/"//g' |sed 's/^1$/01/g' |sed 's/^2$/02/g' |sed 's/^3$/03/g' |sed 's/^4$/04/g' |sed 's/^5$/05/g' |sed 's/^6$/06/g' |sed 's/^7$/07/g' |sed 's/^8$/08/g' |sed 's/^9$/09/g' | sed 's/^0$/00/g' )"
	season="$(echo "$JSON_ORIG" | jq '.response.data.parent_media_index' |sed 's/"//g')"
	grandparent_key="$(echo "$JSON_ORIG" |jq -r '.response.data.grandparent_rating_key')"
	title="$(echo "$JSON_ORIG" |  jq '.response.data.grandparent_title' |sed 's/"//g' |sed -E 's/(\((19|20)[[:digit:]]{2}\))$//g')"
	rating="$(echo "$JSON_ORIG" | jq '.response.data.rating' | sed 's/"//g')"
	release="$(echo "$JSON_ORIG" |jq '.response.data.originally_available_at' |sed 's/"//g')"
	rel_year="$(echo "$JSON_ORIG" |jq -r '.response.data.year' |sed 's/"//g')"
	numbermagic 
	response="S: $title ${season}x${episode} ($released) [$rating/10.0]"
	path="$(echo "$JSON_ORIG" | jq -r '.response.data.media_info[0].parts[0].file')"
	if [ "$announce_new" = "yes" ]; then
		say "$RES :$response"
		notify
	fi
	log n "$response"


}

movies() {
	genre="movie"
	title="$(echo "$JSON_ORIG" |  jq '.response.data.title' |sed 's/"//g' |sed -E 's/(\((19|20)[[:digit:]]{2}\))$//g' | sed 's/  //g')"
	release="$(echo "$JSON_ORIG" |jq '.response.data.originally_available_at' |sed 's/"//g')"
	rating="$(echo "$JSON_ORIG" | jq '.response.data.rating' | sed 's/"//g')"
	rel_year="$(echo "$JSON_ORIG" |jq -r '.response.data.year' |sed 's/"//g')"
	path="$(echo "$JSON_ORIG" |jq -r '.response.data.media_info[0].parts[0].file')"
	imdb="$(echo "$JSON_ORIG" |jq -r ".response.data.guid" 2>/dev/null)"
	imdb=${imdb##*//};imdb=${imdb%%\?*}
	if [ "$rating" = "" ]; then # bedre med ratings fra imdb sjøl.
		get_imdbid="$(echo "$JSON_ORIG" | jq '.response.data.guid' | awk -F "//" '{print $2}' |awk -F "?" '{print $1}')"
		rating="$(curl -s "http://www.omdbapi.com/?i=$get_imdbid&apikey=$omdb_key" |jq -r '.Ratings[0].Value')"
	fi
	numbermagic
	to_db
	if [ "$norsk" = "yes" ]; then
		C="F: (Norsk"
	else
		C="F:"
	fi
	response="$C $title ($released) [$rating/10.0]"

	if [ "$announce_new" = "yes" ]; then
		say "$RES :$response"
		notify

	fi
	log n "$response"


}
events() {
	:
}
music() { 
	: 
}

export key="$1"
JSON_ORIG="$(curl -s "$tt_hostname/api/v2?apikey=$tt_apikey&cmd=get_metadata&rating_key=$key")"
section="$(echo "$JSON_ORIG" |jq '.response.data.library_name' |sed 's/"//g')"


case $section in
	'Series') tvshows;exit 0;;
	'Films') movies;exit 0;;
	'Events') events;exit 0;;
	'Music') music;exit 0;;
	'Norsk') norsk=yes; movies;exit 0;;
	'Dolby/Lyd test') :;exit 0;;
	'Movies (4K)') :;exit 0;;
	'Julekalendere') tvshows;exit0;;
	*) log e "Section $section is missing, unable to process. ($key)";exit 0

	esac	


