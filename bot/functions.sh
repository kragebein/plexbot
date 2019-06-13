#!/bin/bash -
# There is no reason what so ever to edit this file unless you totally know what you are doing. In that case, have fun. 
source /drive/drive/.rtorrent/scripts/v3/bot/config.cfg
source ${pb%/*}/proto/$proto.sh 
source ${pb%/*}/db/$db.sh
_script="functions.sh"
DTG=$(echo "[$(date +%d-%m-%y) $(date +%H:%M:%S)]")
log() {
	# Log v3
    if [ -w $log_path ]; then
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

uac() {
	# user access control
	for i in ${!auth_user[@]}; do if [ "$who_orig" == "${auth_user[$i]}" ]; then authorized="y";fi;done
	if [ -z "$authorized" ]; then say "$who :Unauthorized";exit;fi
}
req_admin() {
	for i in $(seq ${!admin_user[@]});do if [ "$who_orig" == ${admin_user[$i]} ]; then bot_admin="y";fi;done
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
	out="${out//&nbsp;/ }"
	out="${out//&amp;/&}"
	out="${out//&lt;/<}"
	out="${out//&gt;/>}"
	out="${out//&quot;/'"'}"
	out="${out//&\#39;/"'"}"
	out="${out//&ldquo;/'"'}" 
	out="${out//&rdquo;/'"'}"
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
#pl() { # not sure if this will ever be 
#	if test -f ../lang/$language.lang; then
#		source ../lang/$language.lang
#	else
#		log e "Language file for \"$language\" either doesnt exist or contains a syntax error. "
#	fi
#}
