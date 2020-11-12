#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_CrowdStrikeVersion.sh
# By:  Zack Thompson / Created:  1/8/2019
# Version:  1.2.0 / Updated:  11/10/2020 / By:  ZT
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

	/usr/libexec/PlistBuddy -c "Print :agent_info:version" /dev/stdin <<< "$( echo ${csAgentInfo} )"

}

##################################################
# Bits staged, collect the information...

if  [[ -e "${falconctl_AppLocation}" && -e "${falconctl_OldLocation}" ]]; then

    # Multiple versions installed
    echo "<result>ERROR:  Multiple CS Versions installed</result>"
    exit 0

elif  [[ -e "${falconctl_AppLocation}" ]]; then

    csVersion=$( getFalconctlVersion "${falconctl_AppLocation}" )

elif  [[ -e "${falconctl_OldLocation}" ]]; then

    csVersion=$( getFalconctlVersion "${falconctl_OldLocation}" )

else

    echo "<result>Not Installed</result>"
    exit 0

fi

if [[ -z "${csVersion}" ]]; then

	# Get the Crowd Strike version from sysctl for versions prior to v5.36.
	csVersion=$( /usr/sbin/sysctl -n cs.version )
	csVersionExitCode=$?

	if [[ $csVersionExitCode -ne 0 ]]; then

		echo "<result>Not Running</result>"

	fi

else

	echo "<result>${csVersion}</result>"

fi

exit 0