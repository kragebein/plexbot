#!/bin/bash -
# There is no reason what so ever to edit this file unless you totally know what you are doing. In that case, have fun. 
source /drive/drive/.rtorrent/scripts/v3/bot/config.cfg
#source "${pb%/*}/lang/$language.lang" #TODO

_script="functions.sh"
dtg="[$(date +%d-%m-%y) $(date +%H:%M:%S)]"
log() {
	# Log v3
	#	if ! [ -w "$log_path/$_script" ]; then
	#		echo "ERROR, incorrect permissions in log_path ($log_path/$_script), cannot write to it!!"
	#		echo "Check permissions or edit config.cfg"
	#        exit 1
	#	fi
	message=$(echo "${*##log $1}" | awk -F "^$1 " '{print $2}')
	case $1 in
		'NOT'|'not'|'n')
			echo "$dtg [notification]: $message" >> "$log_path/${_script%%.*}.log"
			echo "$dtg [notification/${_script%%.*}]: $message" >> "$log_path/plexbot.log"
			echo "$message" >&2
			;;
		'WRN'|'wrn'|'w')
			echo "$dtg [warning]: $message" >> "$log_path/${_script%%.*}.log"
			echo "$dtg [warning/${_script%%.*}]: $message" >> "$log_path/plexbot.log"
			echo "[warning] $message" >&2
			#syslog "[$0 - warning] - $message"
			;;
		'err'|'ERR'|'e')
			echo "$dtg [error]: $message" >> "$log_path/${_script%%.*}.log"
			echo "$dtg [error/${_script%%.*}]: $message" >> "$log_path/plexbot.log"
			echo "[ERROR] $message" >&2
			#                       syslog "[$0 - error] $message"
			echo "Unrecoverable, exiting." >&2
			say "#log :$_script: $message"
			exit 1
			;;
		'say'|'SAY'|'s')
			echo "$dtg [saying]: $message" >> "$log_path/${_script%%.*}.log"
			echo "$dtg [saying/${_script%%.*}]: $message" >> "$log_path/plexbot.log"
			echo "[saying] $message" >&2
			#                       syslog "[$0 - warning] $message"
			say "#log :$message"
			;;
		*)      message="$*"
			echo "$dtg [undef]: $message" >> "$log_path/${_script%%.*}.log"
			echo "$dtg [undef/${_script%%.*}]: $message" >> "$log_path/plexbot.log"
			echo "[undef]: $message" >&2
	esac
}
debug() {
	echo "$*" >&2
}
load() { #note to self, log before load.
	if ! source "$1" ; then
		_script="functions_loader"
		log e "Unable to load $1, see error log."
	fi
}
load "${pb%/*}/proto/$proto.sh"		#load protocol
load "${pb%/*}/db/sql.sh"			#load database

uac() {
	# user access control
	for i in "${!auth_user[@]}"; do if [ "$who_orig" == "${auth_user[$i]}" ]; then authorized="y";fi;done
	if [ -z "$authorized" ]; then say "$who :Beklager, du e ikke autorisert.";log s "uac: $who_orig prøvd å bruk plexbota.";exit;fi
}
req_admin() {
	# admin access control
	for i in $(seq "${!admin_user[@]}");do if [ "$who_orig" == "${admin_user[$i]}" ]; then bot_admin="y";fi;done
	if [ -z $bot_admin ]; then say "$who :Den her handlinga krev høgere tilgang. Uautorisert.";log s "$who_orig prøvd å bruk en adminkommando";exit;fi
}

reload_plugins() {
	p=0
	echo "declare -A plug" > "$pb/plugins/.loaded"
	echo "plug=(" >> "$pb/plugins/.loaded"
	for i in $pb/plugins/*.sh; do
		lol="$(egrep "^regex=" "$i")"
		if [ ! -z "$lol" ]; then
			lol="${lol//\"/}"
			lol="${lol//regex=/}"
			echo "[$i]=\"$lol\"" >> "$pb/plugins/.loaded"
			let p=p+1
		fi
	done
	echo ")" >> "$pb/plugins/.loaded"
	chmod +x "$pb/plugins/.loaded"
	say "$who :Konfigurasjon lasta om, $p plugins e klar."
}

html_ascii () {
	out="$*"
	out="${out//%/%25}"
	out="${out//\&/%26}"
	out="${out//$/%24}"
	out="${out// /%20}"
	out="${out//"'"/%27}"
	out="${out//'"'/%22}"
	out="${out//\//%2F}"
	out="${out//\(/%28}"
	out="${out//\)/%29}"
	out="${out//</%3C}"
	out="${out//>/%3E}"
	out="${out//\?/%3F}"
	out="${out//\!/%21}"
	out="${out//=/%3D}"
	out="${out//\\/%5C}"
	out="${out//,/%2C}"
	out="${out//:/%3A}"
	out="${out//;/%3B}"
	out="${out//\[/%5B}"
	out="${out//\]/%5D}"
	out="${out//\{/%7B}"
	out="${out//\}/%7D}"
	echo "$out"
}
read.last() {
cat /tmp/.lastadd
}
put.last() {
echo "$imdbid" > /tmp/.lastadd
}

ttdb() { # if you input imdbid it will create $rating_key, if you input rating_key it will create $imdbid
	_script="ttdb.log"
	rewrite() {
		buffer=$(mktemp)
		sed "s/ttdb_token=\"$ttdb_token\"/ttdb_token=\"$key\"/g" "$pb/config.cfg" > "$buffer"
		mv -f "$buffer" "$pb/config.cfg";chmod +x "$pb/config.cfg"
		log n "rewrote token to config"
	}
	get_key() {
		key="$(curl -s -X GET --header 'Accept: application/json' --header "Authorization: Bearer $ttdb_token" 'https://api.thetvdb.com/refresh_token' |jq -r '.token')"
		if [ "$key" = "null" ]; then
			key="$(curl -s -X POST --header 'Content-Type: application/json' --header 'Accept: application/json' -d '{ "apikey": "'"$ttdb_api"'",  "userkey": "'"$ttdb_ukey"'",  "username": "'"$ttdb_user"'" }' 'https://api.thetvdb.com/login' |jq -r '.token')"
			if [ "$key" = "null" ]; then
				log s "Could not refresh/get new token! ttdb token failiure";exit
			fi
		fi
		rewrite "$key"
		ttdb_token="$key"
	}
	check() { #Sometimes the plot will come with escape characters and errors. So we remove and check.
		_test="$(echo "$json" |jq -r '.Error')"
		if [ "$_test" != "null" ]; then
			case $_test in
				'Not authorized')
					get_key;;
				'Resource not found')
					exit;;      # ttdbid not found
				*)
					echo "$_test" 
					exit
					;;
			esac
		fi

	}
	input="$1"
	if [[ "$input" =~ ^.t.{0,9} ]]; then
		json="$(curl -s -X GET --header 'Accept: application/json' --header "Authorization: Bearer $ttdb_token" "https://api.thetvdb.com/search/series?imdbId=$input" |tr -d '\n')"
		check "$json"
		rating_key="$(echo -ne "$json" |jq '.data[0].id')"
		export rating_key
		echo "$rating_key"
	else
		json="$(curl -s -X GET --header 'Accept: application/json' --header "Authorization: Bearer $ttdb_token" "https://api.thetvdb.com/series/$input" |tr -d '\n')"
		check "$json"
		imdbid="$(echo -ne "$json" |jq -r '.data.imdbId')"
		export imdbid
		echo "$imdbid"
	fi

}
