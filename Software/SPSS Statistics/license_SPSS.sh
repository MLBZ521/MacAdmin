#!/bin/bash

###################################################################################################
# Script Name:  license_SPSS.sh
# By:  Zack Thompson / Created:  1/3/2018
# Version:  2.5.0 / Updated:  9/7/2021 / By:  ZT
#
# Description:  This script applies the license for SPSS applications.
#
###################################################################################################

echo "*****  License SPSS process:  START  *****"

# Define the minimum supported version
minimum_supported_version="26"

##################################################
# Define Functions

exitCheck() {
	if [[ $1 != 0 ]]; then

		echo "${2}"
		echo "Exit Code:  ${1}"
		echo "*****  License SPSS process:  FAILED  *****"
		exit $1

	else

		echo "*****  License SPSS process:  COMPLETE  *****"
		exit 0

	fi
}

status_code_check() {

	if [[ $1 != 0 ]]; then

		echo "Exit Code:  ${1}"
		echo "Command results:  ${2}"
		echo "*****  License SPSS process:  FAILED  *****"
		exit $1

	elif [[ -n $2 ]]; then

		echo "Command results:  ${2}"

	fi

}

renameLocalLicense(){

	# If a current Authorized User license file exists, back it up.
	if [[ -e "${1}" ]]; then

		echo "${2}"
		dateStamp=$( /bin/date +%Y-%m-%d_%H.%M.%S )
		/bin/mv "${1}" "${1}_${dateStamp}"

	fi

}

resetLockCode(){

	# Reset the Lock Code
	# Adapted from known issue:  https://www.ibm.com/support/pages/troubleshooting-common-licensing-problems-authorized-user-spss-product-statistics-modeler-amos
	if [[ -e "${1}" ]]; then

		echo "Resetting the lock code..."
		/usr/bin/sed -i '' 's/0x010/0x004/' "${1}"

	fi
}

resetNetworkLicense() {

	# If the network license file exists, remove the License Manager server name.
	if [[ -e "${1}" ]]; then
		echo "Preemptively removing Network License Manager info due to local license being used..."
		/usr/bin/sed -i '' 's/DaemonHost=.*/DaemonHost=/' "${1}"
	fi

}

setPermsLocalLicense() {

	# Setting permissions to resolve issues as it relates to (this step is not described, but helps to resolve):  https://www-01.ibm.com/support/docview.wss?uid=swg21966637
	echo "Setting permissions on the SPSS ${1} license file..."
	/bin/chmod 644 "${2}"

}

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
		exitCheck 1 "ERROR:  Invalid License Type provided"
	;;

esac

# Determine License Mechanism
case "${5}" in

	"LM" | "License Manager" | "Network" )
		licenseMechanism="Network"
	;;

	"Stand Alone" | "Local" )
		licenseMechanism="Local"
	;;

	* )
		exitCheck 2 "ERROR:  Invalid License Mechanism provided"
	;;

esac

# Turn off case-insensitive pattern matching
shopt -u nocasematch

echo "Licensing Type:  ${licenseType}"
echo "Licensing Mechanism:  ${licenseMechanism}"

##################################################
# Define Licensing Details

LicenseInfo() {

	if [[ $licenseType == "Academic" ]]; then

		licenseManager="server.company.com"
		commuterDays="7"

		# Determine License Code
		case "${versionSPSS}" in

			"28" )
				licenseCode="2812345678910"
			;;

			"27" )
				licenseCode="2712345678910"
			;;

			"26" )
				licenseCode="2612345678910"
			;;

			"25" )
				licenseCode="2512345678910"
			;;

			"24" )
				licenseCode="2412345678910"
			;;

			"23" )
				licenseCode="2312345678910"
			;;

			* )
				echo "WARNING:  Licensing script does not support this version of SPSS"
			;;

		esac

	elif [[ $licenseType == "Administrative" ]]; then

		licenseManager="server.company.com"
		commuterDays="7"

		# Determine License Code
		case "${versionSPSS}" in

			"28" )
				licenseCode="2812345678911"
			;;

			"27" )
				licenseCode="2712345678911"
			;;

			"26" )
				licenseCode="2612345678911"
			;;

			"25" )
				licenseCode="2512345678911"
			;;

			"24" )
				licenseCode="2412345678911"
			;;

			"23" )
				licenseCode="2312345678911"
			;;

			* )
				echo "WARNING:  Licensing script does not support this version of SPSS"
			;;

		esac

	fi
}

##################################################
# Bits staged, license software...

exitCode=0

# Find all installed versions of SPSS.
appPaths=$( /usr/bin/find -E /Applications -iregex ".*[/](SPSS) ?(Statistics) ?([0-9]{2})?[.]app" -type d -prune )

echo -e "Found appPaths:  \n\n${appPaths}"

# Verify at least one version of SPSS was found.
if [[ -z "${appPaths}" ]]; then

	exitCheck 3 "WARNING:  A version of SPSS was not found in the expected location!"

