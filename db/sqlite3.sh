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
sql3() {
	_script="sql.log"
	dbfile="${pb%/*}/db/sqlite3.sql"
	if ! which sqlite3 >/dev/null; then
		echo "sqlite3 not installed. Install it first"
		exit
	fi
	if ! sqlite3 "$dbfile" -line "$*" -column | sed s'/      //g'; then
		echo "sqlite3 failed writing \"$*\" to $dbfile"
	fi
	log n "sql: $*"
}

