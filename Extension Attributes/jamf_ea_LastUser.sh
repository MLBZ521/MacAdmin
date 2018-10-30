#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_LastUser.sh
# By:  Zack Thompson / Created:  10/30/2018
# Version:  1.0 / Updated:  10/30/2018 / By:  ZT
#
# Description:  A Jamf Extension Attribute that displays the last user to log in.
#
###################################################################################################

lastUser=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')

if [[ -z $lastUser ]]; then
	echo "<result>No logins</result>"
else
	echo "<result>${lastUser}</result>"
fi

exit 0