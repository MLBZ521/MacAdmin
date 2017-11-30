#!/bin/bash

###################################################################################################
# Script Name:  jamf_policyCaller.sh
# By:  Zack Thompson / Created:  11/30/2017
# Version:  1.0 / Updated:  11/30/2017 / By:  ZT
#
# Description:  This script uses JSS Parameters to run multiple custom triggers and/or Policy IDs.
# 		(JSS does not currently support multiple custom triggers in a single Policy, so this is a workaround for that.)
#
# Inspired by:  @mm2270 - https://www.jamf.com/jamf-nation/feature-requests/2337/multiple-custom-events-per-policy
#
###################################################################################################

/bin/echo "*****  policyCaller Process:  START  *****"
/bin/echo "Calling provided parameters..."

# If custom triggers are provided, loop through them.
if [[ -n $4 ]]; then
	IFS=", " read customTriggers <<< $4
		for customTrigger in $customTriggers; do
			/bin/echo "Calling Policies that use the custom trigger:  ${customTrigger}"
			/usr/local/bin/jamf policy -trigger $customTrigger
		done
fi

# If Policy IDs are provided, loop through them.
if [[ -n $5 ]]; then
	IFS=", " read policyIDs <<< $5
		for policyID in $policyIDs; do
			/bin/echo "Calling Policy ID:  ${policyID}"
			/usr/local/bin/jamf policy -id $policyID
		done
fi

/bin/echo "All policies have been processed."
/bin/echo "*****  policyCaller Process:  COMPLETE  *****"

exit 0
