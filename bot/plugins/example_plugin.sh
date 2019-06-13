#!/bin/bash - 

_script="example_script.sh"  # name of this file. For log reasons.
source /drive/drive/.rtorrent/scripts/v3/bot/functions.sh # always call this lib
uac
# You can comment the regex to disable the plugin, but do not put comments behind the line
#regex="^[.]this.{1,3}[0-9]+$"
# this plugin will always be invoked through input.sh in the bot/-directory.
#set the below like this:
if [ -z "$channel" ]; then who="$channel"; fi # This will output to group chat.
who="$who" channel="$channel" cmd="$cmd"      # this will output to whoever did the command.
if [ -z "$who" ]; then log w "\$who unset"; fi
if [ -z "$channel" ]; then channel="$who"; log w "\$channel unset"; fi
if [ -z "$cmd" ]; then log w "\$cmd unset"; fi
# who is the user who triggered the bot, channel is what medium were used, group chat, private message, and cmd is the full command including trigger.
#To interact with the database, you can use db_query with any flavour (well, oracle, mysql, pgsql, sqlite3)
for i in IFS=$'\n' db_query "SELECT * FROM pb WHERE id = '1';"; do
	clk="1"
	declare -A db_arr[$clk]="$i"
	let clk=clk+1
done
#db_query "INSERT INTO pb ($db_arr[@])"
# db_query will always output (but not log) what it has done. 
# You can run oracle blocks $payload, payload() and i_o. 
#payload="${config_path%/*}/q/anonymous_block.sql"
#payload="${payload/%action%/test}"
#i_o # this will run the above block.
echo ${!db_arr[@]}
