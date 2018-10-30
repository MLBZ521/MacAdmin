#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_FileSystemType.sh
# By:  Zack Thompson / Created:  10/30/2018
# Version:  1.0 / Updated:  10/30/2018 / By:  ZT
#
# Description:  A Jamf Extension Attribute to grab the File System Type (or "Personality").
#
###################################################################################################

echo "<result>$(/usr/sbin/diskutil info / | /usr/bin/awk -F "File System Personality:" '{print $2}' | /usr/bin/xargs)</result>"

exit 0