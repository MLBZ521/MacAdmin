#!/bin/bash
# set -x

####################################################################################################
# Script Name:  Get-LatestOSSupported.sh
# By:  Zack Thompson / Created:  9/26/2017
# Version:  2.5.3 / Updated:  9/26/2023 / By:  ZT
#
# Description:  A Jamf Pro Extension Attribute to check the latest compatible version of macOS.
#
# New Feature:  When running as standalone script, you can pass a Model number and OS version
# 				to the script to validate regex.
# 	EXAMPLE
# 		$ bash ./Get-LatestOSSupported.sh "MacBookPro13,3" "12.0"
# 		Test OS value: 12.0
# 		Test Model value: MacBookPro13,3
# 		<result>Monterey</result>
#
#	Courtesy of Nic Wendlowsky (@hkystar35)
#
# Updates:  For each OS version released, a new Regex string and each function will need to be
#			updated.
#
#	System Requirements can be found here:
#		Full List - https://support.apple.com/en-us/HT211683
#		Sonoma (Preview) - https://www.apple.com/macos/sonoma-preview/
#		Ventura - https://support.apple.com/en-us/HT213265 / https://support.apple.com/en-us/HT213264
#			* Apple has never publicly posted storage requirements for Ventura, which is why this
#			  script identifies Ventura support with an asterisk, e.g. `Ventura*`
#		Monterey - https://support.apple.com/en-us/HT212551
#		Big Sur - https://support.apple.com/en-us/HT211238 / https://support.apple.com/kb/sp833
#			* If running Mountain Lion 10.8, device will need to upgrade to El Capitan 10.11 first.
#			  first.  See:
#			* https://web.archive.org/web/20211018042220/https://www.apple.com/macos/how-to-upgrade/
#		Catalina - https://support.apple.com/en-us/HT210222 / https://support.apple.com/kb/SP803
#		Mojave - https://support.apple.com/kb/SP777
#			* MacPro5,1's = https://support.apple.com/en-us/HT208898
#		High Sierra - https://support.apple.com/kb/SP765
#		Sierra - https://support.apple.com/kb/sp742
#		El Capitan - https://support.apple.com/kb/sp728
#
####################################################################################################

##################################################
# Define test values

# Allow for specifying a Model and OS Version to the script to validate regex.
# If these values are passed, the write_to_ea_history function is ignored so that incorrect
# information is not written to the test computer.
# Supported actions:
# 	TEST_MODEL - example: "MacBookPro13,3"
# 	TEST_OS - example: "14.0"

TEST_MODEL="${1}"
TEST_OS="${2}"

##################################################
# Define organization's environment values

# Locally log EA value which can be collected with a simple `defaults read` allowing this script
# to be ran from a Policy or other method, instead of an actual EA.  Also allows the reported
# value to be collected and used within other scripts/workflows.
# Supported actions:
#   true - Do locally Log
#   false - Do not log locally
locally_log="true"
local_inventory="/opt/ManagedFrameworks/Inventory.plist"

