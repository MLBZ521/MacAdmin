#!/bin/bash

###################################################################################################
# Script Name:  disable_AvastNotifications.sh
# By:  Zack Thompson / Created:  11/27/2018
# Version:  1.0 / Updated:  11/27/2018 / By:  ZT
#
# Description:  This script disables Avast Notification pop-ups.
#
###########################################################

echo "*****  disable_AvastNotifications process:  START  *****"

##################################################
# Define Variables

avastKeys=()
avastKeys+=("AlertPopupDuration")
avastKeys+=("InfoPopupDuration")
avastKeys+=("UpdatePopupDuration")
avastKeys+=("WarningPopupDuration")

##################################################
# Bits Staged

for key in ${avastKeys[@]}; do
	echo "Disabling ${key}"
	/usr/bin/su - "${3}" -c "/usr/bin/defaults write /Users/${3}/Library/Preferences/com.avast.helper.plist ${key} -integer 0" 2>&1 /dev/null
	echo -n "  --> Result:  "

	if [[ $? -eq 0 ]]; then
		echo "Success"
	else
		echo "Failed"
		exitCode=1
	fi
done

echo "*****  disable_AvastNotifications process:  COMPLETE  *****"
exit $exitCode