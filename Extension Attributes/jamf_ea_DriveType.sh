#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_DriveType.sh
# By:  Zack Thompson / Created:  10/30/2018
# Version:  1.0 / Updated:  10/30/2018 / By:  ZT
#
# Description:  A Jamf Extension Attribute to grab the Drive Type (i.e. Solid State or Rotational).
#
###################################################################################################

echo "<result>$(/usr/sbin/system_profiler SPSerialATADataType | /usr/bin/grep "Medium Type" | /usr/bin/sed -e 's/^[Medium\ Type:\ ]*//')</result>"

exit 0