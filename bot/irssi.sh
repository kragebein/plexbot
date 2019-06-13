#!/bin/bash
source /drive/drive/.rtorrent/scripts/master.sh

who="$3"
imdbid="$2"

check_input(){
	if [[ $imdbid =~ ^[0-9]{1,3}(.*)$ ]]; then 
		imdbid="$(cat /tmp/.sbuf |grep -w "$imdbid" |awk -F ' ' '{print $2}')";
	fi
}
getspeed() {
	buffer="$(mktemp)"
	speedtest-cli --simple > $buffer
	speedms="$(cat "$buffer" |grep "Ping" |awk -F : '{print $2}')"
	speedup="$(cat "$buffer" |grep "Up" |awk -F : '{print $2}')"
	speeddn="$(cat "$buffer" |grep "Down" |awk -F : '{print $2}')" 
}

getplex() {
	lastadd_json=$(curl -s "$plexpy/api/v2?apikey=$c_api&cmd=get_recently_added&count=1")
	lastadd=$(echo "$lastadd_json" |jq -r '.response.data.recently_added[0].parent_title')
	case "$lastadd" in
		'')
			lastadd=$(echo "$lastadd_json" |jq -r '.response.data.recently_added[0].title');;
		' ')
			lastadd=$(echo "$lastadd_json" |jq -r '.response.data.recently_added[0].title');;
	esac
	section=$(echo "$lastadd_json" |jq -r '.response.data.recently_added[0].section_id')
	if [ "$section" = "2" ]; then
		lastadd_section="[S]"
	else
		lastadd_section="[F]"
	fi
	added_at=$(echo "$lastadd_json" |jq -r '.response.data.recently_added[0].added_at')
	now="$(date +%s)"
	seconds="$(echo $now - $added_at |bc)"
	minutes="$(echo $seconds/60 |bc)"
	hours="$(echo $minutes/60 |bc)"
	if [ "$seconds" -le "60" ]; then timesince="$seconds sekunder siden";fi
	if [ "$minutes" -le "60" ]; then timesince="$minutes minutter siden";fi
	if [ "$hours" -ge "1" ]; then timesince="~$hours timer siden";fi
	activity=$(curl -s "$plexpy/api/v2?apikey=$c_api&cmd=get_activity")
	stream_count=$(echo "$activity" | jq -r '.response.data.stream_count')

}

