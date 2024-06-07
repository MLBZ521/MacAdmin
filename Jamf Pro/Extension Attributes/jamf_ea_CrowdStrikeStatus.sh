#!/bin/bash
# set -x

###################################################################################################
# Script Name:  jamf_ea_CrowdStrikeStatus.sh
# By:  Zack Thompson / Created:  1/8/2019
# Version:  2.13.0 / Updated:  6/7/2024 / By:  ZT
#
# Description:  This script gets the configuration of the CrowdStrike Falcon Sensor, if installed.
#
###################################################################################################

echo "Checking the CrowdStrike Falcon Sensor configuration..."

##################################################
# Set variables for your environment

# Set whether to remediate the Network Filter State.
# Only force enables if running macOS 11.3 or newer.
# Supported actions:
#   true - if network filter state is disabled, enable it
#   false - do not change network filter state, only report on it
remediate_network_filter="true"

# Set whether CrowdStrike Firmware Analysis is enabled in your Prevention Policy.
# Supported actions:
#   true - Firmware Analysis is enabled
#   false - Firmware Analysis is disabled
csFirmwareAnalysisEnabled="false"

# Set environments' Customer ID (CID)
# Formatted for falconctl stats
declare -a expected_tenant_cids=( \
	"12345678-90AB-CDEF-1234-567890ABCDEF" \
	"ABCDEF12-3456-7890-ABCD-EF1234567890" \
	"23456789-0ABC-DEF-12345-67890ABCDEF1" \
	"BCDEF123-4567-890A-BCDE-F1234567890A"
)
	# ASU Enterprise
	# ASU Engineering
	# ASU NFR Testing
	# ASU Primary
	# ASU-HIPAA
	# KE-RTO

# The number of days before reporting device has not connected to the CrowdStrike Cloud.
lastConnectedVariance=7

# The number of attempts to get information from the
#    Falcon Service with a ten second sleep in-between.
retry=10

# Locally log EA value for historical reference (since Jamf Pro only ever has the last value).
# Supported actions:
#   true - Do locally Log
#   false - Do not log locally
locally_log="true"
local_ea_history="/opt/ManagedFrameworks/EA_History.log"

##################################################
# Functions

write_to_log() {

	# Arguments
	# $1 = (str) Message that will be written to a log file

	local message="${1}"

	if [[ "${locally_log}" == "true" ]]; then

		if [[ ! -e "${local_ea_history}" ]]; then

			/bin/mkdir -p "$( /usr/bin/dirname "${local_ea_history}" )"
			/usr/bin/touch "${local_ea_history}"

		fi

		time_stamp=$( /bin/date +%Y-%m-%d\ %H:%M:%S )
		echo "${time_stamp}:  ${message}" >> "${local_ea_history}"

	fi

}

report_result() {

	# Arguments
	# $1 = (str) Message that will be written to a log file

	local message="${1}"

	write_to_log "CS:F Status:  ${message}"
	echo "<result>${message}</result>"
	exit 0

}

PlistBuddy_Helper() {
	# Helper function to interact with plists.

	# Arguments
	# $1 = (str) action to perform on the plist
		# The "print" action expects to work text (passed to PlistBuddy via stdin), which can be generated via "print_xml"
	# $2 = (str) Path to plist or generated xml
	# $3 = (str) Key or key path to read
	# $4 = (str) Type that will be used for the value
	# $5 = (str) Value to be set to the passed key

	local action="${1}"
	local plist="${2}"
	local key="${3}"
	local type="${4}"
	local value="${5}"

	if [[ "${action}" = "print_xml"  ]]; then

		/usr/libexec/PlistBuddy -x -c "print" "${plist}" 2> /dev/null

	elif [[ "${action}" = "print"  ]]; then

		/usr/libexec/PlistBuddy -c "Print :${key}" /dev/stdin <<< "${plist}" 2> /dev/null

	elif [[ "${action}" = "add"  ]]; then

		# Configure values
		/usr/libexec/PlistBuddy -c "Add :${key} ${type} ${value}" "${plist}" > /dev/null 2>&1 || /usr/libexec/PlistBuddy -c "Set :${key} ${value}" "${plist}" > /dev/null 2>&1

	elif [[ "${action}" = "delete"  ]]; then

		/usr/libexec/PlistBuddy -c "Delete :${key} ${type}" "${plist}" > /dev/null 2>&1

	elif [[ "${action}" = "clear"  ]]; then

		/usr/libexec/PlistBuddy -c "clear ${type}" "${plist}" > /dev/null 2>&1

	fi

}

