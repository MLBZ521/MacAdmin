#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_SMBProtocol.sh
# By:  Zack Thompson / Created:  7/3/2017
# Version:  1.0 / Updated:  7/3/2017 / By:  ZT
#
# Description:  This script gets the configuration of the SMB Protocol on a Mac.
#
###################################################################################################

echo "Checking the SMB Protocols allowed on this Mac..."

# Check if file exists.
if [[ -e /etc/nsmb.conf ]]; then

	# If it exists, check if the SMB Protocol is set.
	nsmbSMBProtocol=$(cat /etc/nsmb.conf | /usr/bin/grep "sprotocol_vers_map" | awk -F "=" '{print $2}')

	# Check if Protocol is currently configured.
	if [[ -z $nsmbSMBProtocol ]]; then
		# Protocol is not configured...

		# Return 'Not Configured'
		echo "<result>Not Configured</result>"

	elif [[ $nsmbSMBProtocol == "7" ]]; then
		# Return SMBv1_v2_v3
		echo "<result>SMBv1_v2_v3</result>"

	elif [[ $nsmbSMBProtocol == "6" ]]; then
		# Return SMBv2_v3
		echo "<result>SMBv2_v3</result>"

	elif [[ $nsmbSMBProtocol == "4" ]]; then
		# Return SMBv3
		echo "<result>SMBv3</result>"

	elif [[ $nsmbSMBProtocol == "2" ]]; then
		# Return SMBv2
		echo "<result>SMBv2</result>"

	elif [[ $nsmbSMBProtocol == "1" ]]; then
		# Return SMBv1
		echo "<result>SMBv1</result>"

	else
		# Return Unknown
		echo "<result>Unknown Configuration</result>"
	fi
else
	# File does not exist...

	# Return 'Not Configured'
	echo "<result>Not Configured</result>"
fi

exit 0