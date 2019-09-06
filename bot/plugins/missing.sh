#!/bin/bash - 

_script="missing.sh"  # name of this file. For log reasons.
source /drive/drive/.rtorrent/scripts/v3/bot/functions.sh # always call this lib
uac
regex="^[.]missing"

if [ -z "$channel" ]; then who="$channel"; fi # This will output to group chat.
# break up input into seperate values
input="${cmd#*.missing }"
imdbid="${input%% *}"
eps="${input#*$imdbid }"
season="${eps% *}"
episode="${eps#* }"
# First we check imdb if the show actually exists
JSON=$(curl -s "http://www.omdbapi.com/?i=$imdbid&apikey=$o_key&type=series")
title="$(echo "$JSON" |jq -r '.Title')"
if [ "$(echo "$JSON" |jq -r '.Response')" = "False" ]; then
	say "$who :Feil i imdb-id";exit
else
	if [ "$(echo "$JSON" |jq -r '.Type')" = "movie" ]; then
		say "$who :$title e en film. Du kan kun bruk missing på seria.";exit
	fi
fi
# so this seems to be a show/series, in this case we need to make sure the proper arguments are with us
if [ "$season" = "$imdbid" ]; then
	say "$who :Du må ha med sesong og episode som argument. f.eks: tt123456 2 4! $title sesong 2 episode 4"
	exit
fi

#We have 2 (actually 3) datapoins to check here. sql database will tell us if the episode is physically on the system, 
# while sickrage will check if the episode at some point has been downloaded. 

thetvdb_id="$(ttdb "$imdbid")"
json="$(curl -s "$sickrage/api/$s_key/?cmd=episode&indexerid=$thetvdb_id&season=$season&episode=$episode")"
echo "$json";exit
check=$(echo "$json" |jq -r '.result')
case "$check" in
	'success')
		episode_status=$(echo "$json" |jq -r '.data.status')
		episode_name=$(echo "$json" |jq -r '.data.name')

		case $episode_status in
			'Downloaded'|'Archived')
				say "$who :$show_title - \"$episode_name\" fins allerede i systemet, men endrer likevel status på episoden. Blir lagt til pånytt."
				curl -s "$sickrage/api/$s_key/?cmd=episode.setstatus&status=wanted&indexerid=$thetvdb_id&season=$season&episode=$episode&force=1"
				;;
			'Wanted')
				episode_search=$(curl -s  "$sickrage/api/$s_key/?cmd=episode.search&indexerid=$thetvdb_id&season=$season&episode=$episode")
				echo "$sickrage/api/$s_key/?cmd=episode.search&indexerid=$thetvdb_id&season=$season&episode=$episode"

				case "$(echo "$episode_search" |jq -r '.result')" in
					'success') say "$who :Fant episode! Blir lagt til Plex snarest!";;
					'failure') say "$who :Gjorde et søk, fant desverre ikke episoden innenfor de gitte kvalitetsparametre."; log s "$episode_search";exit;;
					'error') say "$who :Feil hos ekstern tjeneste, kunne ikke utføre søk.";exit;;
					*) log s "Genrell feilmelding fra sickrage: $episode_search";;
				esac ;;

			'Skipped'|'Ignored'|'Snatched')
				say "$who :Søker etter $show_title - \"$episode_name\" .."
				status_change=$(curl -s "$sickrage/api/$s_key/?cmd=episode.setstatus&status=wanted&indexerid=$thetvdb_id&season=$season&episode=$episode&force=1")

				case "$(echo "$status_change" |jq -r '.result')" in
					'failure') say "$who :Episoden mangler, men kan ikke endre status";exit;;
					'success') say "$who :Oops, episoden manglet. Den blir lagt til fortløpende.";exit;;
				esac ;;
		esac ;;

	'failure')
		say "$who :$title fins ikke på Plex. Request den først."
		;;
	'error')
		say "$who :Episode $episode av sesong $season fins ikke på $title. Du e out of bounds."
		exit;;

	esac


