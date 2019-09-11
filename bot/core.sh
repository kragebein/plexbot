#!/bin/bash - 
#===============================================================================
#
#          FILE: core.sh
# 
#         USAGE: ./core.sh 
# 
#   DESCRIPTION: This file wil make Plex, Sickrage/Medusa, Couchpotao, thetvdb and imdb talk together to create a system
# 		 that allows you to easly add movies and shows to your existing Plex Library.
#       OPTIONS: 
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 04/30/2019 20:13
#      REVISION:  ---
#===============================================================================
_script="core.sh"
setflags() {
	imdbid="$(echo "$cmd" | egrep -wo "tt[0-9]{1,19}")"
	language="$(echo "$cmd" | egrep -wo "\s?[-l}] \w{2}")"
	#anime="$()
}
accepted_lang(){
	var="$(grep -w "${language^^}" "$pb/../lang/cc.csv" | awk -F ',' '{print $2}')"
	if [ "$var" = "${language^^}" ]; then
		linglang="$(grep -W "${language^^}" "$pb/../cc.csv" | awk -F ',' '{print $1}')"
		return 0
	else
		return 1
	fi
}
check_request_flags(){
	case "${language% *}" in 
		l) 
			language="${language##* }"
			if ! accepted_lang; then
				say "$who : $language e ikke et gyldig språkvalg. Prøv f.eks no, jp, dk, se osv"
				exit
			fi
			core_lang="$language"

		esac  
	}
	check_input(){
		if [[ "$cmd" =~ ^[0-9]{1,3}(.*)$ ]]; then
			imdbid="$(grep -w "$cmd" /tmp/.sbuf |awk -F ' ' '{print $2}')";
			put.last
		else
			put.last
		fi
	}
	missing_episode() {
		input=$(echo -ne "$*" | awk -F ".missing" '{print $2}' | awk -F ' ' '{print $1}')
		season=$(echo -ne "$*" | awk -F ".missing" '{print $2}' | awk -F ' ' '{print $2}')
		episode=$(echo -ne "$*" | awk -F ".missing" '{print $2}' | awk -F ' ' '{print $3}')
		JSON=$(curl -s "http://www.omdbapi.com/?i=$input&apikey=$omdb_key&type=series")
		response=$(echo "$JSON" |jq -r '.Response')
		Type=$(echo "$JSON" |jq -r '.Type')
		Name=$(echo "$JSON" |jq -r '.Title')
		if [ "$response" = "False" ]; then
			say "$who :Feil i imdb-id";echo "$JSON" > /tmp/.debugmissing;exit
		else
			if [ "$Type" = "movie" ]; then
				say "$who :$Name e en film ditt nepskrell!";exit
			fi
		fi
		title=$(echo "$JSON" |jq -r '.Title')
		nope=0
		imdbid=$(echo "$JSON" |jq -r ".imdbID" 2>/dev/null)
		show_title=$(echo "$JSON" |jq -r ".Title" 2>/dev/null)
		thetvdb_id=$(ttdb "$imdbid")
		if [ "$thetvdb_id" = "" ]; then
			say "$who :thetvdb api nede?";exit
		fi
		sanity=$(curl -s "$sr_hostname/api/$sr_apikey/?cmd=episode&indexerid=$thetvdb_id&season=$season&episode=$episode")
		check=$(echo "$sanity" |jq -r '.result')
		case $check in
			'success')
				episode_status=$(echo "$sanity" |jq -r '.data.status')
				episode_name=$(echo "$sanity" |jq -r '.data.name')
				case $episode_status in
					'Downloaded') say "$who :$show_title - \"$episode_name\" fins allerede i systemet, men endrer likevel status på episoden. Blir lagt til pånytt.";exit;
						curl -s "$sr_hostname/api/$sr_apikey/?cmd=episode.setstatus&status=wanted&indexerid=$thetvdb_id&season=$season&episode=$episode";;
					'Wanted')
						echo "Søker etter $show_title - \"$episode_name\" .."
						episode_search=$(curl -s  "$sr_hostname/api/$sr_apikey/?cmd=episode.search&indexerid=$thetvdb_id&season=$season&episode=$episode")
						result=$(echo "$episode_search" |jq -r '.result')
						case $result in
							'success') say "$who :Fant episode! Blir lagt til Plex snarest!";;
							'failure') say "$who :Gjorde et søk, fant desverre ikke episoden innenfor de gitte kvalitetsparametre.";exit;;
							'error') say "$who :Feil hos ekstern tjeneste, kunne ikke utføre søk.";exit;;
							*)	say "$who :Feil; missing_episode, sanity_check->episode_status->wanted->result";say "$who :$episode_search";exit;;
						esac;;
					'Skipped'|'Ignored'|'Snatched')
						say "$who :Søker etter $show_title - \"$episode_name\" .."
						status_change=$(curl -s "$sr_hostname/api/$sr_apikey/?cmd=episode.setstatus&status=wanted&indexerid=$thetvdb_id&season=$season&episode=$episode");
						result=$(echo "$status_change" |jq -r '.result')
						case $result in
							'failure') message=$(echo "$status_change" |jq -r '.message'); say "$who :Episoden mangler, men kan ikke endre status: $message";exit;;
							'success') say "$who :Oops, episoden manglet. Den blir lagt til fortløpende.";exit;;
							*) say "$who :Feil; missing_episode, sanity_check->episode_status->skipped->result;"; say "$who :$status_change";exit;;
						esac;;
				esac;;
			'failure') say "$who :Serien fins ikke på Plex, request den først!";exit;;
			'error') say "$who :S${season}x${episode} fins ikke på $title";exit;;
			*) say "$who :Feil, missing_episode, sanity_check;";say "$who :$sanity";exit;;
		esac
	}
	imdb_look() {
		rm /tmp/.sbuf 2>/dev/null
		buffer=$(mktemp)
		arg="$(echo "$cmd" |awk -F ".search " '{print $2}')"
		argw="$(echo -ne "$arg" | xxd -plain | tr -d '\n' | sed 's/\(..\)/%\1/g')"
		COUNTER=0
		MULTICOUNT="0"
		JSON="$(curl -s "$cp_hostname/api/$cp_apikey/search?q=$argw")"
		echo "$JSON" >/drive/drive/.rtorrent/logs/json.log 2>/dev/null
		hits="$(echo "$JSON" |grep -o "original_title" -c)"
		say "$who :Filmer"
		say "$who :-------------"
		if [ "$hits" = "0" ]; then say "$who :Ingen treff på $arg";else :;fi
		if [ "$hits" = "1" ]; then calc="1";else calc=$(echo "$hits -1" |bc);fi
		while [ "$COUNTER" -lt "$calc" ]; do
			title="$(echo "$JSON" |jq ".movies[$COUNTER].original_title" 2>/dev/null)"
			imdb="$(echo "$JSON" |jq ".movies[$COUNTER].imdb" 2>/dev/null|sed 's/"//g')"
			year="$(echo "$JSON" |jq ".movies[$COUNTER].year" 2>/dev/null|sed 's/"//g')"
			rating="$(echo "$JSON" |jq ".movies[$COUNTER].rating.imdb[0]" 2>/dev/null)"
			wanted="$(echo "$JSON" |jq ".movies[$COUNTER].in_wanted.status" 2>/dev/null |sed 's/"//g')"
			library="$(echo "$JSON" | jq ".movies[$COUNTER].in_library.status" 2>/dev/null | sed 's/"//g')"
			case $rating in
				'') rating="0.0";;
				' ') rating="0.0";;
				'null') rating="0.0";;
			esac
			if [ "$year" = "null" ]; then
				:
			else
				if [ "$wanted" = "active" ]; then
					what="Ligg i ventelista."
					what2="I kø"
				elif [ "$library" = "done" ]; then
					what="fins allerede i Plex"
					what2="✔️$imdb"
				else
					what="fins ikke i biblioteket, bruk .request $imdb"
					what2="➕$imdb"
				fi
				if [ "$what2" = "null" ]; then
					:
				else
					say "$who :$MULTICOUNT. $what2 - $title ($year)[$rating/10.0]"
					say "$who : "
					echo "$MULTICOUNT $imdb" >> "$buffer"
				fi
			fi
			let COUNTER=COUNTER+1
			let MULTICOUNT=MULTICOUNT+1
		done
		say "$who :TV-serier"
		say "$who :-------------"
		input="$(echo -ne "$arg" | xxd -plain | tr -d '\n' | sed 's/\(..\)/%\1/g')"
		JSON=$(curl -s "http://www.omdbapi.com/?s=$input&apikey=$omdb_key&type=series")
		count=$(echo "$JSON" |jq '.Search' |grep "{" -c)
		COUNTER=0
		if [ "$count" = "0" ]; then
			say "$who :Fant ingenting på \"$arg\""
		fi
		while [ "$COUNTER" -lt "$count" ]; do
			nope=0
			title=$(echo "$JSON" |jq -r ".Search[$COUNTER].Title" 2>/dev/null)
			year=$(echo "$JSON" |jq -r ".Search[$COUNTER].Year" 2>/dev/null)
			imdbid=$(echo "$JSON" |jq -r ".Search[$COUNTER].imdbID" 2>/dev/null)
			thetvdb_id="$(ttdb "$imdbid")"
			sanity=$(curl -s "$sr_hostname/api/$sr_apikey/?cmd=show.cache&tvdbid=$thetvdb_id")
			check=$(echo "$sanity" |jq -r '.result' 2>/dev/null)
			case $check in
				'success') status="✔️$imdbid";;
				'failure') status="➕$imdbid";;
				'error') status="🚫$imdbid";;
			esac
			rating=$(curl -s "http://www.omdbapi.com/?i=$imdbid&apikey=$omdb_key&type=series" |jq -r '.imdbRating' 2>/dev/null)
			case $rating in
				'') rating="0.0";;
				' ') rating="0.0";;
				'null') rating="0.0";;
			esac
			if [ "$nope" = "0" ]; then
				say "$who :$MULTICOUNT. $status - $title ($year)[$rating/10.0]"
				say "$who : "
				echo "$MULTICOUNT $imdbid" >> "$buffer"
			else
				:
			fi
			let COUNTER=COUNTER+1
			let MULTICOUNT=MULTICOUNT+1
		done
		mv "$buffer" /tmp/.sbuf
		exit
	}
	show_get_pluss() {
		#Finn ut av ønsket kvalitet, språk og status. 
		:
	}
	show_get_id() {
		thetvdb_id="$(ttdb "$imdbid")"
		#echo "$imdbid"
		#echo "$(curl -s "http://thetvdb.com/index.php?seriesname=&fieldlocation=4&language=7&genre=&year=&network=&zap2it_id=&tvcom_id=&imdb_id=$imdbid&order=translation&addedBy=&searching=Search&tab=advancedsearch")"
		case $thetvdb_id in
			'') say "$who :$imdb_title finnes på imdb ($imdbid), men den her serien fins ikke på thetvdb enda og kan dæffør ikke lægges tell.";exit;;
			' ')say "$who :$imdb_title finnes på imdb ($imdbid), men den her serien fins ikke på thetvdb enda og kan dæffør ikke lægges tell.";exit;;
			*):;;
		esac
	}
	show_check_exist_fail() {
		sanity=$(curl -s "$sr_hostname/api/$sr_apikey/?cmd=show.cache&tvdbid=$(ttdb $imdbid)")
		check=$(echo "$sanity" |jq -r '.result')
		case $check in
			'failure') :;;
			'success') say "$who :Serien \"$imdb_title\" ligg allerede i Plex";exit;;
			*) say "$who : Feil; blank/tom respons fra ekstern server, prøv igjen."; say "$who :$sanity";exit 1;;
		esac
	}
	show_check_exist() {
		sanity=$(curl -s "$sr_hostname/api/$sr_apikey/?cmd=show.cache&tvdbid=$thetvdb_id")
		check=$(echo "$sanity" |jq -r '.result')
		case $check in
			'failure') :;;
			'success') say "$who :Serien $imdb_title ligg allerede i Plex";exit;;
			*) sleep 1s;show_check_exist_fail;;
		esac
	}
	show_add() {
		stage_area="/drive/drive/Series"
		n="$imdb_title"
		n2=$(printf "%s" "$n" | awk -F " " '{print $1}')
		if [ "$n2" = "The " ]; then
			n3=$(printf "%s" "$n" | awk -F 'The ' '{print $2}')
			n="$n3";
		fi
		f=$(printf "%s" "$n" | cut -c 1 | awk '{print toupper($0)}')
		r='^[0-9]+$'
		if  [[ $f =~ $r ]] ; then
			f="0-9"
		fi
		if [ -z "$core_lang" ]; then
			core_lang="en"
		fi
		indexerid="$thetvdb_id"
		status="wanted"
		future_status="wanted"
		season_folder="1"
		anime="0" 
		quality_check=$(curl -s "http://www.omdbapi.com/?i=$imdbid&apikey=$omdb_key&type=series" |jq -r '.Year')
		start_year=$(echo "$quality_check" |awk -F "–" '{print $1}')
		if [ "$start_year" = "null" ]; then # we always want High def
			#initial="sdtv|sddvd|hdtv|hdwebdl|hdbluray"
			initial="hdtv|fullhdtv|hdwebdl|fullhdwebdl|hdbluray|fullhdbluray"
		else
			if [ "$start_year" -le "2006" ]; then
				initial="sdtv|sddvd|hdtv|hdwebdl|hdbluray" # Low Def..
			else
				initial="hdtv|fullhdtv|hdwebdl|fullhdwebdl|hdbluray|fullhdbluray" #High Definition
			fi
		fi
		location="$stage_area/$f/"
		execute_add=$(curl -s "$sr_hostname/api/$sr_apikey/?cmd=show.addnew&indexerid=$indexerid&status=$status&future_status=$future_status&season_folders=$season_folder&initial=${initial}&anime=$anime&location=$location&lang=$core_lang")
		execute_add_error=$(echo "$execute_add" |jq -r '.result')
		case $execute_add_error in
			'success')
				if [ ! "$who" = "$channel" ]; then	
					say "$announce_channel :Serien \"$imdb_title\" ($imdbid) er blitt lagt til [lang:$core_lang]. Vil komme på plex fortløpende"
				fi
				say "$who :Serien \"$imdb_title\" ($imdbid) vart lagt tell [lang:$core_lang]. Kommer på plex asap.";;
			'failure') say "$who :Serien \"$imdb_title\" vart ikke lagt tell. Se feillogg." echo "";echo "$execute_add";;
			*) say "$who :Feil; show_add, execute_add->error";echo "$execute_add";;
		esac
		exit
	}
	tv_search() {
		argw="$(echo "$*" |awk -F ".tvsearch " '{print $2}')"
		input="$(echo -ne "$argw" | xxd -plain | tr -d '\n' | sed 's/\(..\)/%\1/g')"
		JSON=$(curl -s "http://www.omdbapi.com/?s=$input&apikey=$omdb_key&type=series")
		count=$(echo "$JSON" |jq '.Search' |grep "{" -c)
		COUNTER=0
		if [ "$count" = "0" ]; then
			say "$who :Fant ingenteng på \"$argw\"";exit
		else
			:
		fi
		while [ "$COUNTER" -lt "$count" ]; do
			nope=0
			title=$(echo "$JSON" |jq -r ".Search[$COUNTER].Title" 2>/dev/null)
			year=$(echo "$JSON" |jq -r ".Search[$COUNTER].Year" 2>/dev/null)
			imdbid=$(echo "$JSON" |jq -r ".Search[$COUNTER].imdbID" 2>/dev/null)
			thetvdb_id=$(ttdb "$imdbid")
			sanity=$(curl -s "$sr_hostname/api/$sr_apikey/?cmd=show.cache&tvdbid=$thetvdb_id")
			check=$(echo "$sanity" |jq -r '.result')
			case $check in
				'success') status="I plex";;
				'failure') status="$imdbid";;
				'error') say "$who :$imdbid - $title ($year) [$rating/10.0]";say "$who :Fins ikke på thetvdb👆";exit;;
			esac
			rating=$(curl -s "http://www.omdbapi.com/?i=$imdbid&apikey=$omdb_key&type=series" |jq -r '.imdbRating') 
			if [ "$nope" = "0" ]; then
				say "$who :$status - $title ($year)[$rating/10.0]"
				say "$who : "
			fi
			let COUNTER=COUNTER+1
		done
		exit
	}
	show_initiate() {
		show_get_id
		show_check_exist "$thetvdb_id"
		show_add "$lang" "$thetvdb_id"
		exit
	}
	parse_imdb() {
		xml="$(curl -s "http://www.omdbapi.com/?i=$imdbid&plot=short&r=json&apikey=$omdb_key")"
		if [ "$(echo "$xml")" = "The service is unavailable." ]; then echo "IMDB-api ser ute tell å vær nede, kan ikke gjør nåkka uten det!"; exit 0; fi
		respons="$(echo "$xml" |awk -F "Response\":" '{print $2}'|awk -F "\"" '{print $2}')"
		if [ "$respons" = "True" ]; then :;else say "$who :Ingen film eller serie med den IDen: $imdbid";exit 1;fi
		imdb_title=$(echo "$xml" |awk -F "Title\":" '{print $2}' |awk -F "\"" '{print $2}' 2>/dev/null)
		couch_title="$(html_ascii "$imdb_title")" # Lets make it searchable through urls 
		typ="$(echo "$xml" |awk -F "\"Type\":" '{print $2}' |awk -F "\"" '{print $2}')"
		if [ "$typ" = "series" ]; then show_initiate "$imdbid";exit;
		elif [ "$typ" = "movie" ]; then :;else say "$who :$imdb_title e ikke en film eller serie.";exit 0
		fi
	}
	check_exist() {
		#say "$who :Film requests ute av drift for øyeblikket";exit
		exists="$(curl -s "$cp_hostname/api/$cp_apikey/media.get/?id=$imdbid")"
		check=$(echo "$exists" |awk -F '{\"status\": ' '{print $2}' |awk -F "\"" '{print $2}')
		case $check in
			'active')
				say "$who :$imdb_title ($imdbid) ligger allerede i ventelista, men filmen har ikke hadd første visning enda, det bi først gjort et forsøk på å lægg den tell etter første visning.";exit 0;;
			'done')
				say "$who :$imdb_title ($imdbid) e allerede på Plex.";exit 0;;
			'false')
				:;;
		esac
	}
	parse_sofa() {
		check_exist
		year=$(curl -s curl -s "http://www.omdbapi.com/?i=$imdbid&plot=short&r=json&apikey=$omdb_key" |jq -r '.Year')
		initial="32be391d247b4af2acab4fce07bd7c02" # set default
		if [ "$year" -le "2006" ]; then
			initial="32be391d247b4af2acab4fce07bd7c02" #HD
		elif [ "$year" -le "2002" ]; then
			initial="7634dd8abcf14a5a90eef7ad1aba098d" #SD
		fi
		xml="$(curl -s "$cp_hostname/api/$cp_apikey/movie.add/?force_readd=false&title=$couch_title&identifier=$imdbid&profile_id=$initial")"
		response="$(echo $xml |awk -F "\"success\": " '{print $2}' |awk -F '}' '{print $1}')"
		if [ "$response" = "true" ]; then :;else say "$who :Kunne ikke parse JSON, se debuglog.\n$xml";echo -e "$xml\n$imdbid\n$couch_title" > logs/updater.logdgb;exit 1; fi
		status="$(echo $xml |awk -F '{\"status\": ' '{print $2}' |awk -F "\"" '{print $2}')"
		case $status in
			'done')
				say "$who :Filmen \"$imdb_title\" fins allerede i Plex";exit 1;;
			'active')
				sleep 10s;cp_status="$(cat "/tmp/webhook_$imdbid" |grep "Snatched" |awk -F ".ø. " '{print $2}')"
				if [ "$cp_status" = "$imdbid" ]; then
					say "$who :Filmen $imdb_title ($imdbid) ble funnet, henter ned.."
				else
					say "$who :Filmen $imdb_title ($imdbid) er lagt i ønskelista."
					if [ ! "$who" = "$channel" ]; then
						say "$announce_channel :Filmen $imdb_title ($imdbid) e lagt i ønskelisten."
					fi

					rm "/tmp/cp_status_$imdbid" 2>/dev/null
					echo "$imdbid" > "/tmp/.request.$imdbid"
				fi;;
			*)
				:
		esac
	}
	wishlist(){
		json=$(curl -s "$cp_hostname/api/$cp_apikey/media.list/?status=active")
		TOT=$(echo "$json" |jq -r '.total')
		CNT=0
		buffer="$(mktemp)"
		say "$who :Vennligst vent, kompilerer.."
		while [ "$CNT" -lt "$TOT" ]; do
			for i in $(echo "$CNT"); do
				title=$(echo "$json" |jq -r ".movies[$i].info.original_title")
				imdb=$(echo "$json" | jq -r ".movies[$i].identifiers.imdb")
				rating=$(echo "$json" |jq -r ".movies[$i].info.rating.imdb[0]")
				if [ "$rating" = "0" ]; then rating="0.0"; fi
				year=$(echo "$json" |jq -r ".movies[$i].info.year")
				if [ "$rating" = "null" ]; then year="in";rating="development";fi
				echo "$imdb - $title ($year) [$rating]" >> "$buffer"
			done
			let CNT=CNT+1
		done
		while read line;do
			say "$who :$line"
		done < "$buffer"
		rm "$buffer"
		say "$who :Totalt $CNT filmer i listen"
	}
	imdb() {
		id_key="${cmd//.imdbd/}"
		if [ "$id_key" = "" ]; then
			id_key="$(read.last)"
		fi
		data="$(curl -s "http://www.omdbapi.com/?i=$id_key&apikey=$omdb_key&plot=full")"
		if [ "$2" = "-r" ]; then
			echo "$data"
			exit
		fi
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
		case $_type in
			'series')
				say "$RES :*$title*, released $released ($rating)."
				say "$RES :*Active years*: $year (seasons: $seasons)"
				say "$RES :*Actors*: $actors"
				say "$RES :*plot*: $plot";;
			'movie'|'documentary'|'anime')
				file="$(echo "$meta" |jq -r '.response.data.media_info[0].parts[0].file')"
				video_bit="$(echo "$meta" |jq -r '.response.data.media_info[0].parts[0].streams[0].video_bitrate')"
				video_width="$(echo "$meta"  |jq -r '.response.data.media_info[0].parts[0].streams[0].video_width')"
				video_height="$(echo "$meta"  |jq -r '.response.data.media_info[0].parts[0].streams[0].video_height')"
				video_codec="$(echo "$meta"  |jq -r '.response.data.media_info[0].parts[0].streams[0].video_codec')"
				video_fps="$(echo "$meta" |jq -r '.response.data.media_info[0].parts[0].streams[0].video_frame_rate' |awk -F "." '{print $1}')"
				say "$RES :$title, released $released ($rating)."
				say "$RES :Active years: $year (runtime: $runtime)"
				say "$RES :Actors: $actors"
				say "$RES :plot: $plot"
				if [ "$ratingkey" != "" ]; then
					say "$RES :Plex: ${video_width}x${video_height}@${video_fps}fps($video_codec/${video_bit}kbps)"
					echo "debug: $ratingkey"
				fi
				;;
		esac
	}
