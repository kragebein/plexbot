#!/bin/bash - 
#===============================================================================
#
#          FILE: output.sh
# 
#         USAGE: ./output.sh 
# 
#   DESCRIPTION: input needs output.
#		 bot will respond through private chat or group messages if you are authorized to 
#		 Informational messages will still go to $bot_channel (set in config.sh)
pipe="/tmp/.rc"

where="$who"
channel="$channel"
cmd="$cmd"
if [ "$channel" != "" ]; then
	where="$channel"
fi


say() {
	if [ -z ${DEBUG+yes} ]; then # DEBUG=yes will print to stdout instead.
		if [ -p "$pipe" ]; then
			echo -e "/QUOTE PRIVMSG "$dest :$@"" > $pipe
		fi
	else
		debug_ignore="$(echo "$*" |awk -F " :" '{print $1}')"
		debug_print="$(echo  "$*" | awk -F "$debug_ignore :" '{print $2}')"
		echo "$debug_print"
	fi

}
