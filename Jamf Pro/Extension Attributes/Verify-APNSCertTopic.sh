#!/bin/bash
# set -x

####################################################################################################
# Script Name:  Verify-APNSCertTopic.sh
# By:  Zack Thompson / Created:  11/3/2023
# Version:  1.0.0 / Updated:  11/3/2023 / By:  ZT
#
# Description:  This script checks if the the APNS MDM
#	Client and MDM Profile management topics match.
#
####################################################################################################

##################################################
# Set variables for your environment

# Pass a value in the first argument to "test" the script and not write to the local EA files.
testing="${1}"

# Jamf Pro Server URL
jamf_pro_server=$( /usr/bin/defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url )

# APNS Cert Topic
# Can be obtained from https://identity.apple.com/pushcert/ 
# 	or https://<jps.url.org>:8443/pushNotificationCertificate.html
if [[ "${jamf_pro_server}" =~ .*production.* ]]; then
	apple_mgmt_cert="com.apple.mgmt.External.<INSERT_APNs_TOPIC_GUID_HERE"
elif [[ "${jamf_pro_server}" =~ .*development.* ]]; then
	apple_mgmt_cert="com.apple.mgmt.External.INSERT_APNs_TOPIC_GUID_HERE"
fi

# MDM Profile Identifier
mdm_profile_identifier="00000000-0000-0000-A000-4A414D460003"

# Locally log EA value for historical reference (since Jamf Pro only ever has the last value).
# Supported actions:
#   true - Do locally Log
#   false - Do not log locally
locally_log="true"
local_ea_history="/opt/ManagedFrameworks/EA_History.log"
local_ea_history_identifier="APNS/MDM Management Topics:  "
local_ea_inventory="/opt/ManagedFrameworks/Inventory.plist"
local_ea_inventory_identifier="apns_mdm_health"

##################################################
# Functions

write_to_ea_inventory() {

	# Arguments
	# $1 = (str) Plist key that the message value will be assigned too
	# $2 = (str) Message that will be assigned to the key

	local key="${1}"
	local value="${2}"

	if [[ "${locally_log}" == "true" && -z "${testing}" ]]; then

		if [[ ! -e "${local_ea_inventory}" ]]; then

			/bin/mkdir -p "$( /usr/bin/dirname "${local_ea_inventory}" )"
			/usr/bin/touch "${local_ea_inventory}"

		fi

		/usr/bin/defaults write "${local_ea_inventory}" "${key}" "${value}"

	fi

}

write_to_ea_history() {

	# Arguments
	# $1 = (str) Message that will be written to a log file

	local message="${1}"

	time_stamp=$( /bin/date +%Y-%m-%d\ %H:%M:%S )

	if [[ "${locally_log}" == "true" && -z "${testing}" ]]; then

		if [[ ! -e "${local_ea_history}" ]]; then

			/bin/mkdir -p "$( /usr/bin/dirname "${local_ea_history}" )"
			/usr/bin/touch "${local_ea_history}"

		fi

		echo "${time_stamp} | ${local_ea_history_identifier}${message}" >> "${local_ea_history}"

	else

		echo "${time_stamp} | ${local_ea_history_identifier}${message}"

	fi

}

report_result() {

	# Arguments
	# $1 = (str) Message that will be recorded to the configured locations

	local message="${1}"

	write_to_ea_history "${message}"
	write_to_ea_inventory "${local_ea_inventory_identifier}" "${message}"
	echo "<result>${message}</result>"
	exit 0

}

PlistBuddy_Helper() {
	# Helper function to interact with plists.

	# Arguments
	# $1 = (str) action to perform on the plist
		# The "print" action expects to work with text (passed to PlistBuddy
		# via stdin), which can be generated via "print_xml"
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

		# Dump plist file as XML
		/usr/libexec/PlistBuddy -x -c "print" "${plist}" 2> /dev/null

	elif [[ "${action}" = "print"  ]]; then

		# Read plist "str" (as a heredoc) and print the passed key
		/usr/libexec/PlistBuddy -c "Print :${key}" /dev/stdin <<< "${plist}" 2> /dev/null

	elif [[ "${action}" = "add"  ]]; then

		# Configure values
		/usr/libexec/PlistBuddy -c "Add :${key} ${type} ${value}" "${plist}" > /dev/null 2>&1 || \
		/usr/libexec/PlistBuddy -c "Set :${key} ${value}" "${plist}" > /dev/null 2>&1

	elif [[ "${action}" = "delete"  ]]; then

		# Delete a key
		/usr/libexec/PlistBuddy -c "Delete :${key} ${type}" "${plist}" > /dev/null 2>&1

	elif [[ "${action}" = "clear"  ]]; then

		# Clear a key's value
		/usr/libexec/PlistBuddy -c "clear ${type}" "${plist}" > /dev/null 2>&1

	fi

}

##################################################
# Bits staged, collect the information...

# Dump installed Profiles to stdout in XML format
all_profiles=$( /usr/bin/profiles show -cached --output "stdout-xml" )

