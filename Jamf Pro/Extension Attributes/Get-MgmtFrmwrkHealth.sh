#!/bin/bash
# set -x

####################################################################################################
# Script Name:  Check-MgmtFrmwrkHealth.sh
# By:  Zack Thompson / Created:  4/26/2024
# Version:  1.0.0 / Updated:  4/26/2024 / By:  ZT
#
# Description:  This script checks the state of the Jamf Pro Management Framework and MDM Client.
#
#	Pass [--debug | -d ] as an argument to "test" the script and not write to the local EA files.
#
####################################################################################################

##################################################
# Define Variables

# Enter the Jamf Pro Server FQDN
jamf_pro_base_url="${4}"
# jamf_pro_base_url="jps.server.org"
# APNs Cert Topic
apns_cert_topic_id="${5}"
# apns_cert_topic_id="com.apple.mgmt.External.<Insert APNs Topic GUID Here>"
# JPS Root CA Certificate SHA-1 Hash
jps_root_ca_sha1="${6}"
# jps_root_ca_sha1="<Insert JPS Root CA SHA1 Here>"
# Invitation ID
reenroll_invitation_id="${7}"
# reenroll_invitation_id="<Insert Invitation ID Here>"
# JPS Root CA Certificate Common Name
# jps_root_ca="${8}"
# Custom Event for Test Policy
# jps_health_check_event="${9}"

##################################################
# Set variables for your environment

# Enter the port number of your Jamf Pro Server; this is usually 8443 or 443 -- change if needed.
jps_port="8443"
# verifySSLCert Key
expected_verify_ssl_cert="always"
# JPS Root CA Certificate Common Name
jps_root_ca="<Insert JPS Root CA Certificate Common Name Here>"
# Custom Event for Test Policy
jps_health_check_event="JPS_Health_Check"

##################################################
# Only modify the below variables if needed.

# Set the GUID for the MDM Enrollment Profile.
mdm_profile_identifier="00000000-0000-0000-A000-4A414D460003"
# Jamf Pro Server
jps_url="https://${jamf_pro_base_url}:${jps_port}/"
# Set the location to write logging information for later viewing.
log_file="/opt/ManagedFrameworks/jps_HealthCheck.log"
default_date_format="+%Y-%m-%d %H:%M:%S"
# Set location of local recovery files.
recovery_files="/opt/ManagedFrameworks/jra"
# Location of the Jamf Binary.
jamf_binary="/usr/local/jamf/bin/jamf"
# Location of Jamf Keychain
jamf_keychain="/Library/Application Support/JAMF/JAMF.keychain"
# Set the number of `jamf manage` attempts.
max_manage_attempts=1
manage_attempts=0
# Set the number of `jamf policy` attempts.
max_checkin_attempts=1
checkin_attempts=0
# Set the number of `jamf trustJSS` attempts.
max_trustjss_attempts=1
trustjss_attempts=0

# Locally log EA value for historical reference (since Jamf Pro only ever has the last value).
# Supported actions:
#   true - Do locally Log
#   false - Do not log locally
locally_log="true"
local_ea_history="/opt/ManagedFrameworks/EA_History.log"
local_ea_inventory="/opt/ManagedFrameworks/Inventory.plist"
local_ea_inventory_key="jamf_mgmt_frmwrk_health_check"
debugging_description="Check-MgmtFrmwrkHealth.sh:  "

##################################################
# Helper Functions

arg_parse() {
	# Command Line Argument Parser

	while (( "$#" )); do
		# Loop through the passed arguments

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
	# $2 = (str) Type that will be used for the value
	# $3 = (str) Message that will be assigned to the key
	local key="${1}"
	local type="${2}"
	local value="${3}"

	if [[ "${locally_log}" == "true" && -z "${debug}" ]]; then

		if [[ ! -e "${local_ea_inventory}" ]]; then

			/bin/mkdir -p "$( /usr/bin/dirname "${local_ea_inventory}" )"
			/usr/bin/touch "${local_ea_inventory}"

		fi

		PlistBuddy_Helper "add" "${local_ea_inventory}" "${key}" "${type}" "${value}"

	elif [[ -n "${debug}" ]]; then

		write_to_ea_history "key:  ${key} > value: ${value}"

	fi

	# Optionally, this can be ran as an EA:
	# echo "<result>${value}</result>"

}

