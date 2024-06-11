#!/bin/bash

###################################################################################################
# Script Name:  Collect-APNSMgmtTopic.sh
# By:  Zack Thompson / Created:  11/3/2023
# Version:  1.0.0 / Updated:  11/20/2023 / By:  ZT
#
# Description:  This script collects specific results from the Get-APNSMDMClientHealth.sh script
#	which reports on the APNS MDM Client and MDM Profile management Topics.
#
#	Pass [--debug | -d ] as an argument to "test" the script and not write to the local EA files.
#
###################################################################################################

##################################################
# Define Variables

# Locally log EA value for historical reference (since Jamf Pro only ever has the last value).
# Supported actions:
#   true - Do locally Log
#   false - Do not log locally
locally_log="true"
local_ea_history="/opt/ManagedFrameworks/EA_History.log"
local_ea_inventory="/opt/ManagedFrameworks/Inventory.plist"
debugging_description="Collect-APNSMgmtTopic.sh:  "

####################
# Compiled Results
local_ea_inventory_compiled_key="apns_mdm_mgmt_topics"

# MDM Profile APNS Topic
local_ea_inventory_mdm_profile_key="mdm_apns_topic"

# APNS Cert and Local Push Topic Comparison
local_ea_inventory_apns_topic_key="apns_topics"

# APNS Cert and Device Push Topic Comparison
local_ea_inventory_apns_and_device_topics="apns_and_device_topics"

# APNS Cert and User Push Topic Comparison
local_ea_inventory_apns_and_user_topics="apns_and_user_topics"

#############################################n#####
# Functions

arg_parse() {
	# Command Line Argument Parser

	while (( "$#" )); do
		# Work through the passed arguments

		case "${1}" in
			-d | --debug )
				debug="true"
				write_to_ea_history "DEBUGGING ENABLED" "${debugging_description}"
			;;
			# * )
			# 	switch="${1}"
			# 	shift
			# 	value="${1}"
			# 	eval "${switch}"="'${value}'"
			# ;;
		esac

		shift
	done
}

write_to_ea_history() {

	# Arguments
	# $1 = (str) Message that will be written to a log file
	# $2 = (str) Optional description that will be written ahead of message

	local message="${1}"
	local description="${2}"

	time_stamp=$( /bin/date +%Y-%m-%d\ %H:%M:%S )

	if [[ "${locally_log}" == "true" && -z "${debug}" ]]; then

		if [[ ! -e "${local_ea_history}" ]]; then

			/bin/mkdir -p "$( /usr/bin/dirname "${local_ea_history}" )"
			/usr/bin/touch "${local_ea_history}"

		fi

		echo "${time_stamp} | ${description}${message}" >> "${local_ea_history}"

	else

		echo "${time_stamp} | ${description}${message}"

	fi

}

get_value() {

	# Arguments
	# $1 = (str) Message that will be recorded to the configured locations

	local key="${1}"

	/usr/bin/defaults read "${local_ea_inventory}" "${key}"

}

##################################################
# Command Line Argument Parser

parameters=( "$@" )
arg_parse "${parameters[@]}"

##################################################
# Bits staged, collect the information...

if [[ ! -e $local_ea_inventory ]]; then
	return_result="Missing local inventory register"
else
	return_result=""

	if [[ "$( get_value "${local_ea_inventory_compiled_key}" )" == "Valid" ]]; then
		return_result="Valid"
	else

		if [[ "$( get_value "${local_ea_inventory_mdm_profile_key}" )" != "Valid" ]]; then
			return_result+="MDM Mgmt Topic is Invalid;"

			if [[ "$( get_value "${local_ea_inventory_apns_topic_key}" )" != "Valid" ]]; then

				if [[ "$( get_value "${local_ea_inventory_apns_and_device_topics}" )" != "Valid" ]]; then
					return_result+=" Device APNS Topics are Invalid;"
				fi

				if [[ "$( get_value "${local_ea_inventory_apns_and_user_topics}" )" != "Valid" ]]; then
					return_result+=" User APNS Topics are Invalid;"
				fi

			fi

		fi
	fi

	if [[ -z $return_result ]]; then
		return_result="Unknown"
	fi

fi

write_to_ea_history "APNS Mgmt Topic Collected:  ${return_result}"
echo "<result>${return_result}</result>"
exit 0