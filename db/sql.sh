#!/bin/bash
# SQL query selector.
_script="sql.log"
case "$db" in
'mysql')

    sql() {
        if ! which mysql >/dev/null; then
            echo "mysql not installed. Install it first"
            exit
        fi
        # syntax: myq "databasenavn select blah from blah where blah osvosv" avslutt med ;"
        db=$(echo "$*" | awk -F " " '{print $1}')
        query=$(echo "$*" | awk -F "$db " '{print $2}')
        mysql --login-path=local -D "$db" -s -s -N -e "$query;"
        log n "mysql: $query"
    }
    ;;
'sqlite3')

    sql() {
        dbfile="${pb%/*}/db/sqlite3.sql"
        if ! which sqlite3 >/dev/null; then
            echo "sqlite3 not installed. Install it first"
            exit
        fi
        if ! sqlite3 "$dbfile" -line "$*" -column | sed s'/      //g'; then
            echo "sqlite3 failed writing \"$*\" to $dbfile"
        fi
       log n "sqlite: $*" 
    }
    ;;

'oracle')
    block() {
        echo "CONNECT $oracle_user/$oracle_password@$oracle_host/XE"
        echo "set serveroutput on"
        echo "set feedback off"
        echo "$*"
        echo "."
        echo "/"
    }
    sql() {
        if ! which sqlplus >/dev/null; then
            echo "sqlplus (Oracle client) is not installed. Install it first"
            exit
        fi
        block "$@" | sqlplus -S /nolog | tr -d '\n'
        log n "oracle: $*"
    }
    ;;
'postgresql')
    sql() {
        # TODO
        exit
        log n "pgsql: $*"
    }
    ;;
esac
