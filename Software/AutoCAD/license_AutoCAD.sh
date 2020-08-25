#!/bin/bash

###################################################################################################
# Script Name:  license_AutoCAD.sh
# By:  Zack Thompson / Created:  3/29/2018
# Version:  1.1.0 / Updated:  8/21/2020 / By:  ZT
#
# Description:  This script applies the license for AutoCAD 2019 and older.
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

		if [[ $licenseType == "Academic" ]]; then

			licenseContents="SERVER licser1.company.com 000000000000 12345
SERVER licser2.company.com 000000000000 12345
SERVER licser3.company.com 000000000000 12345
USE_SERVER"

		elif [[ $licenseType == "Administrative" ]]; then

			licenseContents="SERVER licser4.company.com 000000000000 67890
SERVER licser5.company.com 000000000000 67890
SERVER licser6.company.com 000000000000 67890
USE_SERVER"

		fi

	;;

	"Stand Alone" | "Local" )

		licenseMechanism="Local"

		if [[ $licenseType == "Academic" ]]; then

			# Functionality would need to be added to support a local license
			echo "Functionality would need to be added to support a local license."

		elif [[ $licenseType == "Administrative" ]]; then

			# Functionality would need to be added to support a local license
			echo "Functionality would need to be added to support a local license."

		fi

	;;

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
appPaths=$( /usr/bin/find -E /Applications -iregex ".*[/]AutoCAD 20[0-9]{2}[.]app" -type d -prune )

# Verify that a AutoCAD Application was found.
if [[ -z "${appPaths}" ]]; then

	echo "ERROR:  AutoCAD was not found!"
	echo "*****  License AutoCAD process:  FAILED  *****"
	exit 3

else

	# If the machine has multiple AutoCAD Applications, loop through them...
	while IFS="\n" read -r appPath; do

		# Set the location of App's Contents folder
		appContents="${appPath}/Contents"

		# Get the App's version (just in case, not assuming the name of the app is the correct version string)
		appVersion=$( /usr/bin/defaults read "${appContents}/Info.plist" CFBundleName | /usr/bin/awk -F "AutoCAD " '{print $2}' )

		# Set the Network License file path for this version
		networkLicense="${licenseDirectory}/${appVersion}"

		echo "Product Version:  ${appVersion}"

		if [[ $appVersion -le 2019 ]]; then

			# Check if the directory exists
			if [[ ! -d "${networkLicense}" ]]; then

				/bin/mkdir -p "${networkLicense}"

			fi

			echo "Applying licesning configuration..."

			/usr/bin/printf "${licenseContents}" > "${networkLicense}/LicPath.lic"
			exitCode1=$?

			/usr/bin/printf "_${licenseMechanism}" > "${networkLicense}/LGS.data"
			exitCode2=$?

			if [[ $exitCode1 != 0 || $exitCode2 != 0 ]]; then

				echo "ERROR:  Failed to create the license files!"
				echo "*****  License AutoCAD process:  FAILED  *****"
				exit 4

			fi

		else

			echo "WARNING:  This script does not support this version of AutoCAD!"

		fi

	done < <( echo "${appPaths}" )
fi

echo "AutoCAD has been activated!"
echo "*****  License AutoCAD process:  COMPLETE  *****"
exit 0
