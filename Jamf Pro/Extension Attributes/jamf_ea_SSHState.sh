#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_SSHState.sh
# By:  Zack Thompson / Created:  10/30/2018
# Version:  1.0 / Updated:  10/30/2018 / By:  ZT
#
# Description:  A Jamf Extension Attribute to grab the Remote Login (SSH) State.
#
###################################################################################################

if [[ $(/usr/sbin/systemsetup -getremotelogin) == "Remote Login: Off" ]]; then
	echo "<result>Disabled</result>"
else
	echo "<result>Enabled</result>"
fi

exit 0