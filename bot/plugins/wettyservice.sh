#!/bin/bash - 
#===============================================================================
#
#          FILE: wettyservice.sh
# 
#         USAGE: ./wettyservice.sh 
# 
#   DESCRIPTION: 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 04/21/2019 11:36
#      REVISION:  ---
#===============================================================================

#set -o nounset                              # Treat unset variables as an error
_script="wettyservice.sh"
regex="^wetty"
req_admin # this plugin requires admin privs
source /drive/drive/.rtorrent/scripts/master.sh
pid="$(pgrep -u root node)" #pid of wetty service
argument="${cmd#wetty *}"
case $argument in
	'status')
		if [ "$pid" = "" ]; then
			say "$who :Wetty service is currently stopped."
		else
			say "$who :wetty service is currently running."
		fi;;
	'start')
		if [ "$pid" = "" ]; then
			if wettystart; then
				say "$who :Started wetty service"
			else
				say "$who :Could not start wetty service. Already running"
			fi
		fi;;
	'stop')
		if [ "$pid" != "" ]; then
			if sudo kill $pid; then
				say "$who :stopped wetty service"
			else
				say "$who :could not stop wetty servic. Already runninge"
			fi

		fi;;
	*)
		say "$who :Usage: wetty (status|start|stop)";;
esac





