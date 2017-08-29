#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_SMBProtocol.sh
# By:  Zack Thompson / Created:  7/3/2017
# Version:  2.0 / Updated:  7/19/2017 / By:  ZT
#
# Description:  This script gets the configuration of the SMB Protocol on a Mac.
#
###################################################################################################

/bin/echo "Checking the SMB Protocols allowed on this Mac..."

##################################################
# Define Variables
OSVersion=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F . '{print $1"."$2}')

if [[ $OSVersion == 10.12 ]]; then
    smbKey="sprotocol_vers_map"
else
    smbKey="smb_neg"
fi
##################################################

# Check if file exists.
if [[ -e /etc/nsmb.conf ]]; then

    # If it exists, check if the SMB Protocol is set.
    nsmbSMBProtocol=$(/bin/cat /etc/nsmb.conf | /usr/bin/grep "$smbKey" | /usr/bin/awk -F "=" '{print $2}')

    # Check if Protocol is currently configured.
    if [[ -z $nsmbSMBProtocol ]]; then
        # Protocol is not configured...

        # Return 'Not Configured'
        /bin/echo "<result>Not Configured</result>"

    elif [[ $nsmbSMBProtocol == "7" ]]; then
        # Return SMBv1_v2_v3
        /bin/echo "<result>SMBv1_v2_v3</result>"

    elif [[ $nsmbSMBProtocol == "6" ]]; then
        # Return SMBv2_v3
        /bin/echo "<result>SMBv2_v3</result>"

    elif [[ $nsmbSMBProtocol == "4" ]]; then
        # Return SMBv3
        /bin/echo "<result>SMBv3</result>"

    elif [[ $nsmbSMBProtocol == "2" ]]; then
        # Return SMBv2
        /bin/echo "<result>SMBv2</result>"

    elif [[ $nsmbSMBProtocol == "1" ]]; then
        # Return SMBv1
        /bin/echo "<result>SMBv1</result>"
    elif [[ $nsmbSMBProtocol == "normal" ]]; then
        # Return SMBv1_v2
        /bin/echo "<result>SMBv1_v2</result>"

    elif [[ $nsmbSMBProtocol == "smb1_only" ]]; then
        # Return SMBv1
        /bin/echo "<result>SMBv1</result>"

    elif [[ $nsmbSMBProtocol == "smb2_only" ]]; then
        # Return SMBv2
        /bin/echo "<result>SMBv2</result>"

    else
        # Return Unknown
        /bin/echo "<result>Unknown Configuration</result>"
    fi
else
    # File does not exist...

    # Return 'Not Configured'
    /bin/echo "<result>Not Configured</result>"
fi

exit 0