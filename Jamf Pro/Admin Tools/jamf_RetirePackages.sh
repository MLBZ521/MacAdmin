#!/bin/bash

###################################################################################################
# Script Name:  jamf_RetirePackages.sh
# By:  Zack Thompson / Created:  9/15/2017
# Version:  1.0 / Updated:  9/15/2017 / By:  ZT
#
# Description:  This script is used for cleaning up packages in a Jamf Pro Server.
#
###################################################################################################

##################################################
# Define Variables
	scriptDirectory=$(dirname "${0}")
	cwd=$(pwd)
	switch="${1}"
	input2="${cwd}/${2}"
	input3="${cwd}/${3}"

##################################################
# Setup Functions

function getHelp {
echo "
usage:  jamf_RetirePackages.sh [-packages] [-policies] [-h]

Info:	Uses jss_helper to query the JSS to get a list of packages and then get a list of policies that are installing the packages.

Actions:
	-packages	Gets all the packages from the JSS and export them to a file.
			Example:  jamf_RetirePackages.sh -packages output.file

	-policies	Gets all the policies that install the packages listed in the input file and exports the info to a file.
			Example:  jamf_RetirePackages.sh -policies input.file output.file
"
}

function getPackages {
	packages=$(jss_helper package)

	printf '%s\n' "$packages" | while IFS= read -r line; do
	   packageID=$(echo "$line" | awk -F 'ID: ' '{print $2}' | awk -F ' ' '{print $1}')
	   packageName=$(echo "$line" | awk -F 'NAME: ' '{print $2}')
	   echo "$packageID,$packageName" >> "${input2}"
	done
}

function getPolicies {
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
	done < $1
}

##################################################
# Find out what we want to do...

case $switch in
	-packages )
		if [[ -n $input2 ]]; then
			# Function getPackages
			getPackages $input2
		else
			# Function getHelp
			getHelp
		fi
	;;
	-policies)
		if [[ -n $input2 || -n $input3 ]]; then
			# Function getPolicies
			getPolicies $input2 $input3
		else
			# Function getHelp
			getHelp
		fi
	;;
	-h | * )
		# Function getHelp
		getHelp
	;;
esac