#!/bin/bash - 
#===============================================================================
#
#          FILE: sqlite3.sh
# 
#         USAGE: ./sqlite3.sh 
# 
#   DESCRIPTION: Sqlite3 datafile
# 
#       OPTIONS: 
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 08/31/2019 08:59
#      REVISION:  ---
#===============================================================================
#source /drive/drive/.rtorrent/scripts/v3/bot/functions.sh
# We are called from inside functions.sh, 
dbfile="${pb%/*}/db/sqlite3.sql"
if ! which sqlite3 >/dev/null; then echo "sqlite3 not installed. Install it first";exit
fi
sql3() {
	if ! sqlite3 $dbfile -line "$*" -column |sed s'/      //g' ; then 
	echo "sqlite3 failed writing \"$*\" to $dbfile"
	fi
}

sql3_updatedb() {
	#this will be run under crontab and it will run once a day, every to to keep everything up to date.
	# We can't keep track of everything plex does, so removals etc will have to be updated from this list.
	sqlite3 $dbfile -line "delete from content"
	if $pb/plugins/list_evry_movie.sh; then
		pb $pb/plugins/list_evry_episode.sh
	fi
}