missing_episode() {
	input=$(echo -ne "$*" | awk -F ".missing" '{print $2}' | awk -F ' ' '{print $1}')
	season=$(echo -ne "$*" | awk -F ".missing" '{print $2}' | awk -F ' ' '{print $2}')
	episode=$(echo -ne "$*" | awk -F ".missing" '{print $2}' | awk -F ' ' '{print $3}')
	JSON=$(curl -s "http://www.omdbapi.com/?i=$input&apikey=$o_key&type=series")
	response=$(echo "$JSON" |jq -r '.Response')
	Type=$(echo "$JSON" |jq -r '.Type')
	Name=$(echo "$JSON" |jq -r '.Title')
	if [ "$response" = "False" ]; then
		say "$RES :Feil i imdb-id";echo "$JSON" > /tmp/.debugmissing;exit
	else
		if [ "$Type" = "movie" ]; then
			say "$RES :$Name e en film ditt nepskrell!";exit
		fi
	fi
	title=$(echo "$JSON" |jq -r '.Title')

	nope=0
	imdbid=$(echo "$JSON" |jq -r ".imdbID" 2>/dev/null)
	show_title=$(echo "$JSON" |jq -r ".Title" 2>/dev/null)
	thetvdb_id=$(/drive/drive/.rtorrent/scripts/ttdb.sh $imdbid)
	if [ "$thetvdb_id" = "" ]; then
		say "$RES :thetvdb api nede?";exit
	fi

	sanity=$(curl -s "$sickrage/api/$s_key/?cmd=episode&indexerid=$thetvdb_id&season=$season&episode=$episode")
	check=$(echo "$sanity" |jq -r '.result')
	case $check in
		'success')
			episode_status=$(echo "$sanity" |jq -r '.data.status')
			episode_name=$(echo "$sanity" |jq -r '.data.name')
			case $episode_status in
				'Downloaded') say "$RES :$show_title - \"$episode_name\" fins allerede i systemet, men endrer likevel status på episoden. Blir lagt til pånytt.";exit;
					curl -s "$sickrage/api/$s_key/?cmd=episode.setstatus&status=wanted&indexerid=$thetvdb_id&season=$season&episode=$episode";;
				'Wanted')
					echo "Søker etter $show_title - \"$episode_name\" .."
					episode_search=$(curl -s  "$sickrage/api/$s_key/?cmd=episode.search&indexerid=$thetvdb_id&season=$season&episode=$episode")
					result=$(echo "$episode_search" |jq -r '.result')
					case $result in
						'success') say "$RES :Fant episode! Blir lagt til Plex snarest!";;
						'failure') say "$RES :Gjorde et søk, fant desverre ikke episoden innenfor de gitte kvalitetsparametre.";exit;;
						'error') say "$RES :Feil hos ekstern tjeneste, kunne ikke utføre søk.";exit;;
						*)	say "$RES :Feil; missing_episode, sanity_check->episode_status->wanted->result";say "$RES :$episode_search";exit;;
					esac;;

				'Skipped'|'Ignored'|'Snatched')
					say "$RES :Søker etter $show_title - \"$episode_name\" .."
					status_change=$(curl -s "$sickrage/api/$s_key/?cmd=episode.setstatus&status=wanted&indexerid=$thetvdb_id&season=$season&episode=$episode");
					result=$(echo "$status_change" |jq -r '.result')
					case $result in
						'failure') message=$(echo "$status_change" |jq -r '.message') say "$RES :Episoden mangler, men kan ikke endre status: $message";exit;;
						'success') say "$RES :Oops, episoden manglet. Den blir lagt til fortløpende.";exit;;
						*) say "$RES :Feil; missing_episode, sanity_check->episode_status->skipped->result;"; say "$RES :$status_change";exit;;
					esac;;

				esac;;

			'failure') say "$RES :Serien fins ikke på Plex, request den først!";exit;;
			'error') say "$RES :S${season}x${episode} fins ikke på $title";exit;;
			*) say "$RES :Feil, missing_episode, sanity_check;";say "$RES :$sanity";exit;;
		esac
	}

	imdb_look() {
		rm /tmp/.sbuf 2>/dev/null
		buffer=$(mktemp)
		arg="$(echo $* |awk -F ".search " '{print $2}')"
		argw="$(echo -ne "$arg" | xxd -plain | tr -d '\n' | sed 's/\(..\)/%\1/g')"
		COUNTER=0
		MULTICOUNT="0"
		JSON="$(curl -s "$couchpotato/api/$sofa_api/search?q=$argw")"
		echo "$JSON" >/drive/drive/.rtorrent/logs/json.log 2>/dev/null
		hits="$(echo $JSON |grep -o "original_title" |wc -l)"
		say "$RES :Filmer"
		say "$RES :-------------"
		if [ "$hits" = "0" ]; then say "$RES :Ingen treff på $arg";else :;fi
		if [ "$hits" = "1" ]; then calc="1";else calc=`echo "$hits -1" |bc`;fi
		while [  $COUNTER -lt $calc ]; do
			title="$(echo $JSON |jq ".movies[$COUNTER].original_title" 2>/dev/null)"
			imdb="$(echo $JSON |jq ".movies[$COUNTER].imdb" 2>/dev/null|sed 's/"//g')"
			year="$(echo $JSON |jq ".movies[$COUNTER].year" 2>/dev/null|sed 's/"//g')"
			rating="$(echo $JSON |jq ".movies[$COUNTER].rating.imdb[0]" 2>/dev/null)"
			wanted="$(echo $JSON |jq ".movies[$COUNTER].in_wanted.status" 2>/dev/null |sed 's/"//g')"
			library="$(echo $JSON | jq ".movies[$COUNTER].in_library.status" 2>/dev/null | sed 's/"//g')"
			case $rating in
				'') rating="0.0";;
				' ') rating="0.0";;
				'null') rating="0.0";;
			esac

			if [ "$year" = "null" ]; then
				:
			else
				if [ "$wanted" = "active" ]; then
					what="Ligger i ventelisten."
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
					say "$RES :$MULTICOUNT. $what2 - $title ($year)[$rating/10.0]"
					say "$RES : "

					echo "$MULTICOUNT $imdb" >>$buffer

				fi
			fi
			let COUNTER=COUNTER+1
			let MULTICOUNT=MULTICOUNT+1
		done
		say "$RES :TV-serier"
		say "$RES :-------------"
		input="$(echo -ne "$arg" | xxd -plain | tr -d '\n' | sed 's/\(..\)/%\1/g')"
		JSON=$(curl -s "http://www.omdbapi.com/?s=$input&apikey=$o_key&type=series")
		count=$(echo "$JSON" |jq '.Search' |grep "{" |wc -l)
		COUNTER=0
		if [ "$count" = "0" ]; then
			say "$RES :Ingen treff på \"$arg\""
		fi

		while [ $COUNTER -lt $count ]; do
			nope=0
			title=$(echo "$JSON" |jq -r ".Search[$COUNTER].Title" 2>/dev/null)
			year=$(echo "$JSON" |jq -r ".Search[$COUNTER].Year" 2>/dev/null)
			imdbid=$(echo "$JSON" |jq -r ".Search[$COUNTER].imdbID" 2>/dev/null)
			thetvdb_id="$(/drive/drive/.rtorrent/scripts/ttdb.sh $imdbid)"
			sanity=$(curl -s "$sickrage/api/$s_key/?cmd=show.cache&tvdbid=$thetvdb_id")
			check=$(echo "$sanity" |jq -r '.result' 2>/dev/null)
			case $check in
				'success') status="✔️$imdbid";;
				'failure') status="➕$imdbid";;
				'error') status="🚫$imdbid";;
			esac
			rating=$(curl -s "http://www.omdbapi.com/?i=$imdbid&apikey=$o_key&type=series" |jq -r '.imdbRating' 2>/dev/null)
			case $rating in
				'') rating="0.0";;
				' ') rating="0.0";;
				'null') rating="0.0";;
			esac
			if [ "$nope" = "0" ]; then
				say "$RES :$MULTICOUNT. $status - $title ($year)[$rating/10.0]"
				say "$RES : "
				echo "$MULTICOUNT $imdbid" >>$buffer
			else
				:
			fi
			let COUNTER=COUNTER+1
			let MULTICOUNT=MULTICOUNT+1
		done
		mv $buffer /tmp/.sbuf
		exit


	}
	show_get_pluss() {
		#Finn ut av ønsket kvalitet, språk og status. 
		:
	}

	show_get_id() {

		thetvdb_id="$(/drive/drive/.rtorrent/scripts/ttdb.sh $imdbid)"
		#echo "$imdbid"
		#echo "$(curl -s "http://thetvdb.com/index.php?seriesname=&fieldlocation=4&language=7&genre=&year=&network=&zap2it_id=&tvcom_id=&imdb_id=$imdbid&order=translation&addedBy=&searching=Search&tab=advancedsearch")"
		case $thetvdb_id in
			'') say "$RES :$imdb_title fins på imdb ($imdbid), men fins ikke en samsvarende id på thetvdb (null), kan derfor ikke legges til.";exit;;
			' ')say "$RES :$imdb_title fins på imdb ($imdbid), men fins ikke en samsvarende id på thetvdb (null), kan derfor ikke legges til.";exit;;
			*):;;
		esac

	}

	show_check_exist_fail() { 
		sanity=$(curl -s "$sickrage/api/$s_key/?cmd=show.cache&tvdbid=$thetvdb_id")
		check=$(echo "$sanity" |jq -r '.result')
		case $check in
			'failure') :;;
			'success') say "$RES :Serien \"$imdb_title\" ligg allerede i Plex";exit;;
			*) say "$RES : Feil; blank/tom respons fra ekstern server, prøv igjen."; say "$RES :$sanity";exit 1;;
		esac

	}

	show_check_exist() {
		sanity=$(curl -s "$sickrage/api/$s_key/?cmd=show.cache&tvdbid=$thetvdb_id")
		check=$(echo "$sanity" |jq -r '.result')
		case $check in
			'failure') :;;
			'success') say "$RES :Serien $imdb_title ligg allerede i Plex";exit;;
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

		indexerid="$thetvdb_id"
		status="wanted"
		future_status="wanted"
		season_folder="1"
		anime="0" 
		quality_check=$(curl -s "http://www.omdbapi.com/?i=$imdbid&apikey=$o_key&type=series" |jq -r '.Year')

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
		execute_add=$(curl -s "$sickrage/api/$s_key/?cmd=show.addnew&indexerid=$indexerid&status=$status&future_status=$future_status&season_folders=$season_folder&initial=${initial}&anime=$anime&location=$location")
		execute_add_error=$(echo "$execute_add" |jq -r '.result')
		case $execute_add_error in
			'success') say "$RES :Serien \"$imdb_title\" ($imdbid) er blitt lagt til. Vil komme på plex fortløpende";;
			'failure') say "$RES :Serien \"$imdb_title\" ble ikke lagt til." echo "";echo "$execute_add";;
			*) say "$RES :Feil; show_add, execute_add->error";echo "$execute_add";;
		esac
		exit
	}

	tv_search() {
		argw="`echo $* |awk -F ".tvsearch " '{print $2}'`"
		input="`echo -ne "$argw" | xxd -plain | tr -d '\n' | sed 's/\(..\)/%\1/g'`"
		JSON=$(curl -s "http://www.omdbapi.com/?s=$input&apikey=$o_key&type=series")
		count=$(echo "$JSON" |jq '.Search' |grep "{" |wc -l)
		COUNTER=0
		if [ "$count" = "0" ]; then
			say "$RES :Ingen treff på \"$argw\"";exit
		else
			:
		fi

		while [ $COUNTER -lt $count ]; do
			nope=0
			title=$(echo "$JSON" |jq -r ".Search[$COUNTER].Title" 2>/dev/null)
			year=$(echo "$JSON" |jq -r ".Search[$COUNTER].Year" 2>/dev/null)
			imdbid=$(echo "$JSON" |jq -r ".Search[$COUNTER].imdbID" 2>/dev/null)
			thetvdb_id=$(/drive/drive/.rtorrent/scripts/ttdb.sh $imdbid)

			sanity=$(curl -s "$sickrage/api/$s_key/?cmd=show.cache&tvdbid=$thetvdb_id")
			check=$(echo "$sanity" |jq -r '.result')
			case $check in
				'success') status="I plex";;
				'failure') status="$imdbid";;
				'error') say "$RES :$imdbid - $title ($year) [$rating/10.0]";say "$RES :Fins ikke på thetvdb👆";exit;;
			esac
			rating=$(curl -s "http://www.omdbapi.com/?i=$imdbid&apikey=$o_key&type=series" |jq -r '.imdbRating') 
			if [ "$nope" = "0" ]; then
				say "$RES :$status - $title ($year)[$rating/10.0]"
				say "$RES : "
			fi
			let COUNTER=COUNTER+1
		done
		exit
	}

	show_initiate() {
		show_get_id
		show_check_exist $thetvdb_id
		show_add $lang $thetvdb_id 
		exit
	}

	parse_imdb() {
		#TODO:  get_lang
		xml="$(curl -s "http://www.omdbapi.com/?i=$imdbid&plot=short&r=json&apikey=$o_key")"
		if [ "$(echo $xml)" = "The service is unavailable." ]; then echo "Nødvendig tredjepartstjeneste midlertidlig utilgjengelig. Prøv igjen senere."; exit 0; fi
		respons="$(echo $xml |awk -F "Response\":" '{print $2}'|awk -F "\"" '{print $2}')"
		if [ "$respons" = "True" ]; then :;else say "$RES :Ingen film eller serie med denne IDen: $imdbid";exit 1;fi
		imdb_title=$(echo $xml |awk -F "Title\":" '{print $2}' |awk -F "\"" '{print $2}' 2>/dev/null)
		couch_title=$(echo $imdb_title | sed 's/ /+/g')
		typ="$(echo $xml |awk -F "\"Type\":" '{print $2}' |awk -F "\"" '{print $2}')"
		if [ "$typ" = "series" ]; then show_initiate $imdbid;exit;
		elif [ "$typ" = "movie" ]; then :;else say "$RES :$imdb_title er ikke en film eller serie. Kun filmer og serier kan legges i ønskelisten.";exit 0
		fi
	}


	check_exist() {
		#say "$RES :Film requests ute av drift for øyeblikket";exit
		exists="$(curl -s "$couchpotato/api/$sofa_api/media.get/?id=$imdbid")"
		check=$(echo "$exists" |awk -F '{\"status\": ' '{print $2}' |awk -F "\"" '{print $2}')
		case $check in
			'active')
				say "$RES :$imdb_title ($imdbid) ligger allerede i ventelisten, men filmen har enda ikke hatt første visning. Det blir ikke gjort forsøk på å legge den til før etter første visning.";exit 0;;
			'done')
				say "$RES :$imdb_title ($imdbid) er allerede tilgjengelig i biblioteket.";exit 0;;
			'false')
				:;;
		esac
	}


	parse_sofa() {
		check_exist
		year=$(curl -s curl -s "http://www.omdbapi.com/?i=$imdbid&plot=short&r=json&apikey=$o_key" |jq -r '.Year')
		initial="32be391d247b4af2acab4fce07bd7c02" # set default
		if [ "$year" -le "2006" ]; then
			initial="32be391d247b4af2acab4fce07bd7c02" #HD

		elif [ "$year" -le "2002" ]; then
			initial="7634dd8abcf14a5a90eef7ad1aba098d" #SD
		fi

		xml="$(curl -s "$couchpotato/api/$sofa_api/movie.add/?force_readd=false&title=$couch_title&identifier=$imdbid&profile_id=$initial")"
		response="$(echo $xml |awk -F "\"success\": " '{print $2}' |awk -F '}' '{print $1}')"
		if [ "$response" = "true" ]; then :;else say "$RES :Kunne ikke parse JSON, se debuglog.\n$xml";echo -e "$xml\n$imdbid\n$couch_title" > logs/updater.logdgb;exit 1; fi
		status="$(echo $xml |awk -F '{\"status\": ' '{print $2}' |awk -F "\"" '{print $2}')"
		case $status in
			'done')
				say "$RES :Filmen \"$imdb_title\" fins allerede i Plex";exit 1;;
			'active')
				sleep 10s;cp_status="$(cat /tmp/webhook_$imdbid |grep "Snatched" |awk -F ".ø. " '{print $2}')"
				if [ "$cp_status" = "$imdbid" ]; then
					say "$RES :Filmen $imdb_title ($imdbid) ble funnet, henter ned.."
				else
					say "$RES :Filmen $imdb_title ($imdbid) er lagt til ønskelisten."
					rm /tmp/cp_status_$imdbid 2>/dev/null
					echo "$imdbid" > /tmp/.request.$imdbid
				fi;;
			*)
				:
		esac
	}


	case $1 in 
		'.speedtest')
			getspeed
			say "$RES :ms: $speedms"
			say "$RES :up: $speedup"
			say "$RES :dn: $speeddn"
			exit;;
		'.restartplex')
			say "$RES :Plex må manuelt startes på nytt igjen.";exit
			buffer="$(mktemp)"
			sudo service plexmediaserver restart > $buffer
			if [ "$?" = "0" ]; then
				say "$RES :Plex Media Server restarta"
			else
				say "$RES :Det skjedd en fail. Kontakt Stian eller Patrick. Log output:"
				say "$RES :$(cat $buffer)";rm $buffer
			fi
			exit;;
		'.speed')
			getnetwork
			say "$RES :up/down: $curup/$curdn"
			say "$RES :Up/Down/Total: $tx/$rx/$ttotal"
			exit	;;
		'.up')
			say "$RES :$(uptime)"
			exit	;;
		'.plex')
			getplex 
			say "$RES :Siste lagt til: $lastadd_section $lastadd ($timesince)"
			if [ "$stream_count" = "0" ]; then 
				say "$RES :Plex e folketomt! E ingen som stream no.";
			else
				/drive/drive/.rtorrent/scripts/showstreams.sh;
			fi
			exit	;;
		'.stats')
			say "#gruppa : https://www.lazywack.no/fb/" ;;
		'.kino')
			bash /drive/drive/.rtorrent/scripts/kino.sh "$@";;
		'.request') check_input;parse_imdb;parse_sofa ;;
		'.missing') check_input; missing_episode $imdbid $3 $4;;
		'.top') /drive/drive/.rtorrent/scripts/top10.sh ;;
		'.tvsearch') tv_search $*;;
		'.wishlist') /drive/drive/.rtorrent/scripts/wishlist.sh ;;
		'.search') imdb_look $* ;;	
		'.refresh') check_input;/drive/drive/.rtorrent/scripts/refresh_plex_item.sh $imdbid ;;
		'.next') /drive/drive/.rtorrent/scripts/next.sh; /drive/drive/.rtorrent/scripts/movies_next.sh;;
		'.graf') say "$RES :https://www.lazywack.no/grafana/"; say "$RES : plexbota p: von goliath";;
		'.pmp') say "$RES :Plex Media Player; https://www.plex.tv/downloads/#getdownload (Get an app)";;
		'.bitrate')
			say "$RES :Noen av filmene er svært høy bitrate på, for å kunne streame disse må du ha høy hastighet på nettlinja. Her ser du hvordan du kan se bitraten på filmen/serien: http://imgur.com/a/S7ey3.";echo "Er filmen f.eks 6000 kbps, må du ha 6mbit eller høyere. for å kunne streame filmen uten problemer.";;
		'.do_search') curl -s "$couchpotato/api/$sofa_api/movie.searcher.full_search" 2>/dev/null 1>/dev/null; say "$RES :Bip bop bip bop. Søker gjennom hele ønskelisten.";;
		'.imdb') /drive/drive/.rtorrent/scripts/imdb.sh $2;;
		'.debug')
			buffer="$(mktemp)"
			echo "$(tail -8 /drive/drive/.rtorrent/logs/updater.logdgb)" >>$buffer
			while read line;do
				say "$RES :$line"
			done < $buffer;exit;;
		'.status')
			/drive/drive/.rtorrent/scripts/getstats.sh $*
			exit    ;;
		'.help')
			say "$RES :Hvordan bruke Plexbota?"
			say "$RES :Alle kommandoer starter med <punktum><kommando>"
			say "$RES : "
			say "$RES :status - viser sammendrag av all informasjon"
			say "$RES :nettverk - viser nettverksinformasjon."
			say "$RES : "
			say "$RES :restartplex - restart plex. Kun om alt går i stampe."
			say "$RES : "
			say "$RES :request <imdbid> - legger <imdb> til i ønskelisten."
			say "$RES :wishlist - se hva som ligger i ønskelista"
			say "$RES :search - søk etter filmer/serier via imdb"
			say "$RES :next - Viser når neste episode kommer på plex"
			say "$RES :do_search - Gjør et fullt søk etter hele wishlisten"
			say "$RES :missing - last ned episode (pånytt)!"
			say "$RES :\".missing <imdbid> <sesong> <episode>\""
			say "$RES :refresh <imdbdid> - refresh metadata (last ned tekst)"
			say "$RES :notify <imdbid> - Få varsel når episode/film e tilgjengelig"
			say "$RES : " 
			say "$RES :Andre kommandoer"
			say "$RES :up, load, debug, plex"
			exit	;;
		' ')
			say "$RES :Sjekk ut .help"
			exit
			;;

		esac