##################################################
# Define Regex Strings to exclude Mac Models that *do not support* each OS Version
not_elcapitan_or_older_regex="^((MacPro|Macmini|MacBookPro)[1-2],[0-9]|iMac[1-6],[0-9]|MacBook[1-4],[0-9]|MacBookAir1,[0-9])$"
not_highsierra_regex="^(MacPro[1-4],[0-9]|iMac[1-9],[0-9]|Macmini[1-3],[0-9]|(MacBook|MacBookPro)[1-5],[0-9]|MacBookAir[1-2],[0-9])$"
not_mojave_regex="^(MacPro[1-4],[0-9]|iMac([1-9]|1[0-2]),[0-9]|Macmini[1-5],[0-9]|MacBook[1-7],[0-9]|MacBookAir[1-4],[0-9]|MacBookPro[1-8],[0-9])$"
not_catalina_regex="^(MacPro[1-5],[0-9]|iMac([1-9]|1[0-2]),[0-9]|Macmini[1-5],[0-9]|MacBook[1-7],[0-9]|MacBookAir[1-4],[0-9]|MacBookPro[1-8],[0-9])$"
not_bigsur_regex="^(MacPro[1-5],[0-9]|iMac((([1-9]|1[0-3]),[0-9])|14,[0-3])|Macmini[1-6],[0-9]|MacBook[1-7],[0-9]|MacBookAir[1-5],[0-9]|MacBookPro([1-9]|10),[0-9])$"
not_monterey_regex="^(MacPro[1-5],[0-9]|iMac([1-9]|1[0-5]),[0-9]|(Macmini|MacBookAir)[1-6],[0-9]|MacBook[1-8],[0-9]|MacBookPro(([1-9]|10),[0-9]|11,[0-3]))$"
not_ventura_regex="^(MacPro[1-6],[0-9]|iMac([1-9]|1[0-7]),[0-9]|(Macmini|MacBookAir)[1-7],[0-9]|MacBook[1-9],[0-9]|MacBookPro([1-9]|1[0-3]),[0-9])$"
not_sonoma_regex="^(MacPro[1-6],[0-9]|iMac([1-9]|1[0-8]),[0-9]|(Macmini|MacBookAir)[1-7],[0-9]|MacBook[\d,]+|MacBookPro([1-9]|1[0-4]),[0-9])$"

##################################################
# Setup Functions

write_to_ea_history() {

	# Arguments
	# $1 = (str) Plist key that the message value will be assigned too
	# $2 = (str) Message that will be assigned to the key

	local key="${1}"
	local value="${2}"

	if [[ "${locally_log}" == "true" && -z "${TEST_OS}" && -z "${TEST_MODEL}" ]]; then

		if [[ ! -e "${local_inventory}" ]]; then

			/bin/mkdir -p "$( /usr/bin/dirname "${local_inventory}" )"
			/usr/bin/touch "${local_inventory}"

		fi

		/usr/bin/defaults write "${local_inventory}" "${key}" "${value}"

	fi

}

model_check() {
	# $1 = Mac Model Identifier
	local model="${1}"

	if [[ $model =~ $not_elcapitan_or_older_regex || $model =~ ^Xserve.*$ ]]; then
		echo "<result>Current Model Not Supported</result>"
		exit 0
	elif [[ $model =~ $not_highsierra_regex ]]; then
		echo "El Capitan"
	elif [[ $model =~ $not_mojave_regex ]]; then
		echo "High Sierra"
	elif [[ $model =~ $not_catalina_regex ]]; then
		echo "Mojave"
	elif [[ $model =~ $not_bigsur_regex ]]; then
		echo "Catalina"
	elif [[ $model =~ $not_monterey_regex ]]; then
		echo "Big Sur"
	elif [[ $model =~ $not_ventura_regex ]]; then
		echo "Monterey"
	elif [[ $model =~ $not_sonoma_regex ]]; then
		echo "Ventura*"
	else
		echo "Sonoma*"
	fi
}

