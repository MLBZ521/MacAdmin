#!/bin/bash
# set -x

####################################################################################################
# Script Name:  Collect-JMFCertHealth.sh
# By:  Zack Thompson / Created:  4/26/2024
# Version:  1.0.0 / Updated:  4/26/2024 / By:  ZT
#
# Description:  This script validates the Jamf Management Framework Device Identity Certificate.
#
####################################################################################################

##################################################
# Define variables

# JPS Root CA Certificate Common Name
jps_root_ca="<Insert JPS Root CA Certificate Common Name Here>"

# Locally log EA value for historical reference (since Jamf Pro only ever has the last value).
# Supported actions:
#   true - Do locally Log
#   false - Do not log locally
locally_log="true"
local_ea_history="/opt/ManagedFrameworks/EA_History.log"
local_ea_history_identifier="JMF Cert Health Check:  "
local_ea_inventory="/opt/ManagedFrameworks/Inventory.plist"
local_ea_inventory_identifier="jmf_cert_health"

# Location of Jamf Keychain
jamf_keychain="/Library/Application Support/JAMF/JAMF.keychain"

##################################################
# Functions

write_to_ea_inventory() {
	# Write message to the local EA Inventory plist.

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
	# Write message to the local EA History log.

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
	# Handles writing the result to the local sources and out
	# to stdout for collection via Jamf Pro's EA recon process.

	# Arguments
	# $1 = (str) Message that will be recorded to the configured locations
	local message="${1}"

	write_to_ea_history "${message}"
	write_to_ea_inventory "${local_ea_inventory_identifier}" "${message}"
	echo "<result>${message}</result>"
	exit 0
}

##################################################
# Logic Functions

# shellcheck disable=SC2120
find_identity_from_keychain() {
	# This function searches a keychain for a specific identity cert.
	# Expects a Regex pattern to search for.

	# Arguments
	# $1 = (str) Common Name Regex Pattern
		# Default = "[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}"
	# $2 = (int) Keychain to search
		# Default = "/Library/Keychains/System.keychain"
	local common_name_pattern="${1}"
	local keychain="${2}"

	if [[ -z "${common_name_pattern}" ]]; then
		common_name_pattern="[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}"
	fi

	if [[ -z "${keychain}" ]]; then
		keychain="/Library/Keychains/System.keychain"
	fi

	/usr/bin/security find-identity -v "${keychain}" | \
		/usr/bin/grep --extended-regexp "${common_name_pattern}" | \
		/usr/bin/awk -F ' ' '{print $3}' | /usr/bin/sed 's/"//g'
}

get_certificate_full_details() {
	# This function takes a certificate common name and outputs its complete details.

	# Arguments
	# $1 = (str) Certificate Common Name
	# $2 = (int) Keychain to search
		# Default = "/Library/Keychains/System.keychain"
	local cert_common_name="${1}"
	local keychain="${2}"

	if [[ -z "${keychain}" ]]; then
		keychain="/Library/Keychains/System.keychain"
	fi

	/usr/bin/security find-certificate -p -c "${cert_common_name}" "${keychain}" | \
		/usr/bin/openssl x509 -text
}

get_certificate_detail() {
	# This function searches for a specific detail of a certificate.

	# Arguments
	# $1 = (str) Full Certificate details
	# $2 = (int) Specific detail to search for
	local full_cert_details="${1}"
	local search_pattern="${2}"

	echo "${full_cert_details}" | /usr/bin/awk -F "${search_pattern}" '{print $2}' | /usr/bin/xargs
}

convert_date(){
	# Convert a formatted date string into another format.

	# Arguments
	# $1 = (str) a date in string format
	# $2 = (str) the input format of the date string
	# $3 = (str) the output format of the date string
	local date_string="${1}"
	local input_format="${2}"
	local output_format="${3}"

	if [[ -n "${date_string}" ]]; then
		/bin/date -j -f "${input_format}" "${date_string}" +"${output_format}" 2>/dev/null
	else
		/bin/date -j +"${output_format}"
	fi
}

##################################################
# Bits staged, collect the information...

jmf_identity_cert_common_name=$( find_identity_from_keychain "" "${jamf_keychain}" )
jmf_identity_cert_details=$( get_certificate_full_details \
	"${jmf_identity_cert_common_name}" "${jamf_keychain}" )
jmf_identity_cert_issued_by=$( get_certificate_detail "${jmf_identity_cert_details}" "Issuer: CN=" )
jmf_identity_cert_expires=$( get_certificate_detail "${jmf_identity_cert_details}" "Not After : " )
jmf_identity_cert_expires_epoch=$( convert_date \
	"${jmf_identity_cert_expires}" "%b %e %H:%M:%S %Y" "%s" )
current_epoch=$( convert_date "" "" "%s" )

# echo "jmf_identity_cert_common_name:  ${jmf_identity_cert_common_name}"
# echo "jmf_identity_cert_issued_by:  ${jmf_identity_cert_issued_by}"
# echo "jmf_identity_cert_expires:  ${jmf_identity_cert_expires}"
# echo "jmf_identity_cert_expires_epoch:  ${jmf_identity_cert_expires_epoch}"
# echo "current_epoch:  ${current_epoch}"

uuid=$( /usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice | \
	/usr/bin/awk '/IOPlatformUUID/ { split($0, line, "\""); printf("%s\n", line[4]); }' )

if [[ -z "${jmf_identity_cert_common_name}" ]]; then
	result="Not found"
elif [[ "${jmf_identity_cert_issued_by}" != "${jps_root_ca}" ]]; then
	result="Invalid:  ${jmf_identity_cert_issued_by}"
elif [[ "${uuid}" != "${jmf_identity_cert_common_name}" ]]; then
	result="JMF Identity Doesn't Match:  ${jmf_identity_cert_issued_by}"
elif [[ "${jmf_identity_cert_expires_epoch}" -lt "${current_epoch}" ]]; then
	result="Expired"
else
	result="Valid"
fi

report_result "${result}"