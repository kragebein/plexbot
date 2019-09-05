#!/bin/bash - 
_script="delete.sh"
source /drive/drive/.rtorrent/scripts/v3/bot/functions.sh
if [ "$channel" != "" ]; then who="$channel";fi
regex="^!delete"
req_admin 

imdbid="${cmd#*\!delete }"
if [ "$imdbid" = '!delete' ]; then
	say "$who :Den her funksjonen krev et imdb-id argument. F.eks !delete tt123456"
	exit
fi

dcheck() {
	sleepdo(){
		sleep 30s
		sql3 "DELETE from deletewarn WHERE who='$who_orig' AND imdbid='$imdbid'"
	}
	sqlwho="$(sql3 "SELECT who FROM deletewarn WHERE imdbid='$imdbid'")"
	#We need to check if this is the first or second time this command has been run.
	if [ "$who_orig" = "$sqlwho" ]; then
		#This is the second run, go ahead and delete this.
		say "$who :Okay. $title bi sletta."

	else
		say "$who :Det her bi å slett $title fra Plex. Gjenta kommando førr å slett."
		sql3 "INSERT INTO deletewarn VALUES('$who_orig','$imdbid')"
		sleepdo&

	fi
}

delete_movie() {
	# Lets grab some data from stuff. 
	case "$(curl -s "$couchpotato/api/$sofa_api/media.get/?id=$imdbid" |jq -r '.media.status')" in
		'active')
			say "$who :Filmen lå kun i wishlist. Fjerna den derfra."
			;;
		'false')
			say "$who :den iden finnes ikke."
			;;
		'done')


			;;
	esac


}

delete_show() {
	say "$who :delete show function"

}
ojson=$(curl -s "http://www.omdbapi.com/?i=$imdbid&apikey=$o_key&type=series")
curl -s "$couchpotato/api/$sofa_api/media.get/?id=$imdbid"
exit
title="$(echo "$ojson" | jq -r '.Title')"
case "$(echo $ojson |jq -r .Type)" in
	'series')
		dcheck
		delete_show;;
	'movie')
		dcheck
		case "$(curl -s "$couchpotato/api/$sofa_api/media.get/?id=$imdbid" |jq -r '.media.status')" in
			'active')say "$who :Filmen lå kun i wishlist. Fjerna den derfra.";;
			'false') say "$who :Filmen fins ikke på Plex.";;
			'done') echo ""
				;;
		esac
		*)
		say "$who :Den IDen der ga ikke nå meining."
esac