get_falconctl_stats() {

	# Get the current stats.
	# Arguments
	# $1 = (str) path to falconctl

	"${1}" stats agent_info Communications 2>&1
	# Will eventually move to the --plist format, once it's fully supported
	# "${1}" stats agent_info Communications --plist

}

get_falcon_version() {

	# Get the CS:F Full Version string
	# Arguments
	# $1 = (str) output from `falconctl stats agent_info`

	echo "${1}" | /usr/bin/awk -F "version:" '{print $2}' | /usr/bin/xargs

}

check_last_connection() {

	# Check if the last connected date is older than seven days.
	# Arguments
	# $1 = (str) date formatted string, captured from "last connected date" in `falconctl stats Communications`
	# $2 = (int) number (of days)

	if [[ $( /bin/date -j -f "%b %d %Y %H:%M:%S" "$( echo "${1}" | /usr/bin/sed 's/,//g; s/ at//g; s/ [AP]M//g' )" +"%s" ) -lt $( /bin/date -j -v-"${2}"d +"%s" ) ]]; then

		returnResult+=" Last Connected: ${1};"

	fi

}

sip_status() {

	# Get the status of SIP, if SIP is disabled, no need to check if SysExts, KEXTs, nor FDA are enabled.
	/usr/bin/csrutil status | /usr/bin/awk -F ': ' '{print $2}' | /usr/bin/awk -F '.' '{print $1}'

}