os_check() {
	# $1 = Max supported OS version based on hardware model
	# $2 = Current OS major version
	# $3 = Current OS minor version
	# $4 = Current OS patch version
	local validate_os="${1}"
	local os_major="${2}"
	local os_minor="${3}"
	local os_patch="${4}"

	if [[ ! "${mac_model}" =~ ^MacPro.*$ ]]; then
		# For ***non*** MacPro models:

		if [[ "${validate_os}" == "Sonoma*" && ( "${os_major}" -ge 11 || "${os_major}" -eq 10 && "${os_minor}" -ge 9 ) ]]; then
			echo "Sonoma*"
		elif [[ "${validate_os}" == "Ventura*" && ( "${os_major}" -ge 11 || "${os_major}" -eq 10 && "${os_minor}" -ge 9 ) ]]; then
			echo "Ventura*"
		elif [[ "${validate_os}" == "Monterey" && ( "${os_major}" -ge 11 || "${os_major}" -eq 10 && "${os_minor}" -ge 9 ) ]]; then
			echo "Monterey"
		elif [[ "${validate_os}" == "Big Sur" && ( "${os_major}" -ge 11 || "${os_major}" -eq 10 && "${os_minor}" -ge 9 ) ]]; then
			echo "Big Sur"
		elif [[ "${validate_os}" == "Big Sur" && ( "${os_major}" -ge 11 || "${os_major}" -eq 10 && "${os_minor}" -le 8 ) ]]; then
			echo "El Capitan / OS Limitation"
		elif [[ "${validate_os}" == "Catalina" && "${os_major}" -eq 10 && "${os_minor}" -ge 9 ]]; then
			echo "Catalina"
		elif [[ "${validate_os}" == "Catalina" && "${os_major}" -eq 10 && "${os_minor}" -le 8 ]]; then
			echo "Mojave / OS Limitation"  # (Current OS Limitation, 10.15 Catalina)
		elif [[ "${validate_os}" == "Mojave" && "${os_major}" -eq 10 && "${os_minor}" -ge 8 ]]; then
			echo "Mojave"
		elif [[ "${validate_os}" == "High Sierra" && "${os_major}" -eq 10 && "${os_minor}" -ge 8 ]]; then
			echo "High Sierra"
		elif [[ "${validate_os}" == "High Sierra" && "${os_major}" -eq 10 && ( "${os_minor}" -ge 8 || "${os_minor}" -eq 7 && "${os_patch}" -ge 5 ) ]]; then
			echo "Sierra / OS Limitation"  # (Current OS Limitation, 10.13 Compatible)
		elif [[ "${validate_os}" == "El Capitan" && "${os_major}" -eq 10 && ( "${os_minor}" -ge 7 || "${os_minor}" -eq 6 && "${os_patch}" -ge 8 ) ]]; then
			echo "El Capitan"
		else
			echo "<result>Current OS Not Supported</result>"
			exit 0
		fi

	else
		# Because Apple had to make Mojave support for MacPro's difficult...  I have to add complexity to the original "simplistic" logic in this script.

		if [[ $validate_os =~ (Sonoma|Ventura)\* ]]; then
			echo "${validate_os}"

		elif [[ "${validate_os}" == "Monterey" ]]; then
			# Any MacPro model that is compatible with Monterey based on model identifier alone, is 100% compatible with Monterey,
			# since they wouldn't be compatible with any OS that is old, nor could they have incompatible hardware.
			# e.g. MacPro6,1 (i.e. 2013/Trash Cans) and newer
			echo "Monterey"

		elif [[ "${validate_os}" == "Mojave" && "${os_major}" -eq 10 && ( "${os_minor}" -ge 14 || "${os_minor}" -eq 13 && "${os_patch}" -ge 6 ) ]]; then
			# Supports Mojave, but required Metal Capable Graphics Cards and FileVault must be disabled.
			mac_pro_result="Mojave"

			# Check if the Graphics Card supports Metal
			if [[ $( /usr/sbin/system_profiler SPDisplaysDataType | /usr/bin/awk -F 'Metal: ' '{print $2}' | /usr/bin/xargs ) != *"Supported"* ]]; then
				mac_pro_result+=" / GFX unsupported"
			fi

			# Check if FileVault is enabled
			if [[ $( /usr/bin/fdesetup status | /usr/bin/awk -F 'FileVault is ' '{print $2}' | /usr/bin/xargs ) != "Off." ]]; then
				mac_pro_result+=" / FV Enabled"
			fi

			echo "${mac_pro_result}"

		elif [[ "${validate_os}" == "Mojave" && "${os_major}" -eq 10 && ( "${os_minor}" -le 12 || "${os_minor}" -eq 13 && "${os_patch}" -le 5 ) ]]; then
			echo "High Sierra / OS Limitation"  # Supports Mojave or newer, but requires a stepped upgrade path

		elif [[ "${validate_os}" == "Mojave" && "${os_major}" -eq 10 && ( "${os_minor}" -ge 8 || "${os_minor}" -eq 7 && "${os_patch}" -ge 5 ) ]]; then
			echo "Sierra / OS Limitation"  # (Current OS Limitation, 10.13 Compatible)

		elif [[ "${validate_os}" == "El Capitan" && "${os_major}" -eq 10 && ( "${os_minor}" -ge 7 || "${os_minor}" -eq 6 && "${os_patch}" -ge 8 ) ]]; then
			echo "El Capitan"

		else
			echo "<result>Current OS Not Supported</result>"
			exit 0
		fi

	fi
}

