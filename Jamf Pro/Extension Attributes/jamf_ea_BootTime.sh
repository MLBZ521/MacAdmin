#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_BootTime.sh
# By:  Zack Thompson / Created:  8/24/2019
# Version:  1.0.0 / Updated:  8/24/2019 / By:  ZT
#
# Description:  A Jamf Pro Extension Attribute to get the boot time of a device.
#
###################################################################################################

bootTime=$( /usr/sbin/sysctl kern.boottime | /usr/bin/awk '{print $5}' | /usr/bin/tr -d , )

bootTimeFormatted=$( /bin/date -jf %s $bootTime +%F\ %T )

echo "<result>$bootTimeFormatted</result>"

exit 0