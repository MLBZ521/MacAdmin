#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_FirewallState.sh
# By:  Zack Thompson / Created:  10/30/2018
# Version:  1.0 / Updated:  10/30/2018 / By:  ZT
#
# Description:  A Jamf Extension Attribute to grab the Firewall State.
#
###################################################################################################

if [[ $(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate) == "Firewall is disabled. (State = 0)" ]]; then
	echo "<result>Disabled</result>"
else
	echo "<result>Enabled</result>"
fi

exit 0