#!/bin/bash - 
#===============================================================================
#
#          FILE: youtubeadd.sh
# 
#         USAGE: ./youtubeadd.sh 
# 
#   DESCRIPTION: Will add movies/shows from trailers posted in chat. 
#===============================================================================
source /drive/drive/.rtorrent/scripts/master.sh
source /drive/drive/.rtorrent/scripts/v3/bot/functions.sh
_script="youtubeadd.sh"
if [ "$channel" != "" ]; then who="$channel";fi # kommer requesten fra en kanal, gje svar i kanalen.
regex="^(https?\:\/\/)?(www\.)?(youtube\.com|youtu\.?be)\/.+$"

bad_data=( "OFFICIAL TEASER" "OFFICIAL TEASE" "OFFICIAL TRAILER" "FINAL TRAILER" "FIRST TRAILER" "HBO" "NETFLIX" "MARVEL STUDIOS'" "4K" "TRAILERS" "TRAILER" "1080P" "8K" "MOVIECLIPS" "#1" "#2" "#3" "|" "- "
)
inp="$(curl -sL "$cmd" |pup 'meta json{}')"
function add_this() {
	case $result in
		'title')
			echo "$year"
			if [ "$year" = "" ]; then
				json="$(curl -s "http://www.omdbapi.com/?s=$(echo -ne "$_this" | xxd -plain | tr -d '\n' | sed 's/\(..\)/%\1/g')&apikey=$o_key&plot=full")"
			else
				json="$(curl -s "http://www.omdbapi.com/?s=$(echo -ne "$_this" | xxd -plain | tr -d '\n' | sed 's/\(..\)/%\1/g')&y=$year&apikey=$o_key&plot=full")"
			fi
			results="$(echo $json |jq -r ".totalResults")"
			rm /tmp/.sbuf
			case 1 in
				$((results <= 0))) log s "youtubeadd.sh: match failed for \"$_this\" - update regex?";exit;;
				$((results <= 2))) 
					if ! /drive/drive/.rtorrent/scripts/irssi.sh .request $(echo $json | jq -r ".Search[0].imdbID"); then
						say "$who :Ser ut til at det faila å legg tell automatisk. Bruk .request 0"
						echo "0 $(echo $json | jq -r ".Search[0].imdbID")" > /tmp/.sbuf
					fi;;	

				$((results >= 2))) 
					say "$who :$results resultat, vis de første 9:"
					if [ "$(echo $json | jq -r ".Search[$i].Type")" = "series" ]; then
						type="S"
					else
						type="F"
					fi
					for i in $(seq 0 $results); do
						if [ "$(echo $json | jq -r ".Search[$i].imdbID")" = "null" ]; then
							break
						fi
						say "$who :$i / $(echo $json | jq -r ".Search[$i].imdbID") $type:$(echo $json | jq -r ".Search[$i].Title") ($(echo $json | jq -r ".Search[$i].Year"))"
						echo "$i $(echo $json | jq -r ".Search[$i].imdbID")" >> /tmp/.sbuf
					done
					say "$who :Førr å legg tell kan du bruk .request <nummer>."
					;;
			esac ;;

		'imdbid')
			: # not null
			;;
	esac

}
for i in {0..1000} ; do
	content="$(echo "$inp" | jq -r ".[$i].content")"
	name="$(echo "$inp" | jq -r ".[$i].name")"
	case $name in
		'title') #found a title
			result="title"
			year="$(echo "$content" |grep -oP '\([0-9]{4}\)')"
			if [ "$year" != "" ]; then
				year="${year/\(/}";year="${year/\)/}"
			else 
				let y=i+1 #lets have a look in the description to see if we can find a year
				year="$(echo "$inp" | jq -r ".[$y].content" |grep -oP '([^]][0-9]{4})'| sed -e 's/[[:space:]]//g')"
			fi

			content="${content^^}"
			content="$(content="$content" html_ascii)"
			for i in $(echo ${!bad_data[@]}); do
				content="${content//${bad_data[$i]}/}" # need to process name.
				#echo "$content < ${bad_data[$i]}"
			done
			_this="$(echo $content |sed -e 's/[[:space:]]*$//')"
			_this="${_this/($year)/}"
			_this="${_this% *}"
			;;
		*)
			if [[ "$content" =~ '^.t.{0,9}' ]]; then
				result="imdbid"
				imdbid="$content"	#found imdbid! This takes precedence.
				add_this		# go directly to adding.
				exit;
			fi


		esac
		if [ "$content" = "null" ]; then
			break # eof, break loop
		fi
	done
	if [ "$result" = "title" ]; then
		add_this 
	else
		log s "url provided: $url, no data found"
		exit
	fi

