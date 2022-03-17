#!/bin/bash

###################################################################################################
# Script Name:  Get-LastUser.sh
# By:  Zack Thompson / Created:  10/30/2018
# Version:  1.1.0 / Updated:  3/17/2022 / By:  ZT
#
# Description:  A Jamf Extension Attribute that displays the last user to log in.
#
###################################################################################################

last_user=$( /usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk '/Name :/ && ! /loginwindow/ { print $3 }' )

if [[ -z $last_user ]]; then
	echo "<result>No logins</result>"
else
	echo "<result>${last_user}</result>"
fi

exit 0