check_ram_upgradeable() {
	ram_upgradeable=$( /usr/sbin/system_profiler SPMemoryDataType | /usr/bin/awk -F "Upgradeable Memory: " '{print $2}' | /usr/bin/xargs 2&> /dev/null )
	# ARM Macs do not return the "Upgradeable Memory:" attribute as of early 2022
	if [[ -z ${ram_upgradeable} ]]; then
		ram_upgradeable="No"
	fi
	echo "${ram_upgradeable}"
}

# Check if the current RAM meets specs
ram_check() {
	# $1 = Max supported OS version based on hardware model
	local validate_os="${1}"

	# Setting the minimum RAM required for compatibility
	minimum_ram_mojave_and_older=2
	minimum_ram_catalina_and_newer=4

	# Get RAM Info
	system_ram=$(( $( /usr/sbin/sysctl -n hw.memsize ) / bytes_in_gigabytes ))

	if [[ "${validate_os}" =~ ^(Catalina|Big[[:space:]]Sur|Monterey|(Sonoma|Ventura)\*)$ ]]; then
		# OS version requires 4GB RAM minimum
		# For Ventura and Sonoma, value's are inherited from Monterey, Apple has
		# not yet defined these requirements.

		if [[ $system_ram -lt $minimum_ram_catalina_and_newer ]]; then
			# Based on RAM, device does not have enough to support Catalina or newer

			if [[ "$( check_ram_upgradeable )" == "No" ]]; then
				# Device is not upgradable, so can never support Catalina or newer

				if [[ $system_ram -ge $minimum_ram_mojave_and_older ]]; then
					# Device has enough RAM to support Mojave
					validate_os="Mojave"
				else
					# Device does not have enough RAM to support any upgrade!?
					echo "<result>Not Upgradable</result>"
					exit 0
				fi

			else
				# Device does not have enough RAM to upgrade currently, but RAM capacity can be increased.
				validate_os+=" / Insufficient RAM"
			fi

		fi

	else
		# Based on model, device supports Mojave or older
		if [[ $system_ram -lt $minimum_ram_mojave_and_older ]]; then
			# Based on RAM, device does not have enough to upgrade

			if [[ "$( check_ram_upgradeable )" == "No" ]]; then
				# Device does not have enough RAM to support any upgrade!?
				echo "<result>Not Upgradable</result>"
				exit 0
			else
				# Device does not have enough RAM to upgrade currently, but RAM capacity can be increased.
				validate_os+=" / Insufficient RAM"
			fi

		fi

	fi

	echo "${validate_os}"
}

