#!/bin/bash

###################################################################################################
# Script Name:  license_Antidote.sh
# By:  Zack Thompson / Created:  10/13/2020
# Version:  1.0.0 / Updated:  10/13/2020 / By:  ZT
#
# Description:  This script applies a license for Antidote.  (Only tested on v9.5)
#
###################################################################################################

echo -e "*****  License Antidote process:  START  *****\n"

##################################################
# Define Variables

exitCode=0
plist_Antidote="/Library/Preferences/com.druide.Antidote.plist"
cleActivation="${4}"
codeQuota="${5}"
compagnie="${6}"
noDeSerie="${7}"
nom="${8}"
prenom="${9}"

##################################################
# Define Functions

# This is a helper function to interact with plists.
PlistBuddyHelper() {

    key="${1}"
    type="${2}"
    value="${3}"
    plist="${4}"
    action="${5}"

    # Delete existing values if required
    if [[ "${action}" = "delete"  ]]; then
        /usr/libexec/PlistBuddy -c "Delete :${key} ${type}" "${plist}" > /dev/null 2>&1
    fi

    # Configure values
    /usr/libexec/PlistBuddy -c "Add :${key} ${type} ${value}" "${plist}"  > /dev/null 2>&1 || /usr/libexec/PlistBuddy -c "Set :${key} ${value}" "${plist}" > /dev/null 2>&1

}

##################################################
# Bits staged...

# Verify values for the required parameteres were passed
if [[ -z "${cleActivation}" || -z "${codeQuota}" || -z "${noDeSerie}" || -z "${nom}" || -z "${prenom}" ]]; then
    echo -e "Error:  One or more required parameter values were not provided.\n"
    echo "*****  License Antidote Process:  FAILED  *****"
    exit 1
fi

echo "Writing the passed licensing info..."

PlistBuddyHelper "enregistrement-9:cleActivation" "string" "${cleActivation}" "${plist_Antidote}"
exitCode=$(( $exitCode + $? ))
PlistBuddyHelper "enregistrement-9:codeQuota" "string" "${codeQuota}" "${plist_Antidote}"
exitCode=$(( $exitCode + $? ))
PlistBuddyHelper "enregistrement-9:compagnie" "string" "${compagnie}" "${plist_Antidote}"
exitCode=$(( $exitCode + $? ))
PlistBuddyHelper "enregistrement-9:noDeSerie" "string" "${noDeSerie}" "${plist_Antidote}"
exitCode=$(( $exitCode + $? ))
PlistBuddyHelper "enregistrement-9:nom" "string" "${nom}" "${plist_Antidote}"
exitCode=$(( $exitCode + $? ))
PlistBuddyHelper "enregistrement-9:prenom" "string" "${prenom}" "${plist_Antidote}"
exitCode=$(( $exitCode + $? ))

# Verify each step successfully completed.
if [[ $exitCode -ne 0 ]]; then
    echo -e "Error:  Failed to write licensing values.\n"
    echo "*****  License Antidote Process:  FAILED  *****"
    exit 2
fi

echo -e "Antidote has been licensed!\n"
echo "*****  License Antidote Process:  COMPLETE  *****"
exit 0