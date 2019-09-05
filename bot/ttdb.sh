#!/bin/bash - 
#===============================================================================
#
#          FILE: ttdb.sh
# 
#         USAGE: ./ttdb.sh tt12345678 
# 
#	  ABOUT: Will reverse print ID from thetvdb. You input imdbid, it gives you ttdbid, you input ttdbit, it prints imdbid
#  REQUIREMENTS: jq, curl 
#          BUGS: none
#         NOTES: n/a
#        AUTHOR: krage, 
#  ORGANIZATION: goliath
#       CREATED: 05/22/2018 11:00
#      REVISION:  1.0
#===============================================================================
#ttdb_user="changeme"
#ttdb_ukey="changeme"
#ttdb_api="changeme"
ttdb_token="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE1NTU4NDkzMjksImlkIjoiUGxleGJvdGEiLCJvcmlnX2lhdCI6MTU1NTc2MjkyOSwidXNlcmlkIjo0NDk3NDksInVzZXJuYW1lIjoia3JhZ2UifQ.fTFd8dgR_TBc94IrNrOUNXKCc1Re20wHVoqKbKlChdMZGzNg2Tkc2FgcXWuCw5HiyBsP8tl9BSHzPP_74rHmtx6ipYkYTRl3ogTB8dqoNjpuBzOfOnEFLdBvQmtLYV30T2A73HbTppei6XvOXGCS1TtRLBjzwL6ErztfATjUJ9-2uw1fHJciToMsCEyQqOyqLIkblJjgRgc4yLlqkdYSFeixoUtQ1nJrbGe9vKoZVvQW8eTrUoH-fcFgaqyj0yQKScjugP_WJgOosRxAJcX497Y1dB0o5W0UYZ_mimop9h7AqpMIzHlLOLHPEE05R3c025rFDifWeXnnygGU1bGBIA"
_script="ttdb.sh"
source config.cfg
rewrite() {
	buffer=$(mktemp)
	cat $config_path/config.cfg | sed "s/ttdb_token=\"$ttdb_token\"/ttdb_token=\"$key\"/g" >$buffer
	mv -f $buffer $config_path/config.cfg;chmod +x $config_path/config.cfg

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
				get_key
				$0 $*;;
			'Resource not found')
				exit;;      # ttdbid not found
			*)
				echo "ERROR: $json" 
				exit
				;;
		esac
	fi

}
input="$1"



if [[ "$input" =~ ^.t.{0,9} ]]; then
	json="$(curl -s -X GET --header 'Accept: application/json' --header "Authorization: Bearer $ttdb_token" "https://api.thetvdb.com/search/series?imdbId=$input" |  sed 's/\\r//g' | sed s'/\\n//')"
	check "$json";echo -ne "$json" |jq '.data[0].id'
else
	json="$(curl -s -X GET --header 'Accept: application/json' --header "Authorization: Bearer $ttdb_token" "https://api.thetvdb.com/series/$input" |  sed 's/\\r//g' | sed s'/\\n//g')"
	check "$json";echo -ne "$json" |jq -r '.data.imdbId'
fi

if [ "$2" = "-r" ]; then
	echo "$json";exit
fi
if [ "$1" = "tt8421350" ]; then
	echo "349271";exit
fi

