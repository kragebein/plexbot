#!/bin/bash
_script="rejoinchat.sh"
regex="^rejoinchat"
uac 
source /drive/drive/.rtorrent/scripts/v3/bot/functions.sh 
log n "Rejoinchat triggered by $who"
say "$who :Okay. Rejoining"
say "&bitlbee :fbchat"
sleep 2s
say "&bitlbee :fbjoin 1 #gruppa"
say "&bitlbee :fbjoin 2 #plexbot_"
say "&bitlbee :fbjoin 3 #log"
exit 1

