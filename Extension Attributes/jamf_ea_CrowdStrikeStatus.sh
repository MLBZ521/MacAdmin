#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_CrowdStrikeStatus.sh
# By:  Zack Thompson / Created:  1/8/2019
# Version:  1.0.0 / Updated:  1/8/2019 / By:  ZT
#
# Description:  This script gets the configuration of Crowd Strike.
#
###################################################################################################

echo "Checking the Crowd Strike configuration..."

##################################################
# Define Variables for each item that we want to check for
customerID="12345678-90AB-CDEF-1234-567890ABCDEF"
cloudConnectionState="102"
# A value of 102 indicates the host is connected directly to the CrowdStrike cloud.
# A value of 126 indicates the host is connected to the CrowdStrike cloud via a proxy.

# Get the current values for the items we want to check
csCustomerID=$( /usr/sbin/sysctl -n cs.customerid 2>&1 )
csCloudConnectionState=$( /usr/sbin/sysctl -n cs.comms.cloud_connection_state 2>&1 )
kextsEnabled=$( /usr/bin/sqlite3 /var/db/SystemPolicyConfiguration/KextPolicy "select * from kext_policy where team_id='X9E956P446' and allowed='0';" | /usr/bin/wc -l | /usr/bin/xargs )

# Hold statuses
returnResult=""

##################################################
# Bits staged, collect the information...

if [[ "${csCustomerID}" != "${customerID}" ]]; then
    returnResult+="Invalid Customer ID;" 
fi

if [[ "${csCloudConnectionState}" != "${cloudConnectionState}" ]]; then
    returnResult+=" Disconnected State;" 
fi

if [[ "${kextsEnabled}" != "2" ]]; then
    returnResult+=" KEXTs are not enabled;" 
fi

##################################################
# Return any errors or the all good.

if [[ -n "${returnResult}" ]]; then
	echo "<result>${returnResult%?}</result>"
else
	echo "<result>Running</result>"
fi

exit 0