write_to_ea_history() {

	# Arguments
	# $1 = (str) Message that will be written to a log file
	# $2 = (str) Optional description that will be written ahead of message
	local message="${1}"
	local description="${2}"

	time_stamp=$( get_time_stamp )

	if [[ "${locally_log}" == "true" && -z "${debug}" ]]; then

		if [[ ! -e "${local_ea_history}" ]]; then

			/bin/mkdir -p "$( /usr/bin/dirname "${local_ea_history}" )"
			/usr/bin/touch "${local_ea_history}"

		fi

		echo "${time_stamp} | ${description}${message}" | /usr/bin/tee -a "${local_ea_history}"

	else

		echo "${time_stamp} | ${description}${message}"

	fi

}

write_to_log() {
	# This function writes to the defined log.

	# Arguments
	# $1 = (str) Message that will be written to a log file
	local time_stamp
	local message="${1}"

	time_stamp=$( get_time_stamp )
	echo "${time_stamp} | ${message}" | /usr/bin/tee -a "${log_file}"
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
		/usr/libexec/PlistBuddy -c "Print :'${key}'" /dev/stdin <<< "${plist}" 2> /dev/null
	elif [[ "${action}" = "read"  ]]; then
		# Read a key
		/usr/libexec/PlistBuddy -c "Print :'${key}'" "${plist}" 2> /dev/null
	elif [[ "${action}" = "add"  ]]; then
		# Configure values
		/usr/libexec/PlistBuddy -c "Add :'${key}' ${type} ${value}" "${plist}" > /dev/null 2>&1 || \
		/usr/libexec/PlistBuddy -c "Set :'${key}' ${value}" "${plist}" > /dev/null 2>&1
	elif [[ "${action}" = "delete"  ]]; then
		# Delete a key
		/usr/libexec/PlistBuddy -c "Delete :'${key}' ${type}" "${plist}" > /dev/null 2>&1
	elif [[ "${action}" = "clear"  ]]; then
		# Clear a key's value
		/usr/libexec/PlistBuddy -c "clear ${type}" "${plist}" > /dev/null 2>&1
	fi
}

exit_process() {
	# This function handles the exit process of the script.

	# Arguments
	# $1 = (str) action to perform on the plist
	# $2 = (int) exit code to exit the script with
	local status="${1}"
	local exit_code="${2}"

	write_to_log "Result: ${status}"
	write_to_ea_inventory "${local_ea_inventory_key}" "string" "${status}"
	write_to_log "*****  Jamf Pro Management Framework Health Check Process:  COMPLETE  *****"
	exit "${exit_code}"
}

repair_performed() {
	# This function handles documenting repairs when they're performed

	# Arguments
	# $1 = (str) The repair that was performed
	local time_stamp previous_total new_total
	local the_repair_performed="${1}"

	time_stamp=$( get_time_stamp )
	previous_total=$( PlistBuddy_Helper "read" "${local_ea_inventory}" "${the_repair_performed}" )
	previous_total_exit_check=$?

	if [[ "${previous_total_exit_check}" == 0 ]]; then
		new_total=$((previous_total + 1))
	else
		new_total=1
	fi

	write_to_log "{ ${the_repair_performed} } repair count:  ${new_total}"

	if [[ -z "${debug}" ]]; then
		PlistBuddy_Helper "add" "${local_ea_inventory}" \
			"${the_repair_performed}" "integer" "${new_total}"
		PlistBuddy_Helper "add" "${local_ea_inventory}" "${local_ea_inventory_key}" \
			"string" "Performed:  ${the_repair_performed} (${new_total})"
		PlistBuddy_Helper "add" "${local_ea_inventory}" "jamf_mgmt_frmwrk_repair_date" "string" "${time_stamp}"
	fi
}

