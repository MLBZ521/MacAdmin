#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_WiFiSSID.sh
# By:  Zack Thompson / Created:  9/26/2017
# Version:  1.1 / Updated:  10/30/2018 / By:  ZT
#
# Description:  A Jamf Extension Attribute to grab the WiFi SSID.
#
###################################################################################################

wiFiSSID=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | /usr/bin/grep -w 'AirPort\|SSID' | /usr/bin/awk -F ": " '{print $2}')

if [[ -z $wiFiSSID ]]; then
	echo "<result>Not Connected</result>"
else
	echo "<result>${wiFiSSID}</result>"
fi

exit 0