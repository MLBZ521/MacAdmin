#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_CrowdStrikeVersion.sh
# By:  Zack Thompson / Created:  1/8/2019
# Version:  1.4.0 / Updated:  12/1/2021 / By:  ZT
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

write_to_log() {

    local_ea_history="/opt/ManagedFrameworks/EA_History.log"
    message="${1}"
    time_stamp=$( /bin/date +%Y-%m-%d\ %H:%M:%S )
    echo "${time_stamp}:  ${message}" >> "${local_ea_history}"
}

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

write_to_log "CS:F Version:  ${cs_version}"
echo "<result>${cs_version}</result>"
exit 0