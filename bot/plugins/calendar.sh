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
regex="^[.]calendar"
uac

_vars() { 
	year="$(echo "$dato" |awk -F "-" '{print $3}')"
	let alder="$(date +%Y)-$year"
	event="$(echo "$event" |sed s"/%alder%/$alder/g")"

}

todays_event() {
	IFS=$'\n'
	for i in $(sql "SELECT id FROM calendar WHERE dato like '$(date +%d-%m)%';"); do
		dato="$(sql "SELECT dato FROM calendar WHERE id='$i';")"
		navn="$(sql "SELECT navn from calendar WHERE id='$i';")"
		event="$(sql "SELECT event from calendar WHERE id='$i';")"
		repeat="$(sql "SELECT gjentakende from calendar WHERE id='$i';")"
		_vars
		say "$announce_channel :I dag skjer det folkens! $navn $event"
		if [ "$repeat" = "no" ]; then
			sql "DELETE from calendar WHERE id='$i'" 
			log n "deleting non-recurring event ($event) from db"
		fi
	done 


}
14days_event() {
	IFS=$'\n'
	for i in $(sql "SELECT id FROM calendar WHERE dato like '$(date --date="14 days" +"%d-%m")%';"); do
		dato="$(sql "SELECT dato FROM calendar WHERE id='$i';")"
		navn="$(sql "SELECT navn from calendar WHERE id='$i';")"
		event="$(sql "SELECT event from calendar WHERE id='$i';")"
		_vars
		say "$announce_channel :Om 2 uke: $navn $event"
	done

}

30days_event() {
	IFS=$'\n'                                                               
	for i in $(sql "SELECT id FROM calendar WHERE dato like '$(date --date="1 month" +"%d-%m")%';"); do
		dato="$(sql "SELECT dato FROM calendar WHERE id='$i';")"
		navn="$(sql "SELECT navn from calendar WHERE id='$i';")"
		event="$(sql "SELECT event from calendar WHERE id='$i';")"
		_vars 
		say "$announce_channel :Om 30 daga: $navn $event"
	done
}
_get_id() {
	mkbuf="$(mktemp)"
	sql "SELECT id FROM calendar;" > $mkbuf
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
# Its its better if we array this and name the string
input=($cmd)
case "${input[1]}" in
    '-r' )
        calendar_date="${input[2]}"
        first_name="${input[3]}"
        last_name="${input[4]}"
        event=""
		req="yes"
		stat="Et gjentakanes event"
        for i in {5..15}; do
            event+="${input[$i]} "
        done ;;
     *)
        calendar_date="${input[1]}"
        first_name="${input[2]}"
        last_name="${input[3]}"
        event=""
		req="no"
		stat="Et engangsevent"
        for i in {4..15}; do
            event+="${input[$i]} "
        done 
esac
case ${input[0]} in 
	'add') 
			if ! date -d "$(echo "$calendar_date" | sed s',\.,/,g' | sed s',-,/,g' |awk -F "/" '{print  $2 "/"  $1 "/" $3}')" > /dev/null 2>&1 ; then
				say "$who :wtf datoformat. 12-12-18 e f.eks okei, $4 e ikke okei. ";exit
			fi
			dato="$(echo "$calendar_date" | sed s',\.,/,g' | sed s',-,/,g' |awk -F "/" '{print  $1 "-"  $2 "-" $3}')"
			req=yes
			navn="$first_name $last_name"
			
				
		_id="$(_get_id)"
		sql "INSERT INTO calendar VALUES('$_id','$dato', '$navn', '$event', '$req');"
		say "$who :$stat vart lagt tell i kalenderen. (#$_id)"
		log n "$dato $navn $event added to calendar"

		exit
		;;
	'delete'|'del')
		if [ "$(sql "select id from calendar where id='${input[1]}';")" != "${input[1]}" ] ; then
			say "$who :fant ikke ei oppføring med id #${input[1]}, bruk .kalender list førr komplett lista over kalenderoppføringe."
		else
			sql "delete from calendar where id='${input[1]}';"
			say "$who :Sletta kalenderoppføring med id #${input[1]}"
			log n "deleted #${input[1]} from db"
		fi
		exit
		;;
	'list')
		IFS=$'\n'
		for i in $(sql "SELECT ID,dato,navn,event FROM calendar";); do
			say "$who :$i"
		done
		exit
		;;
	*)
		#if [ "${input[0]}" = ".calendar" ]; then
		#	exit #stopp kjøring fra chatten
		#fi;;
esac

# kun daglig cron får kom hit
exit
30days_event;14days_event;todays_event
