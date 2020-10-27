#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_RecoveryHD.sh
# By:  Zack Thompson / Created:  10/30/2018
# Version:  1.1.0 / Updated:  10/21/2020 / By:  ZT
#
# Description:  A Jamf Extension Attribute that displays whether the Recovery Volume is present.
#
###################################################################################################

# Get the Boot Drive.
bootDisk=$( /usr/sbin/bless --info --getBoot )

if [[ -z $( /usr/sbin/diskutil info "${bootDisk}" | /usr/bin/grep 'Recovery' ) ]] ; then

	echo "<result>Not Present</result>"

else

	echo "<result>Present</result>"

fi

exit 0