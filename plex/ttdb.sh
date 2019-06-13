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
ttdb_token="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE1NTU3MzkxOTMsImlkIjoiUGxleGJvdGEiLCJvcmlnX2lhdCI6MTU1NTY1Mjc5MywidXNlcmlkIjo0NDk3NDksInVzZXJuYW1lIjoia3JhZ2UifQ.15x6n-S-PQ_NBOtZ-bCy7S12YMbYsAH3EK0yUV-TKUYKhG_K7J3q5mDtvt9J4PepIMXRVcVmYYLNf7pPvJonbQm7K2aS1cz6MOBCRSxO4S34udmptLMTxO8anHrg6_ESSLgq0dcFdqjgyK4qdL2wq3bzA4b4cnf3kk9iDzcbFDJfoqf4aZfsTrgBN4_RPm5iftXXTk6im8OTZyL-m9l1bRUHuIuQ7EXKEg2y33fjH5Cr8xcwmMfC5J8IWto3CxbAdJqwg6dJRijxkDLV5jjm7jkdnitnxoClGww-vCNMDhgfzgD4u0LmwB4NMqqtR11wp_o0EaTTQ3TKBskp44EdnQ"
_script="ttdb.sh"
source /drive/drive/.rtorrent/scripts/master.sh
rewrite() {
	self="/drive/drive/.rtorrent/scripts/v3/plex/ttdb.sh"
	# rewrite token
	buffer=$(mktemp)
	cat $self | sed "s/ttdb_token=\"$ttdb_token\"/ttdb_token=\"$key\"/g" >$buffer
	mv -f $buffer $self;chmod +x $self

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
	if [ "$_test" != "null" ]; then
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
if [[ "$input" =~ ^[a-z].?[0-9].* ]]; then
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

