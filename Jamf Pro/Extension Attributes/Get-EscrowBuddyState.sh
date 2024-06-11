#!/bin/bash
# set -x

####################################################################################################
# Script Name:  Get-EscrowBuddyState.sh
# By:  Zack Thompson / Created:  4/17/2024
# Version:  1.0.0 / Updated:  4/17/2024 / By:  ZT
#
# Description:  This script checks the state of Escrow Buddy on a Mac.
#
#	Pass [--debug | -d ] as an argument to "test" the script and not write to the local EA files.
#
####################################################################################################

##################################################
# Set variables for your environment

# Locally log EA value for historical reference (since Jamf Pro only ever has the last value).
# Supported actions:
#   true - Do locally Log
#   false - Do not log locally
locally_log="true"
local_ea_history="/opt/ManagedFrameworks/EA_History.log"
local_ea_inventory="/opt/ManagedFrameworks/Inventory.plist"
debugging_description="Get-EscrowBuddyState.sh:  "
local_ea_inventory_key="escrow_buddy_state"

##################################################
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

write_to_ea_inventory() {

	# Arguments
	# $1 = (str) Plist key that the message value will be assigned too
	# $2 = (str) Message that will be assigned to the key

	local key="${1}"
	local value="${2}"

	if [[ "${locally_log}" == "true" && -z "${debug}" ]]; then

		if [[ ! -e "${local_ea_inventory}" ]]; then

			/bin/mkdir -p "$( /usr/bin/dirname "${local_ea_inventory}" )"
			/usr/bin/touch "${local_ea_inventory}"

		fi

		/usr/bin/defaults write "${local_ea_inventory}" "${key}" "${value}"
		echo "<result>${value}</result>"

	elif [[ -n "${debug}" ]]; then

		write_to_ea_history "key:  ${key} > value: ${value}"

	fi

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

	if [[ "${action}" == "print_xml"  ]]; then

		# Dump plist file as XML
		/usr/libexec/PlistBuddy -x -c "print" "${plist}" 2> /dev/null

	elif [[ "${action}" == "print"  ]]; then

		# Read plist "str" (as a heredoc) and print the passed key
		/usr/libexec/PlistBuddy -c "Print :${key}" /dev/stdin <<< "${plist}" 2> /dev/null

	elif [[ "${action}" == "read"  ]]; then

		# Read a key
		/usr/libexec/PlistBuddy -c "Print :${key}" "${plist}" 2> /dev/null

	elif [[ "${action}" == "add"  ]]; then

		# Configure values
		/usr/libexec/PlistBuddy -c "Add :${key} ${type} ${value}" "${plist}" > /dev/null 2>&1 || \
		/usr/libexec/PlistBuddy -c "Set :${key} ${value}" "${plist}" > /dev/null 2>&1

	elif [[ "${action}" == "delete"  ]]; then

		# Delete a key
		/usr/libexec/PlistBuddy -c "Delete :${key} ${type}" "${plist}" > /dev/null 2>&1

	elif [[ "${action}" == "clear"  ]]; then

		# Clear a key's value
		/usr/libexec/PlistBuddy -c "clear ${type}" "${plist}" > /dev/null 2>&1

	fi

}

##################################################
# Command Line Argument Parser

parameters=( "$@" )
arg_parse "${parameters[@]}"

##################################################
# Bits staged...

if [[ ! -e "/Library/Security/SecurityAgentPlugins/Escrow Buddy.bundle" ]]; then
	write_to_ea_history "Escrow Buddy:  Not installed"
	write_to_ea_inventory "${local_ea_inventory_key}" "Not Installed"
else

	escrow_buddy_configured=$( /usr/bin/security authorizationdb read system.login.console 2>&1 )

	if [[ ! ${escrow_buddy_configured} == *"<string>Escrow Buddy:Invoke,privileged</string>"* ]]; then
		write_to_ea_history "Escrow Buddy:  Not configured in the Authorization DB"
		write_to_ea_inventory "${local_ea_inventory_key}" "Not Configured in Authorization DB"
	else

		gen_new_key=$( PlistBuddy_Helper "read" "/Library/Preferences/com.netflix.Escrow-Buddy.plist" "GenerateNewKey" )
		echo "gen_new_key:  \`${gen_new_key}\`"
		# PlistBuddy_Helper "print" "/Library/Preferences/com.netflix.Escrow-Buddy" "GenerateNewKey"

		if [[ ${gen_new_key} == "true" ]]; then
			write_to_ea_history "Escrow Buddy:  Configured to generate a new PRK"
			write_to_ea_inventory "${local_ea_inventory_key}" "Enabled"
		elif [[ -e "/var/db/FileVaultPRK.dat" ]]; then
			write_to_ea_history "Escrow Buddy:  PRK is pending escrow"
			write_to_ea_inventory "${local_ea_inventory_key}" "Pending Escrow"
			# Below command doesn't working on Monterey (and likely older...)
			# pending_prk=$( /usr/bin/openssl cms -cmsout -in /var/db/FileVaultPRK.dat -inform DER -noout -print )
			# echo "${pending_prk}"
		elif [[ ${gen_new_key} == "false" ]]; then
			write_to_ea_history "Escrow Buddy:  Not configured to generate a new PRK"
			write_to_ea_inventory "${local_ea_inventory_key}" "Disabled"
		else
			write_to_ea_history "Escrow Buddy:  Unknown state"
			write_to_ea_inventory "${local_ea_inventory_key}" "Unknown"
		fi

	fi

fi

exit 0