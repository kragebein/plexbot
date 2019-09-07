#!/bin/bash -
regex="^(status)"
_script="system.sh"                                       # name of this file. For log reasons.
source /drive/drive/.rtorrent/scripts/v3/bot/functions.sh # always call this lib
uac
# You can comment the regex to disable the plugin, but do not put comments behind the line
source /drive/drive/.rtorrent/scripts/master.sh
# This is my personal status script. it will connect to every single server I have and post data about its status.
# collect statistics from the nodes.
cmd="${cmd//status /}"
echo "$cmd"

load_david="$(remote_run plex uptime | awk -F ": " '{print $2}' | awk -F ', ' '{print $1}')"
load_goliath="$(uptime | awk -F ": " '{print $2}' | awk -F ', ' '{print $1}')"
remote_collect() { #Streamline the network collection.
	case $1 in
	'plex') rem_dev="ens18" ;;
	'shell') rem_dev="ens18" ;;
	'goliath') rem_dev="enp4s0" ;;
	esac
	curdn="$(remote_run $1 ifstat -i $rem_dev 1 1 | grep "\." | awk -F " " '{print $1}' | awk -F "." '{print $1 "kb/s"}')"
	curup="$(remote_run $1 ifstat -i $rem_dev 1 1 | grep "\." | awk -F " " '{print $2}' | awk -F "." '{print $1 "kb/s"}')"
	rx="$(remote_run $1 vnstat -q -s | grep "today" | awk -F " " '{print $2 " " $3}' | sed 's/[[:space:]]//g')"
	tx="$(remote_run $1 vnstat -q -s | grep "today" | awk -F " " '{print $5 " " $6}' | sed 's/[[:space:]]//g')"
	ttotal="$(remote_run $1 vnstat -q -s | grep "today" | awk -F " " '{print $8 " " $9}' | sed 's/[[:space:]]//g')"
	yr="$(date +%y)"
	mo="$(date +%b)"
	tot="$mo '$yr"
	if [ "$1" = "goliath" ]; then
		mtotal="$(remote_run $1 vnstat | grep "$tot" | awk -F "$tot" '{print $2}' | sed 's/[[:space:]]//g' | awk -F "/" '{print "↓"$1 " ↑"$2 " tot:"$3}')"
	else
		mtotal="$(remote_run $1 vnstat | grep "$tot" | awk -F "$tot" '{print $2}' | sed 's/[[:space:]]//g' | awk -F "|" '{print "↓"$1 " ↑"$2 " tot:"$3}')"
	fi
}
collect() {
	lastadd_json=$(curl -s "$tt_hostname/api/v2?apikey=$tt_apikey&cmd=get_recently_added&count=1")
	lastadd=$(echo "$lastadd_json" | jq -r '.response.data.recently_added[0].parent_title')
	case "$lastadd" in
	'')
		lastadd=$(echo "$lastadd_json" | jq -r '.response.data.recently_added[0].title')
		;;
	' ')
		lastadd=$(echo "$lastadd_json" | jq -r '.response.data.recently_added[0].title')
		;;
	esac
	section=$(echo "$lastadd_json" | jq -r '.response.data.recently_added[0].section_id')
	if [ "$section" = "2" ]; then
		lastadd_section="[S]"
	else
		lastadd_section="[F]"
	fi
	added_at=$(echo "$lastadd_json" | jq -r '.response.data.recently_added[0].added_at')
	now="$(date +%s)"
	seconds="$(echo $now - $added_at | bc)"
	minutes="$(echo $seconds/60 | bc)"
	hours="$(echo $minutes/60 | bc)"
	if [ "$seconds" -le "60" ]; then timesince="$seconds sekunder siden"; fi
	if [ "$minutes" -le "60" ]; then timesince="$minutes minutter siden"; fi
	if [ "$hours" -ge "1" ]; then timesince="~$hours timer siden"; fi
	activity=$(curl -s "$tt_hostname/api/v2?apikey=$tt_apikey&cmd=get_activity")
	stream_count=$(echo "$activity" | jq -r '.response.data.stream_count')
	# f.eks $lastadd ble lagt til for $timesince
	playtime="$(/drive/drive/.rtorrent/scripts/total_playtime.sh)"
}
messenger="yes"
case $cmd in
'all')
	compact() {
		echo "Service status:"
		echo ""
		echo -n "Unifi Controller.."
		if ping -c 1 unifi.wack 1>/dev/null 2>/dev/null; then
			echo "online"
			echo -ne "\tUnifi Service: "
			if nc -z unifi.wack 8443 1>/dev/null 2>/dev/null; then echo "online"; else echo "offline"; fi
		else echo "offline"; fi
		echo ""
		#torrent.wack
		echo -n "Torrent VM.."
		if ping -c 1 torrent.wack 1>/dev/null 2>/dev/null; then
			echo "online"
			echo -ne "\trtorrent: "
			if nc -z torrent.wack 3907; then echo "up"; else echo "down"; fi
		else echo "offline"; fi
		remote_collect torrent
		echo -e "\tNåværende Last:   ↓$curdn ↑$curup"
		echo -e "\tUkentlig trafikk: ↓$rx ↑$tx tot:$ttotal"
		echo -e "\tMånedlig trafikk: $mtotal"
		echo ""
		#cr.wack
		echo -n "Div VM.."
		if ping -c 1 cr.wack 1>/dev/null 2>/dev/null; then
			echo "online"
			echo -ne "\tPlexPy:"
			if nc -z cr.wack 8181; then echo "up"; else echo "down"; fi
			echo -en "\tOmbi:"
			if nc -z cr.wack 5000; then echo "up"; else echo "down"; fi
			echo -ne "\tCouchPotato: "
			if nc -z cr.wack 5050; then echo "up"; else echo "down"; fi
		else echo "offline"; fi
		echo ""
		#services.wack
		echo -n "Services VM.."
		if ping -c 1 services.wack 1>/dev/null 2>/dev/null; then
			echo "online"
			echo -ne "\tJackett: "
			if nc -z services.wack 9117; then echo "up"; else echo "down"; fi
			echo -ne "\tDNS: "
			if dig @services.wack google.com 1>/dev/null 2>/dev/null; then echo "up"; else echo "down"; fi
		else echo "offline"; fi
		echo ""
		#plex.wack
		echo -n "David VM.."
		if ping -c 1 plex.wack 1>/dev/null 2>/dev/null; then
			echo "online"
			echo -ne "\tPlex Media Server: "
			if nc -z plex.wack 32400; then echo "up"; else echo "down"; fi
		else echo "offline"; fi
		remote_collect plex
		echo -e "\tNåværende Last:   ↓$curdn ↑$curup"
		echo -e "\tUkentlig trafikk: ↓$rx ↑$tx tot:$ttotal"
		echo -e "\tMånedlig trafikk: $mtotal"
		echo ""
		#shell.wack
		echo -n "Shell VM.."
		if ping -c 1 shell.wack 1>/dev/null 2>/dev/null; then
			echo "online"
			echo -ne "\tConnectable: "
			if nc -z shell.wack 22; then echo "yes"; else echo "no"; fi
		else echo "offline"; fi
		echo ""
		#lazywack.no
		echo -n "lazywack.no.."
		if ping -c 1 lazy.wack 1>/dev/null 2>/dev/null; then
			echo "online"
			echo -ne "\tnginx 80: "
			if nc -z lazy.wack 80; then echo "up"; else echo "down"; fi
			echo -ne "\tnginx 443: "
			if nc -z lazy.wack 443; then echo "up"; else echo "down"; fi
			#		remote_collect lazy
		else echo "offline"; fi
		echo ""
		#goliath.wack
		echo -n "Goliath.."
		if ping -c 1 10.0.0.34 1>/dev/null 2>/dev/null; then
			echo "online"
			echo -ne "\tSickRage: "
			if nc -z 10.0.0.34 8081; then echo "up"; else echo "down"; fi
			echo -ne "\tNFS: "
			if nc -z 10.0.0.34 2049; then echo "up"; else echo "down"; fi
			echo -ne "\tCrypto: "
			if [ -f /drive/drive/.file ]; then echo "mounted"; else echo "!!! not mounted !!!"; fi
			echo -ne "\tRar: "
			if [ -f /mnt/drivefs/.file ]; then echo "mounted"; else echo "!!! not mounted !!!"; fi
			echo -ne "\tPlexbot: "
			if [ "$(ps aux | grep irssi | grep -v "grep" | awk '{print $11}')" = "irssi" ]; then echo "running"; else echo "not running"; fi
			remote_collect goliath
			echo -e "\tNåværende Last:   ↓$curdn ↑$curup"
			echo -e "\tUkentlig trafikk: ↓$rx ↑$tx tot:$ttotal"
			echo -e "\tMånedlig trafikk: $mtotal"
		else echo "offline"; fi
	}
	if [ "$messenger" = "yes" ]; then
		buf="$(mktemp)"
		compact >$buf
		IFS=$'\n'
		for i in $(cat $buf); do
			say "$who :$i"
		done
		rm $buf
	else
		compact
	fi
	;;
'test')
	remote_run plex vnstat
	remote_run torrent ifconfig

	;;
*)
	wan_data="$(ssh kragebein@10.0.0.1 -t sudo ifstat -t 1 eth0 2>/dev/null)"
	wan_data="$(echo "$wan_data" | grep eth0 | sed 's/K//g')"
	main_tx="$(echo "$wan_data" | awk -F ' ' '{print $8}')"
	main_rx="$(echo "$wan_data" | awk -F ' ' '{print $6}')"
	let main_rx=main_rx/100
	let main_tx=main_tx/100
	remote_collect plex
	collect
	if nc -z plex.wack 32400; then
		say "$who :Sist lagt til: $lastadd for $timesince"
		say "$who :$stream_count bruker plex akkurat nå."
	else say "$who :Ooops! Ser ut tell at plex e nede!"; fi
	say "$who :Tid brukt på plex: $playtime"
	say "$who :David Load: $load_david"
	say "$who :Goliath Load: $load_goliath"
	say "$who :Nåværende Last:   ↓${main_rx}kb/S ↑${main_tx}kb/S"
	say "$who :Ukentlig trafikk: ↓$rx ↑$tx tot:$ttotal"
	say "$who :Månedlig trafikk: $mtotal"
	;;
esac
exit
