#!/bin/bash

###################################################################################################
# Script Name:  license_SPSS.sh
# By:  Zack Thompson / Created:  1/3/2018
# Version:  1.2 / Updated:  1/9/2018 / By:  ZT
#
# Description:  This script applies the license for SPSS applications.
#
###################################################################################################

/usr/bin/logger -s "*****  License SPSS process:  START  *****"

##################################################
# Define Variables

# Get the location of SPSSStatistics.app
appPath="/Applications/$(/bin/ls /Applications | /usr/bin/grep "SPSS")"
licensePath="${appPath}/SPSSStatistics.app/Contents/bin"

# Determine License Type
case "${4}" in
	"T&R" | "Teaching and Research" | "Academic" )
		licenseType="Academic"
		;;
	"Admin" | "Administrative" )
		licenseType="Administrative"
		;;
	* )
		/usr/bin/logger -s "ERROR:  Invalid License Type provided"
		/usr/bin/logger -s "*****  License SPSS process:  FAILED  *****"
		exit 1
		;;
esac

/usr/bin/logger -s "Licensing Type:  ${licenseManager}"

# Determine License Mechanism
case "${5}" in
	"LM" | "License Manager" | "Network" )
		licenseMechanism="Network"
		;;
	"Stand Alone" | "Local" )
		licenseMechanism="Local"
		;;
	* )
		/usr/bin/logger -s "ERROR:  Invalid License Mechanism provided"
		/usr/bin/logger -s "*****  License SPSS process:  FAILED  *****"
		exit 2
		;;
esac

/usr/bin/logger -s "Licensing Mechanism:  ${licenseMechanism}"

##################################################
# Define Functions

function LicenseInfo {
	if [[ $licenseType == "Academic" ]]; then
		licenseManager="server.company.com"
		cummuterDays="7"

		# Determine License Code
		case "${versionSPSS}" in
			"25" )
				licenseCode="2512345678910"
				;;
			"24" )
				licenseCode="2412345678910"
				;;
			"23" )
				licenseCode="2312345678910"
				;;
		esac
	elif [[ $licenseType == "Administrative" ]]; then
		licenseManager="server.company.com"
		cummuterDays="7"

		# Determine License Code
		case "${versionSPSS}" in
			"25" )
				licenseCode="2512345678911"
				;;
			"24" )
				licenseCode="2412345678911"
				;;
			"23" )
				licenseCode="2312345678911"
				;;
		esac
	fi
}

##################################################
# Bits staged, license software...

# Ensure the App Bundle exists
if [[ -d "${appPath}/SPSSStatistics.app" ]]; then

	if [[ $licenseMechanism == "Network" ]]; then

		/usr/bin/logger -s "Configuring the License Manager Server..."

		# Set the license file path
		networkLicense="${appPath}/${licensePath}/spssprod.inf"

		# Function LicenseInfo
		LicenseInfo

		# Inject the License Manager Server Name and number of days allowed to check out a license.
		/usr/bin/sed -i '' 's/DaemonHost=.*/'"DaemonHost=${licenseManager}"'/' "${networkLicense}"
		/usr/bin/sed -i '' 's/CommuterMaxLife=.*/'"CommuterMaxLife=${cummuterDays}"'/' "${networkLicense}"

		if [[ -e "${appPath}/${licensePath}/lservrc" ]]; then
			/usr/bin/logger -s "Local License file exists; deleting..."
			/bin/rm -rf "${appPath}/${licensePath}/lservrc"
		fi

	elif [[ $licenseMechanism == "Local" ]]; then

		# Get the SPSS version
		versionSPSS=$(/usr/bin/defaults read "${appPath}/SPSSStatistics.app/Contents/Info.plist" CFBundleShortVersionString | /usr/bin/awk -F "." '{print $1}')
		/usr/bin/logger -s "Apply License Code for version:  ${versionSPSS}"

		# Function LicenseInfo
		LicenseInfo

		# Apply License Code
		/usr/bin/cd "${appPath}/${licensePath}"
		exitStatus=$(./licenseactivator "${licenseCode}")

		if [[ $exitStatus == *"Authorization succeeded"* ]]; then
			/usr/bin/logger -s "License Code applied successfully!"

			if [[ -e "${appPath}/${licensePath}/spssprod.inf" ]]; then
				/usr/bin/logger -s "Removing Network License Manager info..."
				# Remove the License Manager Server Name.
				/usr/bin/sed -i '' 's/DaemonHost=.*/'"DaemonHost="'/' "${networkLicense}"
			fi

		else
			/usr/bin/logger -s "ERROR:  Failed to apply License Code"
			/usr/bin/logger -s "ERROR Contents:  ${exitStatus}"
			/usr/bin/logger -s "*****  License SPSS process:  FAILED  *****"
			exit 4
		fi
	fi
else
	/usr/bin/logger -s "ERROR:  Unable to locate the SPSSStatistics.app bundle"
	/usr/bin/logger -s "*****  License SPSS process:  FAILED  *****"
	exit 3
fi

/usr/bin/logger -s "SPSS has been activated!"
/usr/bin/logger -s "*****  License SPSS process:  COMPLETE  *****"

exit 0
