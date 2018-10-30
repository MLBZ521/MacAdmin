#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_RecoveryHD.sh
# By:  Zack Thompson / Created:  10/30/2018
# Version:  1.0 / Updated:  10/30/2018 / By:  ZT
#
# Description:  A Jamf Extension Attribute that displays whether the Recovery Volume is present.
#
###################################################################################################

if [[ -z $(/usr/sbin/diskutil list | /usr/bin/grep -w 'Recovery HD\|APFS Volume Recovery') ]] ; then
	echo "<result>Not Present</result>"
else
	echo "<result>Present</result>"
fi

exit 0