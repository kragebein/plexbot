#!/bin/bash
_script="added.sh"
source /drive/drive/.rtorrent/scripts/master.sh
source /drive/drive/.rtorrent/scripts/.plexbot.conf
payload() {

	oracle_login
	payload="$(cat ../q/addedtoplex.sql)"
	payload="${payload/\%showname\%/$title}"
	payload="${payload/\%imdbid\%/$imdbid}"
	payload="${payload/\%grandparent_key\%/$grandparent_key}"
	payload="${payload/\%rating_key\%/$key}"
	payload="${payload/\%episode_name\%/${episode_name/\'/}}"
	payload="${payload/\%season\%/$season}"
	payload="${payload/\%episode\%/$episode}"
	request="$(myq "plexbot SELECT who FROM notify WHERE imdbid="$imdbid" LIMIT 1;" 2>/dev/null)"
	if [ -z $request ]; then request="SYSTEM"; fi
	payload="${payload/\%request\%/$request}"
	payload="${payload/\%status\%/added}"
	payload="${payload/\%path\%/$filepath}"
	payload="${payload/\%type\%/$showtype}"
	echo "$payload"
}
i_o () {
	payload | sqlplus -S /NOLOG	
}
notify() {
	if [ "$otitle" != "null" ]; then
		if [ "$title" = "$otitle" ]; then 
			for i in $( myq "plexbot SELECT who FROM notify WHERE imdbid = '$imdbid';"); do
				if [ "$genre" = "tv" ]; then
					say "$i :Hei, ny episode av $title (${season}x${episode}) e tilgjengelig på plex no"
				else
					say "$i :Hei, $title e tilgjengelig på plex no"
				fi
			done
		fi
	fi
	echo "$imdbid" > /tmp/.lastadd
}



numbermagic() {
	xtitle="$(echo "$title" | xxd -plain | tr -d '\n' | sed 's/\(..\)/%\1/g')"
	if [ "$genre" = "tv" ]; then
		parent_key="$(echo "$JSON_ORIG" |jq -r '.response.data.grandparent_rating_key')"
		rel_year="$(curl -s "$plexpy/api/v2?apikey=$c_api&cmd=get_metadata&rating_key=$parent_key" |jq -r '.response.data.year')"
	fi
	json="$(curl -s "http://www.omdbapi.com/?t=$xtitle&y=$rel_year&apikey=$o_key")"
	otitle="$(echo "$json" |jq -r '.Title')"
	imdbid="$(echo "$json" |jq -r '.imdbID')"

	if [ "$section" = "TV Shows" ]; then
		if [ "$rating" = "" ]; then #Try grandparent key
			JSON_GP="$(curl -s "$plexpy/api/v2?apikey=$c_api&cmd=get_metadata&rating_key=$(echo "$JSON_ORIG" -r |jq '.response.data.grandparent_rating_key')")"
			rating="$(echo "$JSON_GP" |jq '.response.data.rating' | sed 's/"//g')"
		fi
	fi

	if ! [[ "$rating" =~ ^[0-9](\.)[0-9] ]]; then # Plex agent failure, agent needs reset. Get episode rating from imdb instead
		log n "addedtoplex klart ikke hent rating tell $title/${season}x${episode}"
		season_data="$(curl -s "https://www.omdbapi.com/?i=$imdbid&Season=$season&apikey=$o_key")"
		rating="$(echo "$season_data" |jq -r ".Episodes[$episode].imdbRating")" # rating
		released="$(echo "$season_data" | jq -r ".Episodes[$episode].Released")" # release
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
	showtype="series"
	episode="$(echo "$JSON_ORIG" |jq -r '.response.data.media_index' |sed 's/"//g' |sed 's/^1$/01/g' |sed 's/^2$/02/g' |sed 's/^3$/03/g' |sed 's/^4$/04/g' |sed 's/^5$/05/g' |sed 's/^6$/06/g' |sed 's/^7$/07/g' |sed 's/^8$/08/g' |sed 's/^9$/09/g' | sed 's/^0$/00/g' )"
	season="$(echo "$JSON_ORIG" |jq -r '.response.data.parent_media_index' |sed 's/"//g')"
	grandparent_key="$(echo "$JSON_ORIG" |jq -r '.response.data.grandparent_rating_key')"
	title="$(echo "$JSON_ORIG" |jq '.response.data.grandparent_title' |sed 's/"//g' |sed -E 's/(\((19|20)[[:digit:]]{2}\))$//g')"
	episode_name="$(echo "$JSON_ORIG" |jq -r '.response.data.title')"
	rating="$(echo "$JSON_ORIG" |jq -r '.response.data.rating' | sed 's/"//g')"
	release="$(echo "$JSON_ORIG" |jq -r '.response.data.originally_available_at' |sed 's/"//g')"
	rel_year="$(echo "$JSON_ORIG" |jq -r '.response.data.year' |sed 's/"//g')"
	filepath="$(echo "$JSON_ORIG" | jq -r '.response.data.media_info[0].parts[0].file')"
	numbermagic 
	response="S: $title ${season}x${episode} ($released) [$rating/10.0]"
	i_o
	if [ "$announce_new" = "yes" ]; then
		#		say "$RES :$response"
		notify
	fi
	log n "$response"


}

movies() {
	genre="movie"
	showtype="movie"
	title="$(echo "$JSON_ORIG" |  jq '.response.data.title' |sed 's/"//g' |sed -E 's/(\((19|20)[[:digit:]]{2}\))$//g' | sed 's/  //g')"
	release="$(echo "$JSON_ORIG" |jq '.response.data.originally_available_at' |sed 's/"//g')"
	rating="$(echo "$JSON_ORIG" | jq '.response.data.rating' | sed 's/"//g')"
	rel_year="$(echo "$JSON_ORIG" |jq -r '.response.data.year' |sed 's/"//g')"
	filepath="$(echo "$JSON_ORIG" |jq -r '.response.data.media_info[0].parts[0].file')"
	if [ "$rating" = "" ]; then # bedre med ratings fra imdb sjøl.
		get_imdbid="$(echo "$JSON_ORIG" | jq '.response.data.guid' | awk -F "//" '{print $2}' |awk -F "?" '{print $1}')"
		rating="$(curl -s "http://www.omdbapi.com/?i=$get_imdbid&apikey=$o_key" |jq -r '.Ratings[0].Value')"
	fi
	numbermagic
	if [ "$norsk" = "yes" ]; then
		C="F: (Norsk"
	else
		C="F:"
	fi
	response="$C $title ($released) [$rating/10.0]"
	i_o
	if [ "$announce_new" = "yes" ]; then
		#		say "$RES :$response"
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

key="$1"
JSON_ORIG="$(curl -s "$plexpy/api/v2?apikey=$c_api&cmd=get_metadata&rating_key=$key")"
section="$(echo "$JSON_ORIG" |jq '.response.data.library_name' |sed 's/"//g')"
if [ "$2" = "-r" ]; then
	echo "$JSON_ORIG"
	exit
fi

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


