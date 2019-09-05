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
source /drive/drive/.rtorrent/scripts/v3/bot/functions.sh
db="${pb%/*}/db/sqlite3.sql"
if ! sqlite3; echo "sqlite3 not installed. Install it first";exit
fi

#   if ! sqlite3 $db -line "SELECT * FROM content"; then 
#	sqlite3 $db -line "CREATE TABLE content ('imdbid' TEXT, 'rating_key' TEXT, 'file' TEXT)"
#	sqlite3 $db -line "CREATE TABLE power"


sql3() {
	db="${pb%/*}/db/sqlite3.sql"
	sqlite3 $db -line "$*" -column
	echo "sqlite3 writing to $db: $*"
}

sql3_updatedb() {
	#this will be run under crontab and it will run once a day, every to to keep everything up to date.
	# We can't keep track of everything plex does, so removals etc will have to be updated from this list.
	db="${pb%/*}/db/sqlite3.sql" 
	sqlite3 $db -line "delete from content" -column
	if $pb/plugins/list_evry_movie.sh then;
		pb $pb/plugins/list_evry_episode.sh
	fi


}