# shellcheck disable=SC2120
get_time_stamp() {
	# Helper function to provide a standard date-time stamp

	# Arguments
	# $1 = (str) Date format to use; otherwise the default will be used
	local date_format="${1}"

	if [[ -z "${date_format}" ]]; then
		date_format="${default_date_format}"
	fi

	/bin/date "${date_format}"
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
# Logic Functions

check_binary_connection() {
	# Verifies that the Jamf binary can successfully communicate 
	# with the Jamf Pro Server; returns result.

	write_to_log "Testing if the Jamf Binary can communicate with the JPS..."
	binaryCommunication=$( "${jamf_binary}" checkJSSConnection > /dev/null; echo $? )

	if [[ "$binaryCommunication" -eq 0 ]]; then
		write_to_log "  -> Success"
	else
		write_to_log "  -> Failed"
		exit_process "Binary cannot communicate with JPS" 3
	fi
}

check_binary_permissions() {
	# Checking the permissions on the Jamf binary; returns result.

	write_to_log "Verifying the Jamf Binary permissions..."
	local current_permissions current_owner
	current_permissions=$( /usr/bin/stat -f "%OLp" "${jamf_binary}" )
	current_owner=$( /usr/bin/stat -f "%Su:%Sg" "${jamf_binary}" )

	# Verifying Permissions
	if [[ $current_permissions == "555" && $current_owner == "root:wheel" ]]; then
		write_to_log "  -> Valid"
	else
		write_to_log "  -> [Warning] Improper permissions found!"
		write_to_log "    -> Currently they are:  ${current_permissions} ${current_owner}"
		write_to_log "      -> Setting proper permissions..."
		/usr/bin/chflags noschg "${jamf_binary}"
		/usr/bin/chflags nouchg "${jamf_binary}"
		/usr/sbin/chown root:wheel "${jamf_binary}"
		/bin/chmod 555 "${jamf_binary}"
		repair_performed "Reset Binary Permissions"
	fi
}

restore_jamf_binary() {
	# Restore the Jamf Binary.

	write_to_log "  -> [Notice] Restoring the Jamf Binary!"

	# Check if the Recovery Binary exists and restore it if not.
	if [[ ! -e "${recovery_files}/jamf" ]]; then
		write_to_log "  -> [Warning] Unable to locate the Jamf Binary in the Recovery Files!"
		write_to_log "    -> Downloading binary from the JPS..."

		if [[ "${current_os_major}" -ge 11 || \
			"${current_os_major}" -eq 10 && "${current_os_minor}" -ge 16
		]]; then
			binary_level="level1"
		elif [[ "${current_os_major}" -eq 10 && "${current_os_minor}" -eq 15 ]]; then
			binary_level="level2"
		elif [[ "${current_os_major}" -eq 10 &&
				$( /usr/bin/bc <<< "${current_os_minor}.${current_os_patch} >= 14.4" ) -eq 1
		]]; then
			binary_level="level3"
		else
			binary_level="level4"
		fi

		curl_return=$( /usr/bin/curl --silent --show-error --fail --request GET \
			"${jps_url}bin/${binary_level}" --output "${recovery_files}/jamf" \
			--write-out "statusCode:%{http_code}" )
		curl_status_code=$(echo "$curl_return" | /usr/bin/awk -F statusCode: '{print $2}')
		if [[ $curl_status_code != "200" ]]; then
			write_to_log "  -> [Error] Failed to restore the Jamf Binary!"
			exit_process "Missing Recovery Jamf Binary" 4
		fi
	fi

	# Create the directory structure and ensure the proper permissions are set.
	/bin/mkdir -p /usr/local/jamf/bin /usr/local/bin
	/bin/cp -f "${recovery_files}/jamf"  "${jamf_binary}"
	/bin/ln -s "${jamf_binary}" /usr/local/bin
	check_binary_permissions
	repair_performed "Restored Binary"
}

check_jps_root_ca_installed() {
	# Does system contain the JPS Root CA?

	if [[ $max_trustjss_attempts -gt $trustjss_attempts ]]; then
		write_to_log "Checking if the JPS Root CA is installed..."
		jps_root_ca_installed=$( /usr/bin/security find-certificate -Z -c "${jps_root_ca}" | \
			/usr/bin/awk -F 'SHA-1 hash: ' '{print $2}' | /usr/bin/xargs )

		if [[ "${jps_root_ca_installed}" == "${jps_root_ca_sha1}" ]]; then
			write_to_log "  -> True"
		else
			write_to_log "  -> [Warning] Root CA is missing!"
			trust_results=$( "${jamf_binary}" trustJSS )
			trust_exit_code=$?

			if [[ "${trust_results}" == *"Unable to add the certificates to the System keychain..."* ]]; then
				write_to_log "  -> [Error] Failed to add the JPS Root CA!"
			elif [[ "${trust_exit_code}" != 0 ]]; then
				write_to_log "  -> [Error] Error attempting to add the JPS Root CA:\n${trust_results}" -e
			else
				repair_performed "jamf trustJSS"
				# Check again
				check_jps_root_ca_installed
			fi
		fi

		trustjss_attempts=$(( trustjss_attempts + 1 ))
	else
		non_hard_stop_errors+=" JPS Root CA not trusted;"
	fi
}

check_validation_policy () {
	# Running a custom Policy Event to check jamf binary functionality; returns result.

	if [[ $max_checkin_attempts -gt $checkin_attempts ]]; then
		write_to_log "Testing if device can run a Policy..."
		check_policy=$( "${jamf_binary}" policy -event "${jps_health_check_event}" )
		check_policy_results=$( echo "${check_policy}" | /usr/bin/grep "Policy Execution Successful!" )

		if [[ -n "${check_policy_results}" ]]; then
			write_to_log "  -> Success"
		else
			write_to_log "  -> [Warning] Unable to execute Policy!"
			manage "failed Validation Policy"

			# After attempting to recover, try executing again.
			check_validation_policy
		fi

		checkin_attempts=$(( checkin_attempts + 1 ))
	else
		non_hard_stop_errors+=" Unable to run Policies;"
	fi
}

check_jps_config() {
	# Verifies the `/Library/Preferences/com.jamfsoftware.jamf` plist exists and configured 
	# as expected, if not, it is created and configured with the proper values.
	write_to_log "Checking local JPS configuration..."

	if [[ -e "/Library/Preferences/com.jamfsoftware.jamf.plist" ]]; then
		jss_url=$( PlistBuddy_Helper "read" "/Library/Preferences/com.jamfsoftware.jamf.plist" jss_url )

		if [[ "${jss_url}" == "${jps_url}" ]]; then
			write_to_log "  -> Valid"
			check_binary_connection
		else
			write_to_log "  -> [Warning] Unexpected JPS URL Specified:  ${jss_url}"
			PlistBuddy_Helper "add" "/Library/Preferences/com.jamfsoftware.jamf.plist" \
				"jss_url" "string" "${jps_url}"
			repair_performed "Configured JPS Server"
		fi

	else
		write_to_log "  -> [Warning] JPS configuration is missing!"
		"${jamf_binary}" createConf -url "${jps_url}" -verifySSLCert "${expected_verify_ssl_cert}"
		repair_performed "Restored JPS Config"
	fi
}

manage() {
	# Creates the config and runs the `jamf manage` command.

	# Arguments
	# $1 = (str) Reason function was called
	local reason="${1}"

	if [[ $max_manage_attempts -gt $manage_attempts ]]; then
		write_to_log "  -> [Notice] Enabling the Management Framework due to ${reason}"
		check_jps_config
		"${jamf_binary}" manage #? -forceMdmEnrollment
		repair_performed "jamf manage"
		manage_attempts=$(( manage_attempts + 1 ))
	elif [[ $max_manage_attempts -eq $manage_attempts ]]; then
		reenroll "${1}"
		manage_attempts=$(( manage_attempts + 1 ))
	else
		exit_process "Unable to repair" 5
	fi
}

reenroll() {
	# Re-enrolls with an enrollment Invitation ID.

	# Arguments
	# $1 = (str) Reason for re-enroll
	local reason="${1}"

	if [[ "${current_os_major}" -eq 10 && "${current_os_minor}" -lt 13 ]]; then
		write_to_log "  -> [Notice] Re-enrolling due to ${reason}"
		"${jamf_binary}" enroll -invitation "${reenroll_invitation_id}" \
			-noRecon -noPolicy -reenroll -archiveDeviceCertificate
		repair_performed "jamf enroll"
	else
		write_to_log "  -> [Error] Device needs to re-enroll!"
		exit_process "Re-enroll required" 6
	fi
}

remove_mdm_profile() {
	# Run the `jamf remove_mdm_profile` command.
	write_to_log "  -> [Warning] Removing the MDM Profile!"
	"${jamf_binary}" remove_mdm_profile
}

remove_framework() {
	# Run the `jamf remove_framework` command.
	write_to_log "  -> [Warning] Removing the Management Framework!"
	"${jamf_binary}" remove_framework #? -keepMDM
}

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

##################################################
# Command Line Argument Parser

parameters=( "$@" )
arg_parse "${parameters[@]}"

##################################################
# Bits staged...

write_to_log "*****  Jamf Pro Management Framework Health Check Process:  START  *****"

non_hard_stop_errors=""

if [[ -e /Library/Preferences/com.jamfsoftware.jamf ]]; then
	/bin/rm /Library/Preferences/com.jamfsoftware.jamf
	PlistBuddy_Helper "delete" "${local_ea_inventory}" "Configured JPS Server" "integer"
	PlistBuddy_Helper "delete" "${local_ea_inventory}" "local_ea_inventory_key" "string"
	PlistBuddy_Helper "delete" "${local_ea_inventory}" "repair_date" "string"
fi

# Get the current OS version
os_version=$( /usr/bin/sw_vers -productVersion )
current_os_major=$( echo "${os_version}" | /usr/bin/awk -F '.' '{print $1}' )
current_os_minor=$( echo "${os_version}" | /usr/bin/awk -F '.' '{print $2}' )
current_os_patch=$( echo "${os_version}" | /usr/bin/awk -F '.' '{print $3}' )

# Verify client is not currently enrolling.
while true; do
	is_device_enrolling=$( /bin/ps aux | /usr/bin/grep --extended-regexp "[jJ](enroll|update)" | /usr/bin/wc -l )
	if [ "${is_device_enrolling}" -gt 0 ]; then
		write_to_log "Conflicting process is running; waiting..."
		/bin/sleep 5
	else
		break
	fi
done

# Check for a valid IP address and can connect to the "outside world"; returns result.
write_to_log "Checking for an active network interface..."
any_active_interfaces=$( /sbin/ifconfig -a inet 2>/dev/null | \
	/usr/bin/sed -n -e '/127.0.0.1/d' -e '/0.0.0.0/d' -e '/inet/p' | /usr/bin/wc -l )

if [ "${any_active_interfaces}" -gt 0 ]; then
	default_interface_id=$( /sbin/route get default | \
		/usr/bin/awk -F 'interface: ' '{print $2}' | /usr/bin/xargs )
	link_status=$( /sbin/ifconfig "${default_interface_id}" | \
		/usr/bin/awk -F 'status: ' '{print $2}' | /usr/bin/xargs )
	if [[ "${link_status}" == "active" ]]; then
		write_to_log "  -> Active interface:  ${default_interface_id}"
	else
		write_to_log "  -> [Warning] Unable to determine the default/active interface"
	fi
else
	write_to_log "  -> [Notice] Device is offline"
	exit_process "Device is offline" 1
fi

# Verifies that the Jamf Pro Servers' Tomcat service 
# is responding via its assigned port; returns result.
write_to_log "Testing if the Jamf web service available..."
jps_web_service=$( /usr/bin/nc -z -w 5 $jamf_pro_base_url $jps_port > /dev/null 2>&1; echo $? )

if [ "${jps_web_service}" -eq 0 ]; then
	write_to_log "  -> Success"
else
	write_to_log "  -> Failed"
	exit_process "JPS Web Service Unavailable" 2
fi

# Verify the Binary exists first.
write_to_log "Verifying the Jamf Binary exists..."

if [[ -e "${jamf_binary}" ]]; then
	write_to_log "  -> True"
	check_binary_permissions
else
	write_to_log "  -> [Warning] Unable to locate the Jamf Binary!"
	restore_jamf_binary
fi

# Does the Jamf Application Support folder exists?
if [[ ! -e "/Library/Application Support/JAMF" ]]; then
	write_to_log "  -> [Warning] The Jamf Application Support folder is missing!"
	reenroll " / Missing Application Support"
fi

# Does the JAMF.keychain exist?
write_to_log "Verifying the Jamf Keychain exists..."

if [[ -e "${jamf_keychain}" ]]; then
	write_to_log "  -> True"
elif [[ -e "${recovery_files}/JAMF.keychain" ]]; then
	write_to_log "  -> [Warning] Jamf Keychain is missing!"
	/bin/cp -f "${recovery_files}/JAMF.keychain"  "${jamf_keychain}"
	repair_performed "Restored Jamf Keychain"
else
	write_to_log "  -> [Warning] Unable to locate the Jamf Keychain!"
	reenroll "Missing Jamf Keychain"
fi

# Checking the permissions on the Jamf Keychain; returns result.
write_to_log "Verifying the Jamf Keychain permissions..."
current_permissions=$( /usr/bin/stat -f "%OLp" "${jamf_keychain}" )
current_owner=$( /usr/bin/stat -f "%Su:%Sg" "${jamf_keychain}" )

# Verifying Permissions
if [[ $current_permissions == "600" && $current_owner == "root:admin" ]]; then
	write_to_log "  -> Valid"
else
	write_to_log "  -> [Warning] Improper permissions found!"
	write_to_log "    -> Current permissions:  ${current_permissions} ${current_owner}"
	write_to_log "      -> Setting proper permissions..."
	/usr/bin/chflags noschg "${jamf_keychain}"
	/usr/bin/chflags nouchg "${jamf_keychain}"
	/usr/sbin/chown root:admin "${jamf_keychain}"
	/bin/chmod 600 "${jamf_keychain}"
	repair_performed "Reset Keychain Permissions"
fi

# Does the Jamf Software configuration exist and is it configured as expected?
check_jps_config

# # Does system contain the JPS Root CA?
# write_to_log "Checking if the JPS Root CA is installed..."
# jps_root_ca_installed=$( /usr/bin/security find-certificate -Z -c "${jps_root_ca}" | \
# 	/usr/bin/awk -F 'SHA-1 hash: ' '{print $2}' | /usr/bin/xargs )

# if [[ "${jps_root_ca_installed}" == "${jps_root_ca_sha1}" ]]; then
# 	write_to_log "  -> True"
# else
# 	write_to_log "  -> [Warning] Root CA is missing!"
# 	trust_results=$( "${jamf_binary}" trustJSS )
# 	trust_exit_code=$?

# 	if [[ "${trust_results}" == *"Unable to add the certificates to the System keychain..."* ]]; then
# 		write_to_log "  -> [Error] Failed to add the JPS Root CA!"
# 	elif [[ "${trust_exit_code}" != 0 ]]; then
# 		write_to_log "  -> [Error] Error attempting to add the JPS Root CA:\n${trust_results}" -e
# 	else
# 		repair_performed "jamf trustJSS"
# 		# After attempting to recover, try executing again.

# 	fi

# fi

# Run the check_jps_root_ca_installed Function
check_jps_root_ca_installed

# Run the check_validation_policy Function
check_validation_policy

# Update local recovery files.
write_to_log "Updating the Recovery Files..."
jamf_binary_version=$( "${jamf_binary}" version | \
	/usr/bin/awk -F 'version=' '{print $2}' | /usr/bin/xargs )

if [[ -e "${recovery_files}/jamf" ]]; then
	jamf_recovery_binary_version=$( "${recovery_files}/jamf" version | \
		/usr/bin/awk -F 'version=' '{print $2}' | /usr/bin/xargs )

	# Compares the current version and updates if there is a newer binary available.
	if [[ "${jamf_binary_version}" == "${jamf_recovery_binary_version}" ]]; then
		write_to_log "  -> Current"
	else
		write_to_log "  -> Updating recovery Jamf Binary"
		/bin/cp -f "${jamf_binary}" "${recovery_files}"
		PlistBuddy_Helper "add" "${local_ea_inventory}" "latest_JamfBinaryVersion" \
			"string" "${jamf_binary_version}"
	fi

else
	/bin/mkdir -p "${recovery_files}"
	write_to_log "  -> Creating a recovery Jamf Binary"
	/bin/cp -f "${jamf_binary}" "${recovery_files}"
	PlistBuddy_Helper "add" "${local_ea_inventory}" "latest_JamfBinaryVersion" \
		"string" "${jamf_binary_version}"
fi

# Backup the Jamf Keychain and server configuration.
/bin/cp -f "${jamf_keychain}" "${recovery_files}"

# Check the MDM Identity Certificate
write_to_log "Validating MDM Identity Certificate..."
mdm_identity_cert_common_name=$( find_identity_from_keychain )

if [[ -n "${mdm_identity_cert_common_name}" ]]; then
	write_to_log "  -> Common Name:  ${mdm_identity_cert_common_name}"

	mdm_identity_cert_details=$( get_certificate_full_details "${mdm_identity_cert_common_name}" )
	mdm_identity_cert_serial_number=$( get_certificate_detail "${mdm_identity_cert_details}" "Serial Number: " )
	write_to_log "  -> Serial Number:  ${mdm_identity_cert_serial_number}"

	mdm_identity_cert_issued_by=$( get_certificate_detail "${mdm_identity_cert_details}" "Issuer: CN=" )
	if [[ "${mdm_identity_cert_issued_by}" != "${jps_root_ca}" ]]; then
		write_to_log "  -> Issued By:  ${mdm_identity_cert_issued_by}"
		write_to_log "    -> [Error] Invalid MDM Identity Cert"
		non_hard_stop_errors+=" Invalid MDM Identity Cert;"
	fi

	mdm_identity_cert_expires=$( get_certificate_detail "${mdm_identity_cert_details}" "Not After : " )
	write_to_log "  -> Expires:  ${mdm_identity_cert_expires}"
	mdm_identity_cert_expires_epoch=$( convert_date \
		"${mdm_identity_cert_expires}" "%b %e %H:%M:%S %Y" "%s" )
	write_to_log "  -> Expires in epoch:  ${mdm_identity_cert_expires_epoch}"
	current_epoch=$( convert_date "" "" "%s" )

	if [[ "${mdm_identity_cert_expires_epoch}" -lt "${current_epoch}" ]]; then
		write_to_log "    -> [Error] Expired"
		non_hard_stop_errors+=" Expired MDM Identity Cert;"
	fi

else
	write_to_log "  -> [Error] MDM Identity Certificate not found!"
	write_to_log "  -> Identifies found in:  /Library/Keychains/System.keychain"
	non_hard_stop_errors+=" Missing MDM Identity Cert;"
	/usr/bin/security find-identity -v "/Library/Keychains/System.keychain"
fi

# Check the JMF Identity Certificate
write_to_log "Validating JMF Identity Certificate..."
uuid=$( /usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice | \
	/usr/bin/awk '/IOPlatformUUID/ { split($0, line, "\""); printf("%s\n", line[4]); }' )
jmf_identity_cert_common_name=$( find_identity_from_keychain "" "${jamf_keychain}" )

if [[ -n "${jmf_identity_cert_common_name}" ]]; then
	write_to_log "  -> Common Name:  ${jmf_identity_cert_common_name}"

	if [[ "${uuid}" != "${jmf_identity_cert_common_name}" ]]; then
		write_to_log "  -> [Warning] JMF Identity Doesn't Match:  ${uuid}"
		non_hard_stop_errors+=" JMF Identity Cert Doesn't Match UUID;"
	fi

	jmf_identity_cert_details=$( get_certificate_full_details \
		"${jmf_identity_cert_common_name}" "${jamf_keychain}" )
	jmf_identity_cert_serial_number=$( get_certificate_detail "${jmf_identity_cert_details}" "Serial Number: " )
	write_to_log "  -> Serial Number:  ${jmf_identity_cert_serial_number}"

	jmf_identity_cert_issued_by=$( get_certificate_detail "${jmf_identity_cert_details}" "Issuer: CN=" )
	if [[ "${jmf_identity_cert_issued_by}" != "${jps_root_ca}" ]]; then
		write_to_log "  -> Issued By:  ${jmf_identity_cert_issued_by}"
		write_to_log "    -> [Error] Invalid JMF Identity Cert"
		non_hard_stop_errors+=" Invalid JMF Identity Cert;"
	fi

	jmf_identity_cert_expires=$( get_certificate_detail "${jmf_identity_cert_details}" "Not After : " )
	write_to_log "  -> Expires:  ${jmf_identity_cert_expires}"
	jmf_identity_cert_expires_epoch=$( convert_date \
		"${jmf_identity_cert_expires}" "%b %e %H:%M:%S %Y" "%s" )
	write_to_log "  -> Expires in epoch:  ${jmf_identity_cert_expires_epoch}"
	current_epoch=$( convert_date "" "" "%s" )

	if [[ "${jmf_identity_cert_expires_epoch}" -lt "${current_epoch}" ]]; then
		write_to_log "    -> [Error] Expired"
		non_hard_stop_errors+=" Expired JMF Identity Cert;"
	fi

else
	write_to_log "  -> [Error] JMF Identity Certificate not found!"
	write_to_log "  -> Identifies found in:  ${jamf_keychain}"
	non_hard_stop_errors+=" Missing JMF Identity Cert;"
	/usr/bin/security find-identity -v "${jamf_keychain}"
fi

# Check the version of the profiles utility.
profiles_cmd_version=$( /usr/bin/profiles version | \
	/usr/bin/awk -F 'version: ' '{print $2}' | /usr/bin/xargs )

# if [[ $( /usr/bin/bc <<< "${profiles_cmd_version} >= 8.30" ) -eq 1 ]]; then
# 	# profiles_cached_parameter="-cached"
# 	profiles_list_parameter="list"
# else
# 	# profiles_cached_parameter=""

	if [[ $( /usr/bin/bc <<< "${profiles_cmd_version} >= 6.01" ) -eq 1 ]]; then
			profiles_list_parameter="list"
	else
			profiles_list_parameter="-P"
	fi
# fi

# Does system contain the MDM Enrollment Profile?
write_to_log "Checking if the MDM Profile is installed..."

# Dump installed Profiles to stdout in XML format
all_profiles=$( /usr/bin/profiles "${profiles_list_parameter}" -output "stdout-xml" )

# Get the number of installed profiles
number_of_profiles=$(
	PlistBuddy_Helper "print" "${all_profiles}" "_computerlevel" | \
	/usr/bin/grep --text --extended-regexp "^    Dict {$" | /usr/bin/wc -l | /usr/bin/xargs
)

# Loop through the Profile, searching for the one we're looking for.
for (( count=0; count < number_of_profiles; ++count )); do

	if [[ "${break_loop}" == "true" ]]; then
		break
	fi

	identifier=$(
		PlistBuddy_Helper "print" "${all_profiles}" "_computerlevel:${count}:ProfileIdentifier"
	)

	if [[ "${identifier}" == "${mdm_profile_identifier}" ]]; then
		write_to_log "  -> True"
		mdm_profile_installed="true"

		# Validate MDM Profile payload
		write_to_log "Validating MDM Profile..."

		number_of_profile_items=$(
			PlistBuddy_Helper "print" "${all_profiles}" "_computerlevel:${count}:ProfileItems" | \
			/usr/bin/grep --text --extended-regexp "^    Dict {$" | /usr/bin/wc -l | /usr/bin/xargs
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
				break_loop="true"

				payload_content_topic=$(
					PlistBuddy_Helper "print" "${all_profiles}" \
					"_computerlevel:${count}:ProfileItems:${profile_items_count}:PayloadContent:Topic"
				)

				if [[ "${payload_content_topic}" == "${apns_cert_topic_id}" ]]; then
					write_to_log "  -> APNs Topic is valid"
				else
					write_to_log "  -> [Error] APNs Topic is invalid:  ${payload_content_topic}"
					exit_process "MDM Profile APNs Topic is invalid" 7
				fi

				payload_content_checkinurl=$(
					PlistBuddy_Helper "print" "${all_profiles}" \
					"_computerlevel:${count}:ProfileItems:${profile_items_count}:PayloadContent:CheckInURL"
				)

				# echo "payload_content_checkinurl:  ${payload_content_checkinurl}"

				if [[ 
					"${payload_content_checkinurl}" =~ ${jps_url}(mdm/CheckInURL|/computer/mdm)(\?invitation=[0-9]+)?
				]]; then
					invitation_id=$( echo "${payload_content_checkinurl}" | \
						/usr/bin/awk -F '=' '{print $2}' )
					write_to_log "  -> CheckInURL is valid"
					write_to_log "    -> CheckInURL Invitation ID:  ${invitation_id}"
				else
					write_to_log "  -> [Error] CheckInURL is invalid:  ${payload_content_checkinurl}"
					exit_process "MDM Profile CheckInURL is invalid" 8
				fi

				payload_content_serverurl=$(
					PlistBuddy_Helper "print" "${all_profiles}" \
					"_computerlevel:${count}:ProfileItems:${profile_items_count}:PayloadContent:ServerURL"
				)

				if [[ "${payload_content_serverurl}" =~ ${jps_url}(mdm/ServerURL|/computer/mdm) ]]; then
					write_to_log "  -> ServerURL is valid"
				else
					write_to_log "  -> [Error] ServerURL is invalid:  ${payload_content_serverurl}"
					exit_process "MDM Profile ServerURL is invalid" 9
				fi

			fi

		done

	fi

done

if [[ "${mdm_profile_installed}" != "true" ]]; then
	write_to_log "  -> [Error] MDM Profile is missing!"
	# manage "missing MDM Profile"
	exit_process "MDM Profile is missing" 11
fi

if [[ "${current_os_major}" -eq 10 && "${current_os_minor}" -ge 11 ]]; then
	# Check for MDM Client Errors
	write_to_log "Checking for MDM Client errors..."
	mdm_client_logs=$( /usr/bin/log show --style compact \
		--predicate '(process CONTAINS "mdmclient")' --last 1d )
	mdm_identity_error=$( echo "${mdm_client_logs}" | /usr/bin/grep "Unable to create MDM identity" )

	if [[ -z "${mdm_identity_error}" ]]; then
		write_to_log "  -> No MDM communication errors found"
	else
		write_to_log "  -> [Error] Unable to create MDM identity"
		exit_process "Unable to create MDM identity" 10
	fi
fi

if [[ -n "${non_hard_stop_errors}" ]]; then
	# Trim leading space
	non_hard_stop_errors="${non_hard_stop_errors## }"
	# Trim trailing ;
	exit_process "${non_hard_stop_errors%%;}" 12
else
	exit_process "Good" 0
fi