else

	# If the machine has multiple SPSS Applications, loop through them...
	while IFS=$'\n' read -r appPath; do

		##################################################
		# Define Variables

		# Get the App Bundle name
		appName=$( echo "${appPath}" | /usr/bin/awk -F "/" '{print $NF}' )
		# Get only the install path
		installPath=$( echo "${appPath}" | /usr/bin/awk -F "/${appName}" '{print $1}' )
		# Set the location of SPSS.app Contents folder
		spssContents="${appPath}/Contents"
		# Set the location of SPSS.app bin folder
		spssBin="${spssContents}/bin"
		# Get the SPSS version
		versionSPSS=$( /usr/bin/defaults read "${spssContents}/Info.plist" CFBundleShortVersionString | /usr/bin/awk -F "." '{print $1}' )

		if [[ $( /usr/bin/bc <<< "${versionSPSS} < ${minimum_supported_version}" ) -eq 1 ]]; then
			echo "WARNING:  SPSS Version ${versionSPSS} is no longer supported.  Please upgrade to a newer version."
			continue
		fi

		# Function LicenseInfo
		LicenseInfo

		##################################################

		# Setting permissions to resolve issues seen in:  https://www-01.ibm.com/support/docview.wss?uid=swg21966637
		echo "Setting permissions on SPSS ${versionSPSS} files..."
		/usr/sbin/chown -R root:admin "${installPath}"

		if [[ $licenseMechanism == "Network" ]]; then
			echo "Configuring the License Manager Server for version:  ${versionSPSS}"

			if [[ $( /usr/bin/bc <<< "${versionSPSS} >= 27" ) -eq 1 ]]; then

				# Set the Network License file path
				networkLicense="${installPath}/Resources/Activation/commutelicense.ini"
				# Set the Local License file path
				localLicense="${installPath}/Resources/Activation/lservrc"

				# Apply new licensing method; this information is stored in a different file, but instead of directly injecting it...  Let's follow the expected process this time.
				activation_results=$( "${installPath}/Resources/Activation/licenseactivator" LSHOST="${licenseManager}" COMMUTE_MAX_LIFE="${commuterDays}" )
				activation_exit_status=$?
				status_code_check $activation_exit_status "${activation_results}"

			else

				# Set the Network License file path
				networkLicense="${spssBin}/spssprod.inf"
				# Set the Local License file path
				localLicense="${spssBin}/lservrc"

				# Inject the License Manager Server Name and number of days allowed to check out a license.
				/usr/bin/sed -i '' 's/DaemonHost=.*/'"DaemonHost=${licenseManager}"'/' "${networkLicense}"
				/usr/bin/sed -i '' 's/CommuterMaxLife=.*/'"CommuterMaxLife=${commuterDays}"'/' "${networkLicense}"

			fi

			# If the local license file exists, disable it.
			renameLocalLicense "${localLicense}" "Disabling local license..."

		# Verify a license code was defined for this version
		elif [[ $licenseMechanism == "Local" && -n "${licenseCode}" ]]; then

			echo "Apply License Code for version:  ${versionSPSS}"

			if [[ $( /usr/bin/bc <<< "${versionSPSS} >= 27" ) -eq 1 ]]; then

				# Reset the Lock Code
				resetLockCode "${installPath}/Resources/Activation/echoid.dat"

				# Set the Network License file path
				networkLicense="${installPath}/Resources/Activation/commutelicense.ini"
				# Set the Local License file path
				localLicense="${installPath}/Resources/Activation/lservrc"

				# If a current local license file exists, back it up.
				renameLocalLicense "${localLicense}" "Backing up previous local license..."

				# Apply new licensing method
				exitStatus=$( "${installPath}/Resources/Activation/licenseactivator" --code "${licenseCode}" )

				checkLicense=$( "${installPath}/Resources/Activation/showlic" -d "${installPath}/Resources/Activation" -np )

				if [[ $checkLicense == *"No licenses found for IBM SPSS Statistics ${versionSPSS}"* ]]; then

					echo "ERROR:  Failed to apply License Code"
					echo "ERROR Contents:  ${exitStatus}"
					exitCode=6

				else

					echo "License Code applied successfully!"

					# Set permissions on local license file
					setPermsLocalLicense "${versionSPSS}" "${localLicense}"

					# Reset the current network license
					resetNetworkLicense "${networkLicense}"

					echo "SPSS v${versionSPSS} has been activated!"

				fi

			else

				# Reset the Lock Code
				resetLockCode "${spssBin}/echoid.dat"

				# Set the Network License file path
				networkLicense="${spssBin}/spssprod.inf"
				# Set the Local License file path
				localLicense="${spssBin}/lservrc"

				# If a current local license file exists, back it up.
				renameLocalLicense "${localLicense}" "Backing up previous local license..."

				spssJRE="${spssContents}/JRE/bin/java"
				javaProp="-Djava.version=1.5 -Dis.headless=true -Djava.awt.headless=true"
				spssActivator="${spssBin}/licenseactivator.jar"

				# Preferably use the bundled JRE.
				if [[ -e "${spssJRE}" ]]; then
					javaBinary="${spssJRE}"
				else
					javaBinary=java
				fi

				# Setup LC_ALL locale
				if [[ "${LC_ALL}" = "" ]]; then
					LC_ALL=en_US
				fi

				# Apply License Code
				exitStatus=$( cd "${spssBin}" && "${javaBinary}" "${javaProp}" -jar "${spssActivator}" "SILENTMODE" "CODES=${licenseCode}" )

				if [[ $exitStatus == *"Authorization succeeded"* ]]; then
					echo "License Code applied successfully!"

					# Set permissions on local license file
					setPermsLocalLicense "${versionSPSS}" "${localLicense}"

					# Reset the current network license
					resetNetworkLicense "${networkLicense}"

					echo "SPSS v${versionSPSS} has been activated!"

				else

					echo "ERROR:  Failed to apply License Code"
					echo "ERROR Contents:  ${exitStatus}"
					exitCode=5

				fi

			fi

		else

			echo "ERROR:  Local administrative licenses are not supported"
			exitCode=4

		fi

	done < <( echo "${appPaths}" )
fi

exitCheck $exitCode