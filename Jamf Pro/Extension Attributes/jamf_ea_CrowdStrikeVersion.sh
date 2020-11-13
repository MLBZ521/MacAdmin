#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_CrowdStrikeVersion.sh
# By:  Zack Thompson / Created:  1/8/2019
# Version:  1.3.0 / Updated:  11/13/2020 / By:  ZT
#
# Description:  This script gets the version of Crowd Strike, if installed.
#
###################################################################################################

echo "Checking if Crowd Strike is installed..."

##################################################
# Possible falconctl binary locations
falconctl_AppLocation="/Applications/Falcon.app/Contents/Resources/falconctl"
falconctl_OldLocation="/Library/CS/falconctl"

##################################################
# Functions

getFalconctlVersion() {

    csAgentInfo=$( "${1}" stats agent_info --plist )

	csVersion=$( /usr/libexec/PlistBuddy -c "Print :agent_info:version" /dev/stdin <<< "$( echo ${csAgentInfo} )" 2> /dev/null )
	plistBuddyExitCode=$?

	if [[ $plistBuddyExitCode -ne 0 ]]; then

        # Get the Crowd Strike version from sysctl for versions prior to v5.36.
        csVersion=$( /usr/sbin/sysctl -n cs.version )
        csVersionExitCode=$?

        if [[ $csVersionExitCode -ne 0 ]]; then

            csVersion="Not Running"

        fi

    fi

	echo "${csVersion}"

}

##################################################
# Bits staged, collect the information...

if  [[ -e "${falconctl_AppLocation}" && -e "${falconctl_OldLocation}" ]]; then

    # Multiple versions installed
    csVersion="ERROR:  Multiple CS Versions installed"

elif  [[ -e "${falconctl_AppLocation}" ]]; then

    csVersion=$( getFalconctlVersion "${falconctl_AppLocation}" )

elif  [[ -e "${falconctl_OldLocation}" ]]; then

    csVersion=$( getFalconctlVersion "${falconctl_OldLocation}" )

else

    csVersion="Not Installed"

fi

echo "<result>${csVersion}</result>"
exit 0