# Get the number of installed profiles
number_of_profiles=$(
	PlistBuddy_Helper "print" "${all_profiles}" "_computerlevel" | \
	/usr/bin/grep -a -E "^    Dict {$" | /usr/bin/wc -l | /usr/bin/xargs
)

mdm_profile_matches="Unable to validate MDM Profile"

# Loop through the Profile, searching for the one we're looking for.
for (( count=0; count < number_of_profiles; ++count )); do

	if [[ "${break_loop}" == "true" ]]; then
		break
	fi

	identifier=$(
		PlistBuddy_Helper "print" "${all_profiles}" "_computerlevel:${count}:ProfileIdentifier"
	)

	if [[ "${identifier}" == "${mdm_profile_identifier}" ]]; then

		number_of_profile_items=$(
			PlistBuddy_Helper "print" "${all_profiles}" "_computerlevel:${count}:ProfileItems" | \
			/usr/bin/grep -a -E "^    Dict {$" | /usr/bin/wc -l | /usr/bin/xargs
		)

		for ((
			profile_items_count=0;
			profile_items_count < number_of_profile_items;
			++profile_items_count
		)); do

			if [[ "${break_loop}" == "true" ]]; then
				break
			fi

			payload_type=$(
				PlistBuddy_Helper "print" "${all_profiles}" \
				"_computerlevel:${count}:ProfileItems:${profile_items_count}:PayloadType"
			)

			if [[ "${payload_type}" == "com.apple.mdm" ]]; then

				payload_content_topic=$(
					PlistBuddy_Helper "print" "${all_profiles}" \
					"_computerlevel:${count}:ProfileItems:${profile_items_count}:PayloadContent:Topic"
				)

				if [[ "${payload_content_topic}" == "${apple_mgmt_cert}" ]]; then

					write_to_ea_history "MDM Profile's APNS Topic is valid"
					mdm_profile_matches="true"
					break_loop="true"

				else

					write_to_ea_history "[ERROR] MDM Profile's APNS Topic is invalid!"
					write_to_ea_history "MDM Profile APNS Topic:  ${payload_content_topic}"
					break_loop="true"
					mdm_profile_matches="false"

				fi

			fi

		done

	fi

done

# Check APNS status for the MDM Client service
apns_stats=$( /System/Library/PrivateFrameworks/ApplePushService.framework/apsctl status )

if [[ -z "${apns_stats}" ]]; then

	apns_topic_matches="Unable to validate APNS Topic"

else

	# Device Channel
	device_apns_stats=$( /usr/bin/osascript -l JavaScript << EndOfScript

		var apns_stats=\`$apns_stats\`

		apns_stats.match(
			/(^\s+application port name:\s+)com.apple.aps.mdmclient.daemon.push.production(.|\n)+?(?=\1)/gm
		)

EndOfScript
)
	device_last_push_topic=$(
		echo "${device_apns_stats}" | \
		/usr/bin/awk -F 'last push notification topic:' '{print $2}' | \
		/usr/bin/xargs
	)

	# User Channel
	user_apns_stats=$( /usr/bin/osascript -l JavaScript << EndOfScript

		var apns_stats=\`$apns_stats\`

		apns_stats.match(
			/(^\s+application port name:\s+)com.apple.aps.mdmclient.agent.push.production(.|\n)+?(?=\1)/gm
		)

EndOfScript
)
	user_last_push_topic=$(
		echo "${user_apns_stats}" | \
		/usr/bin/awk -F 'last push notification topic:' '{print $2}' | \
		/usr/bin/xargs
	)

	if [[
		"${apple_mgmt_cert}" == "${device_last_push_topic}" &&
		"${apple_mgmt_cert}" == "${user_last_push_topic}"
	]]; then
		write_to_ea_history "APNS Topics are valid"
		apns_topic_matches="true"
	else

		write_to_ea_history "[ERROR] APNS Topic does not match!"
		apns_topic_matches=""

		if [[ "${apple_mgmt_cert}" != "${device_last_push_topic}" ]]; then
			write_to_ea_history "Device APNS Topic mismatch:  ${device_last_push_topic}"
			apns_topic_matches+=" Device APNS Topic mismatch;"
		fi

		if [[ "${apple_mgmt_cert}" == "${user_last_push_topic}" ]]; then
			write_to_ea_history "User APNS Topic mismatch:  ${user_last_push_topic}"
			apns_topic_matches+=" User APNS Topic mismatch;"
		fi

	fi

fi

if [[ "${mdm_profile_matches}" = "true" && "${apns_topic_matches}" = "true" ]]; then
	report_result "Valid"
else

	# Hold statuses
	return_result=""

	if [[ "${mdm_profile_matches}" = "false" ]]; then
		return_result+=" MDM Profile Mismatch;"
	elif [[ "${mdm_profile_matches}" != "true" ]]; then
		return_result+=" ${mdm_profile_matches};"
	fi

	if [[ "${apns_topic_matches}" != "true" ]]; then
		return_result+=" ${apns_topic_matches}"
	fi

fi

# Trim leading space
return_result="${return_result## }"
# Trim trailing ;
report_result "${return_result%%;}"
