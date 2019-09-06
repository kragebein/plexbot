#!/bin/bash -
# There is no reason what so ever to edit this file unless you totally know what you are doing. In that case, have fun. 
source /drive/drive/.rtorrent/scripts/v3/bot/config.cfg

source ${pb%/*}/proto/$proto.sh 
source ${pb%/*}/db/$db.sh
_script="functions.sh"
DTG=$(echo "[$(date +%d-%m-%y) $(date +%H:%M:%S)]")
log() {
	# Log v3
	if [ -w $log_path/$_script ]; then
		echo "ERROR, incorrect permissions in log_path ($log_path), cannot write to it!!"
		echo "Check permissions or edit config.cfg"
		#        exit 1
	fi
	message=$(echo ${*##log $1} | awk -F "^$1 " '{print $2}')
	case $1 in
		'NOT'|'not'|'n')
			echo "$DTG [notification]: $message" >> $log_path/${_script%%.*}.log
			echo "$DTG [notification/${_script%%.*}]: $message" >> $log_path/plexbot.log
			echo "$message"
			;;
		'WRN'|'wrn'|'w')
			echo "$DTG [warning]: $message" >> $log_path/${_script%%.*}.log
			echo "$DTG [warning/${_script%%.*}]: $message" >> $log_path/plexbot.log
			echo "[warning] $message"
			#syslog "[$0 - warning] - $message"
			;;
		'err'|'ERR'|'e')
			echo "$DTG [error]: $message" >> $log_path/${_script%%.*}.log
			echo "$DTG [error/${_script%%.*}]: $message" >> $log_path/plexbot.log
			echo "[ERROR] $message"
			#                       syslog "[$0 - error] $message"
			echo "Unrecoverable, exiting."
			say "#log :$_script: $message"
			exit 1
			;;
		'say'|'SAY'|'s')
			echo "$DTG [saying]: $message" >> $log_path/${_script%%.*}.log
			echo "$DTG [saying/${_script%%.*}]: $message" >> $log_path/plexbot.log
			echo "[saying] $message"
			#                       syslog "[$0 - warning] $message"
			say "#log :$message"
			;;
		*)      message="$*"
			echo "$DTG [undef]: $message" >> $log_path/${_script%%.*}.log
			echo "$DTG [undef/${_script%%.*}]: $message" >> $log_path/plexbot.log
			echo "[undef]: $message"
	esac
}

myq() {
                # syntax: myq "databasenavn select blah from blah where blah osvosv" avslutt med ;"
                db=$(echo "$*" |awk -F " " '{print $1}')
                query=$(echo "$*" |awk -F "$db " '{print $2}')
                mysql --login-path=local -D "$db" -s -s -N -e "$query"
                _script="mysql.sh"
                case $query in
                        *INSERT*)
                                log n "SQL write: $query";;
                esac
                unset _script
        }


uac() {
	# user access control
	for i in "${!auth_user[@]}"; do if [ "$who_orig" == "${auth_user[$i]}" ]; then authorized="y";fi;done
	if [ -z "$authorized" ]; then say "$who :Unauthorized";exit;fi
}
req_admin() {
	for i in $(seq "${!admin_user[@]}");do if [ "$who_orig" == "${admin_user[$i]}" ]; then bot_admin="y";fi;done
	if [ -z $bot_admin ]; then say "$who :This action requires elevated privs. Unauthorized.";exit;fi
}

reload_plugins() {
	p=0
	echo "declare -A plug" > $pb/plugins/.loaded
	echo "plug=(" >> $pb/plugins/.loaded
	for i in $pb/plugins/*.sh; do
		lol="$(egrep "^regex=" $i)"
		if [ ! -z "$lol" ]; then
			lol="${lol//\"/}"
			lol="${lol//regex=/}"
			echo "[$i]=\"$lol\"" >> $pb/plugins/.loaded
			let p=p+1
		fi
	done
	echo ")" >> $pb/plugins/.loaded
	chmod +x $pb/plugins/.loaded
	say "$who :Configuration reloaded, $p plugins loaded"
}

html_ascii () {
	out="$content"  
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
lastadd="/tmp/.lastadd"
lastadd() {
	echo "$imdbid" > $lastadd
}
load() {
	if ! source "$1" ; then
		_script="functions_loader"
		log e "Unable to load $1, syntax error. See error.log"
	fi
}
ttdb() {
	rewrite() {
		buffer=$(mktemp)
		cat $config_path/config.cfg | sed "s/ttdb_token=\"$ttdb_token\"/ttdb_token=\"$key\"/g" >$buffer
		mv -f "$buffer" "$config_path/config.cfg";chmod +x $config_path/config.cfg
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
	}
	check() {
		_test="$(echo "$json" |jq -r '.Error')"
		if [ "$_test" != "NULL" ]; then
			case $_test in
				'Not authorized')
					get_key;;
				'Resource not found')
					exit;;      # ttdbid not found
				*)
					echo "ERROR: $json" 
					exit
					;;
			esac
		fi

	}
	imdbid="$input"
	if [[ "$input" =~ ^.t.{0,9} ]]; then
		json="$(curl -s -X GET --header 'Accept: application/json' --header "Authorization: Bearer $ttdb_token" "https://api.thetvdb.com/search/series?imdbId=$input" |  sed 's/\\r//g' | sed s'/\\n//')"
		check "$json";ttdbid="$(echo -ne "$json" |jq '.data[0].id')";export ttbid
	else
		json="$(curl -s -X GET --header 'Accept: application/json' --header "Authorization: Bearer $ttdb_token" "https://api.thetvdb.com/series/$input" |  sed 's/\\r//g' | sed s'/\\n//g')"
		check "$json";imdbid="$(echo -ne "$json" |jq -r '.data.imdbId')";export imdbid
	fi

}


#pl() { # not sure if this will ever be 
#	if test -f ../lang/$language.lang; then
#		source ../lang/$language.lang
#	else
#		log e "Language file for \"$language\" either doesnt exist or contains a syntax error. "
#	fi
#}
