#!/bin/bash - 
#===============================================================================
#
#          FILE: shirc.sh
# 
#         USAGE: ./shirc.sh 
# 
#   DESCRIPTION: 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 04/25/2019 19:12
#      REVISION:  ---
#===============================================================================
shost="localhost"
sport="6667"
snick="testnick"
ssl="no"
input="/drive/drive/.rtorrent/scripts/v3/bot/input.sh" # input parser

trap echo "sigint"
#trap kill 0 "sigint"

if [[ $ssl == "yes" ]]; then
	socat STDIO OPENSSL:$shost:$sport,verify=0
fi
if [[ $ssl == "no" ]]; then
	connect() { exec 3<>/dev/tcp/$shost/$sport || exit 1; }
fi

connect 
{
	while read sdata; do
		_date="$(date +'<%H:%M:%S>')"
		[[ ${_line:0:1} == ":" ]] && _source="${_line%% *}" && _line="${_line#* }"
		_source="${_source:1}"
		_user=${_source%%\!*}
		_txt="${_line#*:}"
		printf "$sdata" >&2

	done

} <&3 &