# Check if the available free space is sufficient
storage_check() {
	# $1 = Max supported OS version based on hardware model
	# $2 = Current OS major version
	# $3 = Current OS minor version
	# $4 = Current OS patch version
	local validate_os="${1}"
	local os_major="${2}"
	local os_minor="${3}"
	local os_patch="${4}"

	# Get free space on the boot disk
	# storage_free_space=$( /usr/bin/osascript -l 'JavaScript' -e "ObjC.import('Foundation'); var freeSpaceBytesRef=Ref(); $.NSURL.fileURLWithPath('/').getResourceValueForKeyError(freeSpaceBytesRef, 'NSURLVolumeAvailableCapacityForImportantUsageKey', null); Math.round(ObjC.unwrap(freeSpaceBytesRef[0]))" )
	storage_free_space=$( /usr/bin/osascript -l "JavaScript" -e '

		ObjC.import("Foundation");
		var freeSpaceBytesRef=Ref();

		$.NSURL.fileURLWithPath("/").getResourceValueForKeyError(
			freeSpaceBytesRef,
			"NSURLVolumeAvailableCapacityForImportantUsageKey",
			null
		);

		Math.round(
			ObjC.unwrap(
				freeSpaceBytesRef[0]
			)
		)
	')

	# Workaround for NSURLVolumeAvailableCapacityForImportantUsageKey returning 0 if no user is logged in - use NSURLVolumeAvailableCapacityKey instead
	if [[ ${storage_free_space} -eq 0 ]]; then
		storage_free_space=$( /usr/bin/osascript -l "JavaScript" -e '

			ObjC.import("Foundation");
			var freeSpaceBytesRef=Ref();

			$.NSURL.fileURLWithPath("/").getResourceValueForKeyError(
				freeSpaceBytesRef,
				"NSURLVolumeAvailableCapacityKey",
				null
			);

			Math.round(
				ObjC.unwrap(
					freeSpaceBytesRef[0]
				)
			)
		')
	fi

	# Set the required free space to compare.  Set space requirement in bytes:  /usr/bin/bc <<< "<space in GB> * 1073741824"
	case "${validate_os}" in
		"Sonoma*"* )
			# Value's inherited from Monterey, Apple has not defined these requirements
			required_free_space_newer="27917287424" # 26GB if Sierra or later
			os_newer="10.12.0"
			required_free_space_older="47244640256" # 44GB if El Capitan or earlier
			os_older="10.11.0"
		;;
		"Ventura*"* )
			# Value's inherited from Monterey, Apple has not defined these requirements
			required_free_space_newer="27917287424" # 26GB if Sierra or later
			os_newer="10.12.0"
			required_free_space_older="47244640256" # 44GB if El Capitan or earlier
			os_older="10.11.0"
		;;
		"Monterey"* )
			required_free_space_newer="27917287424" # 26GB if Sierra or later
			os_newer="10.12.0"
			required_free_space_older="47244640256" # 44GB if El Capitan or earlier
			os_older="10.11.0"
		;;
		"Big Sur"* )
			required_free_space_newer="38117834752" # 35.5GB if Sierra or later
			os_newer="10.12.0"
			required_free_space_older="47781511168" # 44.5GB if El Capitan or earlier
			os_older="10.11.0"
		;;
		"Catalina"*|"Mojave"* )
			required_free_space_newer="13421772800" # 12.5GB if El Capitan 10.11.5 or later
			os_newer="10.11.5"
			required_free_space_older="19864223744" # 18.5GB if Yosemite or earlier
			os_older="10.10.0"
		;;
		"High Sierra"* )
			required_free_space="15354508084" # 14.3GB
		;;
		"Sierra"*|"El Capitan"* )
			required_free_space="9448928052" # 8.8GB
		;;
		* )
			echo "<result>Not Supported</result>"
			exit 0
		;;
	esac

	if [[ -z $required_free_space ]]; then
		newer_os_major=$( echo "${os_newer}" | /usr/bin/awk -F '.' '{print $1}' )
		newer_os_minor=$( echo "${os_newer}" | /usr/bin/awk -F '.' '{print $2}' )
		newer_os_patch=$( echo "${os_newer}" | /usr/bin/awk -F '.' '{print $3}' )
		older_os_major=$( echo "${os_older}" | /usr/bin/awk -F '.' '{print $1}' )
		older_os_minor=$( echo "${os_older}" | /usr/bin/awk -F '.' '{print $2}' )
		older_os_patch=$( echo "${os_older}" | /usr/bin/awk -F '.' '{print $3}' )

		# Check newer
		if [[ "${os_major}" -gt "${newer_os_major}" ||
			( "${os_major}" -eq "${newer_os_major}" &&
			  "${os_minor}" -ge "${newer_os_minor}" &&
			  "${os_patch}" -ge "${newer_os_patch}" ) ]]; then

			required_free_space=$required_free_space_newer

		# Check older
		elif [[ "${os_major}" -gt "${older_os_major}" ||
			  ( "${os_major}" -eq "${older_os_major}" &&
				"${os_minor}" -ge "${older_os_minor}" &&
				"${os_patch}" -ge "${older_os_patch}" ) ]]; then

			required_free_space=$required_free_space_older

		fi

	fi

	if [[  $storage_free_space -le $required_free_space ]]; then
		echo " / Insufficient Storage"
	fi

}

