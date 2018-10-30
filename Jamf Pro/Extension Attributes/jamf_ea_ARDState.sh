#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_ARDState.sh
# By:  Zack Thompson / Created:  10/30/2018
# Version:  1.0 / Updated:  10/30/2018 / By:  ZT
#
# Description:  A Jamf Extension Attribute to grab the Remote Management (ARD) State.
#
###################################################################################################

if [[ $(/bin/ps ax | /usr/bin/grep --count --ignore-case "[Aa]rdagent") -eq 1 ]]; then
	echo "<result>Enabled</result>"
else
	echo "<result>Disabled</result>"
fi

exit 0