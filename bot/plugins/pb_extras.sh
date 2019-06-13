#!/bin/bash - 
#===============================================================================
#
#          FILE: pb_extras.sh
# 
#         USAGE: ./pb_extras.sh 
# 
#   DESCRIPTION: This is a collection of many smaller functions that are useful
#                but not critical to the operation of plexbot. 
#       CREATED: 06/12/2019 10:34
#      REVISION:  ---
#===============================================================================
load $pb/../../master.sh
_script="pb_extras.sh"
regex="^[.](plex)"
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

showstreams() {
    QUERY="$(curl -s "$plexpy/api/v2?apikey=$c_api&cmd=get_activity")"
STREAM_COUNT=$(echo "$QUERY" | jq -r '.response.data.stream_count')
COUNTER=0
COUNT=1
buf="$(mktemp)"
while [ $COUNTER -lt $STREAM_COUNT ]; do
	STATE=$(echo "$QUERY" |jq -r ".response.data.sessions[$COUNTER].state")
	if [ "$STATE" = "error" ]; then break;fi
	STREAM_BIT=$(echo "$QUERY" |jq -r ".response.data.sessions[$COUNTER].bitrate")
	STREAM_RES=$(echo "$QUERY" |jq -r ".response.data.sessions[$COUNTER].video_resolution")
	STREAM_CALCBIT="$(echo "scale=2; $STREAM_BIT/1000" |bc -l)" #kalkuler teoretisk utnyttelse av båndbredde
	UTIL="$(echo "scale=2; (100*$STREAM_CALCBIT)/50." |bc -l)"
	STREAM_CODEC=$(echo "$QUERY" |jq -r ".response.data.sessions[$COUNTER].video_codec")
	STREAM_AUDIO=$(echo "$QUERY" |jq -r ".response.data.sessions[$COUNTER].audio_codec")
	WHO_PLAYS=$(echo "$QUERY" |jq -r ".response.data.sessions[$COUNTER].user" | sed  's/@.*//g' |awk -F "." '{print $1}')
	WHAT_PLAYS=$(echo "$QUERY" |jq -r ".response.data.sessions[$COUNTER].full_title")
	STREAM_TYPE=$(echo "$QUERY" |jq -r ".response.data.sessions[$COUNTER].video_decision" |sed 's/copy/Direct Stream/g' |sed 's/direct play/Direct Play/' |sed 's/transcode/Transcode/g')
	STREAM_PERC=$(echo "$QUERY" |jq -r ".response.data.sessions[$COUNTER].progress_percent")
	STREAM_APP=$(echo "$QUERY" |jq -r ".response.data.sessions[$COUNTER].platform")
	RATING_KEY=$(echo "$QUERY" |jq -r ".response.data.sessions[$COUNTER].rating_key")
	if [ "$STREAM_TYPE" = "Transcode" ]; then 
		FLAMIN="🔥"
		TRANS_BIT="$(echo "$QUERY" |jq -r ".response.data.sessions[$COUNTER].bitrate")"
		TRANS_RES="$(echo "$QUERY" |jq -r ".response.data.sessions[$COUNTER].video_resolution")"
		TRANS_CALCBIT="$(echo "scale=2; $STREAM_BIT/1000" |bc -l)"
		TRANS_UTIL="$(echo "scale=2; (100*$STREAM_CALCBIT)/50." |bc -l)"

	else
		FLAMIN="👍"

	fi
	if [ "$WHO_PLAYS" != "StianLangvbubje" ]; then
		t="$WHO_PLAYS"
		user_convert "$WHO_PLAYS"
		echo "$t -> $WHO_PLAYS"
		say "$who : " 
		say "$who :#$COUNT:${FLAMIN}$user spiller av $WHAT_PLAYS. ($STREAM_PERC%/100%) [$STREAM_CODEC/$STREAM_AUDIO/${STREAM_BIT}kbps($UTIL%)/${STREAM_RES}]. Bruker $STREAM_TYPE via $STREAM_APP"
		echo "$COUNT $RATING_KEY" >> $buf
	fi
	let COUNTER=COUNTER+1
	let COUNT=COUNT+1
	mv $buf /tmp/.sbuf
done
}

case ${cmd//./} in
    'plex')
        getplex
		say "$who :Siste lagt til: $lastadd_section $lastadd ($timesince)"
		if [ "$stream_count" = "0" ]; then 
		    say "$who :Plex e folketomt! E ingen som stream no."
		else
        	showstreams
    	fi ;;
esac

