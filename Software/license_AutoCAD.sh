#!/bin/bash

###################################################################################################
# Script Name:  license_AutoCAD.sh
# By:  Zack Thompson / Created:  3/29/2018
# Version:  1.0 / Updated:  3/30/2018 / By:  ZT
#
# Description:  This script applies the license for AutoCAD applications.
#
###################################################################################################

echo "*****  License AutoCAD process:  START  *****"

##################################################
# Define Variables

licenseDirectory="/Library/Application Support/Autodesk/CLM/LGS"

##################################################
# Turn on case-insensitive pattern matching
shopt -s nocasematch

# Determine License Type
case "${4}" in
	"T&R" | "Teaching and Research" | "Academic" )
		licenseType="Academic"
		;;
	"Admin" | "Administrative" )
		licenseType="Administrative"
		;;
	* )
		echo "ERROR:  Invalid License Type provided"
		echo "*****  License AutoCAD process:  FAILED  *****"
		exit 1
		;;
esac

echo "Licensing Type:  ${licenseType}"

# Determine License Mechanism
case "${5}" in
	"LM" | "License Manager" | "Network" )
		licenseMechanism="NETWORK"
		;;
	# "Stand Alone" | "Local" )
	# 	licenseMechanism="Local"
	# 	;;
	* )
		echo "ERROR:  Invalid License Mechanism provided"
		echo "*****  License AutoCAD process:  FAILED  *****"
		exit 2
		;;
esac

# Turn off case-insensitive pattern matching
shopt -u nocasematch

echo "Licensing Mechanism:  ${licenseMechanism}"

##################################################
# Bits staged, license software...

# Find all install AutoCAD versions.
appPaths=$(/usr/bin/find -E /Applications -iregex ".*[/]AutoCAD 201[0-9]{1}[.]app" -type d -prune)

# Verify that a AutoCAD Application was found.
if [[ -z "${appPaths}" ]]; then
	echo "ERROR:  AutoCAD was not found!"
	echo "*****  License AutoCAD process:  FAILED  *****"
	exit 3
else
	installedVersions=$(ls "${licenseDirectory}")

	if [[ $licenseType == "Academic" && $licenseMechanism == "NETWORK" ]]; then
licenseContents="SERVER licser1.company.com 000000000000 12345
SERVER licser2.company.com 000000000000 12345
SERVER licser3.company.com 000000000000 12345
USE_SERVER"

	# elif [[ $licenseType == "Academic" && $licenseMechanism == "Local" ]]; then
	# 	licenseContents=""

	elif [[ $licenseType == "Administrative" && $licenseMechanism == "NETWORK" ]]; then
licenseContents="SERVER licser4.company.com 000000000000 67890
SERVER licser5.company.com 000000000000 67890
SERVER licser6.company.com 000000000000 67890
USE_SERVER"

	# elif [[ $licenseType == "Administrative" && $licenseMechanism == "Local" ]]; then
	# 	licenseContents=""
	fi

	echo "Configuring the License Manager Server..."

	while IFS="\n" read -r version; do
		echo "Product Version:  ${version}"
		/usr/bin/printf "${licenseContents}" > "${licenseDirectory}/${version}/LicPath.lic"
		/usr/bin/printf "_${licenseMechanism}" > "${licenseDirectory}/${version}/LGS.data"
	done < <(/usr/bin/printf '%s\n' $installedVersions)

fi

echo "AutoCAD has been activated!"
echo "*****  License AutoCAD process:  COMPLETE  *****"
exit 0