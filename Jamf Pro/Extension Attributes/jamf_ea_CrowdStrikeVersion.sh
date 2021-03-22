#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_CrowdStrikeVersion.sh
# By:  Zack Thompson / Created:  1/8/2019
# Version:  1.3.1 / Updated:  3/22/2021 / By:  ZT
#
# Description:  This script gets the version of Crowd Strike, if installed.
#
###################################################################################################

echo "Checking if Crowd Strike is installed..."

##################################################
# Possible falconctl binary locations
falconctl_app_location="/Applications/Falcon.app/Contents/Resources/falconctl"
falconctl_old_location="/Library/CS/falconctl"

#############################################n#####
# Functions

get_falconctl_version() {

    csAgentInfo=$( "${1}" stats agent_info --plist )

	cs_version=$( /usr/libexec/PlistBuddy -c "Print :agent_info:version" /dev/stdin <<< "${csAgentInfo}" 2> /dev/null )
	plistBuddy_exit_code=$?

	if [[ $plistBuddy_exit_code -ne 0 ]]; then

        # Get the Crowd Strike version from sysctl for versions prior to v5.36.
        cs_version=$( /usr/sbin/sysctl -n cs.version )
        cs_version_exit_code=$?

        if [[ $cs_version_exit_code -ne 0 ]]; then

            cs_version="Not Running"

        fi

    fi

	echo "${cs_version}"

}

##################################################
# Bits staged, collect the information...

if  [[ -e "${falconctl_app_location}" && -e "${falconctl_old_location}" ]]; then

    # Multiple versions installed
    cs_version="ERROR:  Multiple CS Versions installed"

elif  [[ -e "${falconctl_app_location}" ]]; then

    cs_version=$( get_falconctl_version "${falconctl_app_location}" )

elif  [[ -e "${falconctl_old_location}" ]]; then

    cs_version=$( get_falconctl_version "${falconctl_old_location}" )

else

    cs_version="Not Installed"

fi

echo "<result>${cs_version}</result>"
exit 0