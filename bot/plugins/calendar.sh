#!/bin/bash - 
#===============================================================================
#
#          FILE: calendar.sh
# 
#         USAGE: .calendar add/del/list
#		  Use Crontab on this file to make it announce everything at 09am
#		  0 09 * * * /path/to/executable/calendar.sh
# 
#   DESCRIPTION: Calendar plugin


source /drive/drive/.rtorrent/scripts/v3/bot/functions.sh
who="$who" cmd="${cmd#.calendar *}" channel="$channel"
_script="calendar.sh"
#regex="^[.]calendar"
uac

_vars() { 
	year="$(echo "$dato" |awk -F "-" '{print $3}')"
	let alder="$(date +%Y)-$year"
	event="$(echo "$event" |sed s"/%alder%/$alder/g")"

}

todays_event() {
	IFS=$'\n'
	for i in $(myq "plexbot SELECT id FROM calendar WHERE dato like '$(date +%d-%m)%';"); do
		dato="$(myq "plexbot SELECT dato FROM calendar WHERE id='$i';")"
		navn="$(myq "plexbot SELECT navn from calendar WHERE id='$i';")"
		event="$(myq "plexbot SELECT event from calendar WHERE id='$i';")"
		repeat="$(myq "plexbot SELECT gjentakende from calendar WHERE id='$i';")"
		_vars
		say "$announce_channel :I dag skjer det folkens! $navn $event"
		if [ "$repeat" = "no" ]; then
			myq "plexbot DELETE from calendar WHERE id='$i'" 
			log n "deleting non-recurring event ($event) from db"
		fi
	done 


}
14days_event() {
	IFS=$'\n'
	for i in $(myq "plexbot SELECT id FROM calendar WHERE dato like '$(date --date="14 days" +"%d-%m")%';"); do
		dato="$(myq "plexbot SELECT dato FROM calendar WHERE id='$i';")"
		navn="$(myq "plexbot SELECT navn from calendar WHERE id='$i';")"
		event="$(myq "plexbot SELECT event from calendar WHERE id='$i';")"
		_vars
		say "$announce_channel :Om 2 uke: $navn $event"
	done

}

30days_event() {
	IFS=$'\n'                                                               
	for i in $(myq "plexbot SELECT id FROM calendar WHERE dato like '$(date --date="1 month" +"%d-%m")%';"); do
		dato="$(myq "plexbot SELECT dato FROM calendar WHERE id='$i';")"
		navn="$(myq "plexbot SELECT navn from calendar WHERE id='$i';")"
		event="$(myq "plexbot SELECT event from calendar WHERE id='$i';")"
		_vars 
		say "$announce_channel :Om 30 daga: $navn $event"
	done
}
_get_id() {
	mkbuf="$(mktemp)"
	myq "plexbot SELECT id FROM calendar;" > $mkbuf
	available() {
		if [ "$rand"  = "" ]; then 
			check
		else
			printf "%s" "$rand"
		fi

	}
	reiterate() {
		rand="$(echo $(($RANDOM % 9999)))"
		if  egrep -w "^$rand" $mkbuf 1>/dev/null ;then check; else  available; fi

	}
	check() {
		rand="$(echo $(($RANDOM % 9999)))"
		if egrep -w "^$rand" $mkbuf 1>/dev/null ;then  reiterate; else  available; fi

	}
	check
	rm $mkbuf
}

case ${cmd%% *} in 
	'add') 
	input=""
		if [ "$3" = "-r" ]; then #fløtt alt ett hakk tell høyre
			if ! date -d "$(echo "$4" | sed s',\.,/,g' | sed s',-,/,g' |awk -F "/" '{print  $2 "/"  $1 "/" $3}')" > /dev/null 2>&1 ; then
				say "$who :wtf datoformat. 12-12-18 e f.eks okei, $4 e ikke okei. ";exit
			fi
			dato="$(echo "$4" | sed s',\.,/,g' | sed s',-,/,g' |awk -F "/" '{print  $1 "-"  $2 "-" $3}')"
			req=yes
			navn="$5 $6"
			event="$(echo "$*" |awk -F "$6" '{print $2}')"
			stat="Et gjentakanes event"
		else
			if ! date -d "$(echo "$3" | sed s',\.,/,g' | sed s',-,/,g' |awk -F "/" '{print  $2 "/"  $1 "/" $3}')" > /dev/null 2>&1 ; then
				say "$who :wtf datoformat. 12-12-18 e f.eks okei, $3 e ikke okei. ";exit
			fi
			dato="$(echo "$3" | sed s',\.,/,g' | sed s',-,/,g' |awk -F "/" '{print  $1 "-"  $2 "-" $3}')"
			req=no
			event="$(echo "$*" |awk -F "$5" '{print $2}')"
			navn="$4 $5"
			stat="Et engangsevent"
		fi
		_id="$(_get_id)"
		myq "plexbot INSERT INTO calendar VALUES('$_id','$dato', '$navn', '$event', '$req');"
		say "$who :$stat vart lagt tell i kalenderen. (#$_id)"
		log n "$dato $navn $event added to calendar"

		exit
		;;
	'delete'|'del')
		if [ "$(myq "plexbot select id from calendar where id='$3';")" != "$3" ] ; then
			say "$who :fant ikke ei oppføring med id #$3, bruk .kalender list førr komplett lista over kalenderoppføringe."
		else
			myq "plexbot delete from calendar where id='$3';"
			say "$who :Sletta kalenderoppføring med id #$3"
			log n "deleted #$3 from db"
		fi
		exit
		;;
	'list')
		IFS=$'\n'
		for i in $(myq "plexbot SELECT ID,dato,navn,event FROM calendar";); do
			say "$who :$i"
		done
		exit
		;;
	*)
		if [ "$1" = ".kalender" ]; then
			exit #stopp kjøring fra chatten
		fi;;
esac

# kun daglig cron får kom hit
exit
30days_event;14days_event;todays_event
