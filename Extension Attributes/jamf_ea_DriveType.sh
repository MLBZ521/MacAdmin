#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_DriveType.sh
# By:  Zack Thompson / Created:  10/30/2018
# Version:  1.1.0 / Updated:  12/11/2018 / By:  ZT
#
# Description:  A Jamf Extension Attribute to grab the Drive Type (i.e. Solid State, Rotational, or Fusion Drive).
#
###################################################################################################

# Get the Boot Drive.
bootDisk=$(/usr/sbin/bless --info --getBoot)

# Check Boot Drive for drive type characteristics.
if [[ $( /usr/sbin/diskutil info $bootDisk | /usr/bin/awk -F "Fusion Drive:" '{print $2}' | /usr/bin/xargs ) == "Yes" ]]; then
	echo "<result>Fusion Drive</result>"
elif [[ $( /usr/sbin/diskutil info $bootDisk | /usr/bin/awk -F "Solid State:" '{print $2}' | /usr/bin/xargs ) == "Yes" ]]; then
	echo "<result>Solid State</result>"
else
	echo "<result>Rotational</result>"
fi

exit 0