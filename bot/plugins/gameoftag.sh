#!/bin/bash - 
source /drive/drive/.rtorrent/scripts/master.sh
# gameoftagv2, moved game logic into db. 
_script="gameoftag.sh"
regex="^[.](tag)"
uac
#while getopts "u:c:m:" flag; do case $flag in u) player="$OPTARG";; c) channel="$OPTARG";; m) action="$OPTARG";;esac;done
who="$who" cmd="${cmd#.tag *}" channel="$channel"
player="$who"
action="${cmd/.tag/}"
if [ "$action" = "help" ]; then
	say "$player :AGOT helpline."
	say "$player :.tag register - registrer deg."
	say "$player :.tag unregister - avregistrer deg."
	say "$player :.tag vil i februar registrer at du har gitt bort en tag, funk kun dersom du e registrert speller, utenom februar vil du kun faa opp kem som har aarets tag."
	exit;
fi
payload() {
	oracle_login
	payload="$(cat /drive/drive/.rtorrent/scripts/v3/q/gameoftag.sql)"
	payload="${payload/\%action_player\%/$player}"
	payload="${payload/\%input\%/$action}"
	echo "$payload"
}
i_o() {
	export LD_LIBRARY_PATH=/opt/oracle/instantclient_18_5/
	say $(payload | sqlplus -S /NOLOG)
}
i_o
