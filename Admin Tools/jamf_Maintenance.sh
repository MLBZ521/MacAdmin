#!/bin/bash

###################################################################################################
# Script Name:  jamf_Maintenance.sh
# By:  Zack Thompson / Created:  9/15/2017
# Version:  1.3.1 / Updated:  7/2/2018 / By:  ZT
#
# Description:  This script is used for cleaning up objects in a Jamf Pro Server.
#
###################################################################################################

##################################################
# Define Variables
	scriptDirectory=$(dirname "${0}")
	switch1="${1}"
	switch2="${2}"
	switch3="${3}"
	switch4="${4}"
	jamfPS="https://jss.company.com:8443"
	apiPackages="${jamfPS}/JSSResource/packages/id"
	apiPolicies="${jamfPS}/JSSResource/policies/id"
	apiComputers="${jamfPS}/JSSResource/computers/id"
	apiComputerGroups="${jamfPS}/JSSResource/computergroups/id"
	jamfAPIUser="APIUsername"
	jamfAPIPassword="APIPassword"

##################################################
# Setup Functions

getHelp() {
echo "
usage:  jamf_RetirePackages.sh --[action] --[type] [file] | [--help]

Info:	Uses jss_helper to query the JSS to get a list of packages and then get a list of policies that are installing the packages.

Actions:
	--get | -g		Get all the --[type] provided from the JSS and export them to a file.
		Example:  jamf_RetirePackages.sh --get --[type] output.file

	--pkgsUsed		Gets all the policies that install each package listed in the input file and exports the info to a file.
		Example:  jamf_RetirePackages.sh --pkgsUsed input.file output.file

	--delete | -d		Delete all the --[type] provided from the JSS listed in the input file
		Example:  jamf_RetirePackages.sh --delete --[type] input.file

Types:
	--packages | -pkgs

	--policies | -p

	--computers | c

	--computergroups | -g

"
}


getFunction() {
	case $1 in
		--packages | -pkgs )
			if [[ -n "${switch3}" ]]; then
				# Function fileExists
				fileExists "${scriptDirectory}" "${switch3}"

				# Function getPackages
				getPackages "${switch3}"
			else
				# Function getHelp
				getHelp
			fi
		;;
		--policies | -p )
			if [[ -n "${switch3}" ]]; then
				echo "Currently get is not supported for Policies."
			else
				# Function getHelp
				getHelp
			fi
		;;
		--computergroups | -g )
			if [[ -n "${switch3}" ]]; then
				echo "Currently get is not supported for Computer Groups."
			else
				# Function getHelp
				getHelp
			fi
		;;
		-help | * )
			# Function getHelp
			getHelp
		;;
	esac
}

deleteFunction() {
	case $1 in
		--packages | -pkgs )
			if [[ -e "${switch3}" ]]; then
				# Function deleteObjects
				deleteObjects "${switch3}" "${apiPackages}"
			else
				# Function getHelp
				getHelp
			fi
		;;
		--policies | -p )
			if [[ -e "${switch3}" ]]; then
				# Function deleteObjects
				deleteObjects "${switch3}" "${apiPolicies}"
			else
				# Function getHelp
				getHelp
			fi
		;;
		--computers | -c )
			if [[ -e "${switch3}" ]]; then
				# Function deleteObjects
				deleteObjects "${switch3}" "${apiComputers}"
			else
				# Function getHelp
				getHelp
			fi
		;;
		--computergroups | -g )
			if [[ -e "${switch3}" ]]; then
				# Function deleteObjects
				deleteObjects "${switch3}" "${apiComputerGroups}"
			else
				# Function getHelp
				getHelp
			fi
		;;
		-help | * )
			# Function getHelp
			getHelp
		;;
	esac
}

getPackages() {
	packages=$(jss_helper package)

	printf '%s\n' "$packages" | while IFS= read -r line; do
		packageID=$(echo "$line" | awk -F 'ID: ' '{print $2}' | awk -F ' ' '{print $1}')
		packageName=$(echo "$line" | awk -F 'NAME: ' '{print $2}')
		echo "$packageID,$packageName" >> "${1}"
	done
}

getPkgPolicies() {
	while IFS= read -r line; do
		if [[ -n $line ]]; then
			packageID=$(echo "$line" | awk -F ',' '{print $1}')
			packageName=$(echo "$line" | awk -F ',' '{print $2}')
			echo "$packageID,$packageName" >> "${2}"

			getInstalls=$(jss_helper installs "$packageID")

			printf '%s\n' "$getInstalls" | while IFS= read -r line; do
				policyID=$(echo "$line" | awk -F 'ID: ' '{print $2}' | awk -F ' ' '{print $1}')
				policyName=$(echo "$line" | awk -F 'NAME: ' '{print $2}')
				if [[ -n $policyID ]]; then
					echo "$policyID,$policyName" >> "${2}"
				fi
			done
		fi
	done < "${1}"
}

deleteObjects() {
	while IFS= read -r line; do
		if [[ -n $line ]]; then
			itemID=$(echo "$line" | awk -F ',' '{print $1}')
			itemName=$(echo "$line" | awk -F ',' '{print $2}')

			/bin/echo "Deleting:  ${itemName}"
			exitStatus=$(/usr/bin/curl --silent --show-error --fail --user "${jamfAPIUser}:${jamfAPIPassword}" "${2}/${itemID}" --request DELETE 2>&1)
			exitCode=$?

			if [[ $exitCode != 0 ]]; then
				echo " -> FAILED"
				echo "Attempting to delete ID ${itemID} resulted in:  ${exitStatus}" >> "${scriptDirectory}/errorLog.txt"
			fi
		fi
	done < "${1}"
}

fileExists() {
	if [[ ! -e "${1}" ]]; then
		echo "Unable to find the input file!"
		exit 1
	elif [[ ! -e "${2}" ]]; then
		touch "${1}"
	fi
}

##################################################
# Find out what we want to do...

case $switch1 in
	--get | -g )
		if [[ -n "${switch2}" ]]; then
			# Function getFunction
			getFunction "${switch2}"
		else
			# Function getHelp
			getHelp
		fi
	;;
	--pkgsUsed )
		if [[ -n "${switch2}" || -n "${switch3}" ]]; then
			# Function fileExists
			fileExists "${switch2}" "${switch3}"

			# Function getPkgPolicies
			getPkgPolicies "${switch2}" "${switch3}"
		else
			# Function getHelp
			getHelp
		fi
	;;
	--delete | -d )
		if [[ -n "${switch2}" ]]; then
			# Function deleteFunction
			deleteFunction "${switch2}"
		else
			# Function getHelp
			getHelp
		fi
	;;
	--help | * )
			# Function getHelp
			getHelp
		;;
esac

exit 0