##################################################
# Bits Staged...

# Set the number of bytes in a gigabyte
bytes_in_gigabytes="1073741824" # $((1024 * 1024 * 1024)) # Transforms one gigabyte into bytes

# Get the current OS version
if [[ -z "${TEST_OS}" ]]; then
	os_version=$( /usr/bin/sw_vers -productVersion )
else
	os_version="${TEST_OS}"
	echo "Test OS value: ${TEST_OS}"
fi

current_os_major=$( echo "${os_version}" | /usr/bin/awk -F '.' '{print $1}' )
current_os_minor=$( echo "${os_version}" | /usr/bin/awk -F '.' '{print $2}' )
current_os_patch=$( echo "${os_version}" | /usr/bin/awk -F '.' '{print $3}' )

# Get the Model Type
if [[ -z "${TEST_MODEL}" ]]; then
	mac_model=$( /usr/sbin/sysctl -n hw.model )
else
	mac_model="${TEST_MODEL}"
	echo "Test Model value: ${TEST_MODEL}"
fi

# Check for compatibility
model_result=$( model_check "${mac_model}" )

case "${model_result}" in
	"Sonoma*" )
		version_string="14"
	;;
	"Ventura*" )
		version_string="13"
	;;
	"Monterey" )
		version_string="12"
	;;
	"Big Sur" )
		version_string="11"
	;;
	"Catalina" )
		version_string="10.15"
	;;
	"Mojave" )
		version_string="10.14"
	;;
	"High Sierra" )
		version_string="10.13"
	;;
	"Sierra" )
		version_string="10.12"
	;;
	"El Capitan" )
		version_string="10.11"
	;;
esac

if [[ "${version_string}" =~ ^10[.].+ ]]; then
	test_running_unsupported="${current_os_major}.${current_os_minor}"
else
	test_running_unsupported="${current_os_major}"
fi

if [[ $( /usr/bin/bc <<< "${test_running_unsupported} > ${version_string}" ) -eq 1 ]]; then
	# Check to see if device is running an OS version newer than what it supports.
	# If so, no reason to check further specifications.
	report_result="${model_result} (Model doesn't support current OS version)"

elif [[
		"${version_string}" == "${current_os_major}.${current_os_minor}" ||
		"${version_string}" == "${current_os_major}"
	]]; then
	# Check to see if device is already running the latest supported OS.
	# If so, no reason to check further specifications.

	report_result="${model_result}"

else

	os_result=$( os_check  "${model_result}" "${current_os_major}" "${current_os_minor}" "${current_os_patch}" "${mac_model}" )
	ram_check_results=$( ram_check "${os_result}" )
	storage_check_results=$( storage_check "${os_result}" "${current_os_major}" "${current_os_minor}" "${current_os_patch}" )

	report_result="${ram_check_results}${storage_check_results}"
	model_result="${ram_check_results}${storage_check_results}"

fi

echo "<result>${report_result}</result>"
write_to_ea_history "latest_os_supported" "${model_result}"
exit 0