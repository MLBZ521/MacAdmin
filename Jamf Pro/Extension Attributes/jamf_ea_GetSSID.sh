#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_GetSSID.sh
# By:  Zack Thompson / Created:  9/26/2017
# Version:  1.0 / Updated:  9/26/2017 / By:  ZT
#
# Description:  A Jamf Extension Attribute to grab the WiFi SSID.
#
###################################################################################################

wiFiSSID=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep -w 'AirPort\|SSID' | awk -F ": " '{print $2}')

if [[ -z $wiFiSSID ]]; then
	echo "<result>Not Connected</result>"
else
	echo "<result>$wiFiSSID</result>"
fi

exit 0