check_system_extension() {

	##### System Extension Verification #####
	# Check if System Extension is active, enabled, and loaded
	# Arguments
	# $1 = (str) current collected results

	local current_results="${1}"

	# Check if the OS version is 11 or newer, if it is, check if the System Extension is enabled.
	if [[ $( /usr/bin/bc <<< "${osMajorVersion} >= 11" ) -eq 1 ]]; then

		if [[ -e "/Library/SystemExtensions/db.plist" ]]; then

			sysext_db=$( PlistBuddy_Helper "print_xml" "/Library/SystemExtensions/db.plist" )

			number_of_known_extensions=$( PlistBuddy_Helper "print" "${sysext_db}" "extensions" | /usr/bin/grep -a -E "^    Dict {$" | /usr/bin/wc -l | /usr/bin/xargs )

			for (( count=0; count < number_of_known_extensions; ++count )); do

				identifier=$( PlistBuddy_Helper "print" "${sysext_db}" "extensions:${count}:identifier" )
				teamID=$( PlistBuddy_Helper "print" "${sysext_db}" "extensions:${count}:teamID" )

				if [[ "${teamID}" == "X9E956P446" && "${identifier}" == "com.crowdstrike.falcon.Agent" ]]; then

					bundle_short_version=$( PlistBuddy_Helper "print" "${sysext_db}" "extensions:${count}:bundleVersion:CFBundleShortVersionString" )
					bundle_version=$( PlistBuddy_Helper "print" "${sysext_db}" "extensions:${count}:bundleVersion:CFBundleVersion" )
					state=$( PlistBuddy_Helper "print" "${sysext_db}" "extensions:${count}:state" )

					# Multiple extension(s)/versions may appear in the database, verify the extension matches the Falcon.app's version
					if [[ "${falcon_app_short_version}.${falcon_app_bundle_version}" == "${bundle_short_version}.${bundle_version}" ]]; then

						# Verify the extension state is the desired state
						if [[ "${state}" == "activated_enabled" || "${state}" == "activated_waiting_to_upgrade" ]]; then

							extension_enabled="true"
							break

						elif [[ "${state}" =~ .*activated.* ]]; then

							matching_activated_version_state="${state}"

						else

							matching_version_state="${state}"

						fi

					fi

				fi

			done

			if [[ "${extension_enabled}" != "true" ]]; then

				if [[ -n $matching_activated_version_state ]]; then

					returnResult+=" SysExt: ${matching_activated_version_state};"

				elif [[ -n $matching_version_state ]]; then

					returnResult+=" SysExt: ${matching_version_state};"

				else

					returnResult+=" SysExt not activated;"

				fi

			fi

			# Check if System Extensions are managed.
			number_of_managed_policies=$( PlistBuddy_Helper "print" "${sysext_db}" "extensionPolicies" | /usr/bin/grep -a -E "^    Dict {$" | /usr/bin/wc -l | /usr/bin/xargs )

			for (( count=0; count < number_of_managed_policies; ++count )); do

				# Check if the extension is managed if it is not activated and enabled
				teamIDAllowed=$( PlistBuddy_Helper "print" "${sysext_db}" "extensionPolicies:${count}:allowedTeamIDs" )
				extensionAllowed=$( PlistBuddy_Helper "print" "${sysext_db}" "extensionPolicies:${count}:allowedExtensions:X9E956P446" )
				extensionTypesAllowed=$( PlistBuddy_Helper "print" "${sysext_db}" "extensionPolicies:${count}:allowedExtensionTypes:X9E956P446" )

				if [[ "${teamIDAllowed}" =~ .*X9E956P446.*  || "${extensionAllowed}" =~ .*com\.crowdstrike\.falcon\.Agent.* ]]; then

					extensions_allowed="true"

				fi

				if [[ "${extensionTypesAllowed}" =~ .*com\.apple\.system_extension\.network_extension.* && "${extensionTypesAllowed}" =~ .*com\.apple\.system_extension\.endpoint_security.* ]]; then

					extensions_types_allowed="true"

				fi

			done

			if [[ "${extensions_allowed}" != "true" ]]; then

				returnResult+=" SysExt not managed;"

			fi

			if [[ "${extensions_types_allowed}" != "true" ]]; then

				returnResult+=" SysExt Types not managed;"

			fi

		else

			returnResult+=" SysExt not enabled or managed;"

		fi

		if [[ "${current_results}" =~ .*Sensor[[:space:]]not[[:space:]]loaded.* ]]; then

			# Check to see if the System Extension is failing to be staged
			# The last minute _should_ be sufficient considering sysextd retries to load the System Extension every ten seconds
			log_sysextd=$( /usr/bin/log show --predicate 'subsystem contains "com.apple.sx"' --style json --last 1m )

			# Yes, the `\u00a0` character is supposed to be in the below conditional -- why?  Ask Apple.
			returnResult+=$( /usr/bin/osascript -l JavaScript << EndOfScript

	var json_object=JSON.parse(\`$log_sysextd\`)
	json_object.reverse()
	var re = new RegExp("^staging bundle from /Applications/Falcon\.app/Contents/Library/SystemExtensions/com\.crowdstrike\.falcon\.Agent\.systemextension to: /Library/SystemExtensions/\.staging/[A-F0-9\-]{36}/com\.crowdstrike\.falcon\.Agent\.systemextension$")

	for ( var entry of json_object ) {

		if ( re.test(entry.eventMessage) ) {

			var stage_message = true

		}

		if ( entry.eventMessage == "unable to copy to\u00a0staging folder: [0: Success]" ) {

			var failed_msg = true

		}

		if ( stage_message && failed_msg ) {

			" Unable to stage SysExt;"

		}

	}
EndOfScript
)

		fi

	fi

}

check_kernel_extension() {

	##### Kernel Extension Verification #####
	# Check if the OS version is 10.13.2 or newer, if it is, check if the KEXT is enabled.
	## Support for 10.13 is dropping at end of 2020!
	### A KEXT will be used on macOS 11 until Apple releases an System Extension API for Firmware Analysis.
	if [[ $( /usr/bin/bc <<< "${osMinorPatchVersion} >= 13.2" ) -eq 1 || ( $( /usr/bin/bc <<< "${osMajorVersion} >= 11" ) -eq 1 && "${csFirmwareAnalysisEnabled}" == "true" ) ]]; then

		# Get how many KEXTs are loaded.
		kextsLoaded=$( /usr/sbin/kextstat | /usr/bin/grep "com.crowdstrike" | /usr/bin/wc -l | /usr/bin/xargs )

		# Compare loaded KEXTs versus expected KEXTs
		if [[ "${kextsLoaded}" -eq 0 ]]; then

			# Check if there's an issue with loading KEXTs
			if [[ -z $( /usr/bin/find "/private/var/db/KernelExtensionManagement" -flags "restricted" -maxdepth 0 2> /dev/null ) ]]; then

				# Device will need to be booted to Recovery and run the following command:  `chflags restricted /private/var/db/KernelExtensionManagement`
				returnResult+=" KEXT loading blocked;"

			else

				returnResult+=" KEXT not loaded;"

			fi

			# Check if the kernel extension is enabled (whether approved by MDM or by a user).
			mdm_cs_sensor=$( /usr/bin/sqlite3 /var/db/SystemPolicyConfiguration/KextPolicy "select allowed from kext_policy_mdm where team_id='X9E956P446';" )
			user_cs_sensor=$( /usr/bin/sqlite3 /var/db/SystemPolicyConfiguration/KextPolicy "select allowed from kext_policy where team_id='X9E956P446' and bundle_id='com.crowdstrike.sensor';" )

			if [[ -n "${mdm_cs_sensor}" || -n "${user_cs_sensor}" ]]; then

				# Combine the results -- not to concerned how it's enabled as long as it _is_ enabled.
				cs_sensor=$(( mdm_cs_sensor + user_cs_sensor ))

				if [[ "${cs_sensor}" -eq 0 ]]; then

					returnResult+=" KEXT not managed;"

				fi

			fi

		fi

	fi

}

check_privacy_preferences() {

	##### Privacy Preferences Profile Control Verification #####
	# Check if Full Disk Access is enabled (whether by MDM or by a user).
	if [[ $( /usr/bin/bc <<< "${osMinorPatchVersion} >= 14" ) -eq 1 || $( /usr/bin/bc <<< "${osMajorVersion} >= 11" ) -eq 1 ]]; then

		# Get the TCC Database version
		tccdbVersion=$( /usr/bin/sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "select value from admin where key == 'version';" )

		if [[ -e "/Library/Application Support/com.apple.TCC/MDMOverrides.plist" ]]; then

			tcc_mdm_db=$( PlistBuddy_Helper "print_xml" "/Library/Application Support/com.apple.TCC/MDMOverrides.plist" )

		fi

		mdm_fda_enabled=$( PlistBuddy_Helper "print" "${tcc_mdm_db}" "com.crowdstrike.falcon.Agent:kTCCServiceSystemPolicyAllFiles:Allowed" )

		# Check which version of the TCC database being accessed
		if [[ $tccdbVersion -eq 15 ]]; then

			user_fda_enabled=$( /usr/bin/sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "select allowed from access where service = 'kTCCServiceSystemPolicyAllFiles' and client like 'com.crowdstrike.falcon.Agent';" )

		elif [[ $tccdbVersion -eq 19 ]]; then

			user_fda_enabled=$( /usr/bin/sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "select auth_value from access where service = 'kTCCServiceSystemPolicyAllFiles' and client like 'com.crowdstrike.falcon.Agent';" )

		fi

	fi

	# Not to concerned how it's enabled as long as it _is_ enabled.
	if [[ "${mdm_fda_enabled}" != "true" && "${mdm_fda_enabled}" -ne 1 && "${user_fda_enabled}" -ne 1 ]]; then

		returnResult+=" FDA not managed;"

	fi

}

check_network_filter() {

	##### Network Filter State Verification #####
	# Using an official, unsupported, but "more reliable" method for validating the Network Filter Status
	/usr/bin/defaults read "/Library/Application Support/CrowdStrike/Falcon/simplestore.plist" "networkFilterEnabled"

}

##################################################
# Bits staged, collect the information...

# Possible falconctl binary locations
falconctl_app_location="/Applications/Falcon.app/Contents/Resources/falconctl"
falconctl_old_location="/Library/CS/falconctl"

# Get OS Version Details
osVersion=$( /usr/bin/sw_vers -productVersion )
osMajorVersion=$( echo "${osVersion}" | /usr/bin/awk -F '.' '{print $1}' )
osMinorPatchVersion=$( echo "${osVersion}" | /usr/bin/awk -F '.' '{print $2"."$3}' )

# Hold statuses
returnResult=""

if [[ -e "${falconctl_app_location}" && -e "${falconctl_old_location}" ]]; then

	# Multiple versions installed
	report_result "ERROR:  Multiple CS:F versions installed"

elif [[ -e "${falconctl_app_location}" ]]; then

	falconctl="${falconctl_app_location}"

elif [[ -e "${falconctl_old_location}" ]]; then

	report_result "Sensor Version Not Supported"

elif [[ "${osMajorVersion}" == "10" && $( /usr/bin/bc <<< "${osMinorPatchVersion} < 14" ) -eq 1 ]]; then

	# macOS 10.13 or older
	report_result "OS Version Not Supported"

else

	report_result "Not Installed"

fi

# Check the Locale; this will affect the output of falconctl stats
lib_locale=$( /usr/bin/defaults read "/Library/Preferences/.GlobalPreferences.plist" AppleLocale )
root_locale=$( /usr/bin/defaults read "/var/root/Library/Preferences/.GlobalPreferences.plist" AppleLocale )

if [[ "${lib_locale}" != "en_US" ]]; then
	/usr/bin/defaults write "/Library/Preferences/.GlobalPreferences.plist" AppleLocale "en_US"
fi

if [[ "${root_locale}" != "en_US" ]]; then
	/usr/bin/defaults write "/var/root/Library/Preferences/.GlobalPreferences.plist" AppleLocale "en_US"
fi

falcon_app_short_version=$( /usr/bin/defaults read "/Applications/Falcon.app/Contents/Info.plist" CFBundleShortVersionString )
falcon_app_bundle_version=$( /usr/bin/defaults read "/Applications/Falcon.app/Contents/Info.plist" CFBundleVersion )

# Get falconctl stats
falconctlStats=$( get_falconctl_stats "${falconctl}" )

# Ensure falconctl stats command was successful and a version was obtained
while [[ "${falconctlStats}" == "Error: Error while accessing Falcon service" || "${falconctlStats}" == "" ]]; do

	echo "Waiting for the Falcon Sensor to load..."

	# "Error: Error while accessing Falcon service"
		# This can happen if the Falcon Sensor is not loaded
		# This could be due to an in-progress upgrade or other reasons (Malware, user, etc.)

	# echo "Failed to get required details, sleeping and trying again..."

	if [[ $retry == 0 ]]; then

		if [[ "${falconctlStats}" == "" ]]; then

			returnResult+=" Sensor not loaded - reboot may resolve;"

		else

			returnResult+=" Sensor not loaded;"

		fi

		check_system_extension "${returnResult}"

		check_kernel_extension

		check_privacy_preferences

		# Trim leading space
		returnResult="${returnResult## }"
		# Trim trailing ;
		report_result "${returnResult%%;}"

	fi

	retry=$(( retry - 1 ))
	sleep 10

	# Get falconctl stats
	falconctlStats=$( get_falconctl_stats "${falconctl}" )

done

# Check CS Version
if [[ $( /usr/bin/bc <<< "${falcon_app_short_version} >= 6" ) -eq 1 && $( /usr/bin/bc <<< "${osMajorVersion} >= 11" ) -eq 1 ]]; then

	# Get the Sensor State
	sensorState=$( echo "${falconctlStats}" | /usr/bin/awk -F "Sensor operational:" '{print $2}' | /usr/bin/xargs )

	# Verify Sensor State
	if [[ "${sensorState}" != "true" && -n "${sensorState}" ]]; then

		returnResult+=" Sensor State: ${sensorState};"

	fi

fi

# Check CS Version
if [[ $( /usr/bin/bc <<< "${falcon_app_short_version} < 6.18" ) -eq 1 ]]; then

	report_result "Sensor Version Not Supported"

else

	csCustomerID=$( echo "${falconctlStats}" | /usr/bin/awk -F "customerID:" '{print $2}' | /usr/bin/xargs )

fi

# Verify CS Customer ID (CID)
if [[ -z "${csCustomerID}" ]]; then
	returnResult+=" Sensor not licensed;"
elif [[ "${expected_tenant_cids[*]}" =~ $csCustomerID ]]; then
	echo "Valid CID found."
elif [[ -n "${cid}"  ]]; then
	returnResult+=" Invalid Customer ID;"
fi

# Get the connection established dates.
connectionState=$( echo "${falconctlStats}" | /usr/bin/awk -F "State:" '{print $2}' | /usr/bin/xargs )
established=$( echo "${falconctlStats}" | /usr/bin/awk -F "[^Last] Established At:" '{print $2}' | /usr/bin/xargs )
lastEstablished=$( echo "${falconctlStats}" | /usr/bin/awk -F "Last Established At:" '{print $2}' | /usr/bin/xargs )

if [[ "${connectionState}" == "connected" ]]; then

	# Compare if both were available.
	if [[ -n "${established}" && -n "${lastEstablished}" ]]; then

		# Check which is more recent.
		if [[ $( /bin/date -j -f "%b %d %Y %H:%M:%S" "$(echo "${established}" | /usr/bin/sed 's/,//g; s/ at//g; s/ [AP]M//g')" +"%s" ) -ge $( /bin/date -j -f "%b %d %Y %H:%M:%S" "$(echo "${lastEstablished}" | /usr/bin/sed 's/,//g; s/ at//g; s/ [AP]M//g')" +"%s" ) ]]; then

			testConnectionDate="${established}"

		else

			testConnectionDate="${lastEstablished}"

		fi

		# Check if the more recent date is older than seven days
		check_last_connection "${testConnectionDate}" $lastConnectedVariance

	elif [[ -n "${established}" ]]; then

		# If only the Established date was available, check if it is older than seven days.
		check_last_connection "${established}" $lastConnectedVariance

	elif [[ -n "${lastEstablished}" ]]; then

		# If only the Last Established date was available, check if it is older than seven days.
		check_last_connection "${lastEstablished}" $lastConnectedVariance

	else

		# If no connection date was available, return disconnected
		returnResult+=" Unknown Connection State;"

	fi

elif [[ -n "${connectionState}" ]]; then

	# If no connection date was available, return state
	returnResult+=" Connection State: ${connectionState};"

fi

filter_state=$( check_network_filter )

if [[ "${filter_state}" != "1" ]]; then

	if [[ "${remediate_network_filter}" == "true" ]]; then

		# Only force enable the network filter if running macOS 11.3 or newer
		if [[ $( /usr/bin/bc <<< "${osMajorVersion} >= 11" ) -eq 1 && $( /usr/bin/bc <<< "${osMinorPatchVersion} >= 3" ) -eq 1  ]]; then

			# shellcheck disable=SC2034
			enable_filter_results=$( "${falconctl}" enable-filter )
			cs_filter_exit_code=$?
			# echo "enable_filter_results:  ${enable_filter_results}"

			if [[ $cs_filter_exit_code -ne 0 ]]; then

				# Return that we are unable to enable the network filter
				returnResult+=" Unable to enable network filter;"

			fi

		fi

	else

		# Return that the network filter is disabled
		returnResult+=" Network filter disabled;"

	fi

fi

check_system_extension

check_kernel_extension

check_privacy_preferences

# Return the EA Value.
if [[ -n "${returnResult}" ]]; then

	# Trim leading space
	returnResult="${returnResult## }"
	# Trim trailing ;
	report_result "${returnResult%%;}"

else

	report_result "Running"

fi
