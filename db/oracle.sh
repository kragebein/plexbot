#!/bin/bash - 
#===============================================================================
#
#          FILE: db_oracle.sh
# 
#         USAGE: ./db_oracle.sh 
# 
#   DESCRIPTION: 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 03/28/2019 12:43
#      REVISION:  ---
#===============================================================================
source /drive/drive/.rtorrent/scripts/master.sh
_script="db_oracle.sh"
block() {
	oracle_login
	echo "$*"
	echo "."
	echo "/"
}


payload() {
	block | sqlplus -S /nolog | tr -d '\n' 
	#	echo "$(block)"

}


db_query() {
	oracle_login
	$* | sqlplus -S /nolog |tr -d '\n'

}
