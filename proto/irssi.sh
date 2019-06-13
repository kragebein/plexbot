#!/bin/bash - 
# Use remote.pl in irssi to activate fifo pipe. irssi will listen to the pipe for commands.
# aliases etc is not supported. Commands will be sendt directly through to the irc server.
# To use with facebook-messenger, install bitlbee-messenger. 


pipe="/tmp/.rc"
say() {
	if [ -z ${DEBUG+yes} ]; then # DEBUG=yes will print to stdout instead. 
		if [ -p "$pipe" ]; then      
			echo -e "/QUOTE PRIVMSG "$@"" > $pipe
		fi
	else
		debug_ignore="$(echo "$*" |awk -F " :" '{print $1}')"
		debug_print="$(echo  "$*" | awk -F "$debug_ignore :" '{print $2}')"
		echo "$debug_print"
	fi
}


