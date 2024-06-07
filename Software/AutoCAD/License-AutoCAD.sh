#!/bin/bash

####################################################################################################
# Script Name:  License-AutoCAD.sh
# By:  Zack Thompson / Created:  3/29/2018
# Version:  1.2.1 / Updated:  6/07/2024 / By:  ZT
#
# Description:  This script applies the license for AutoCAD.
#
####################################################################################################

##################################################
# Define Variables

autodesk_app_support="/Library/Application Support/Autodesk"
license_directory="${autodesk_app_support}/CLM/LGS"
autodesk_lic_helper="${autodesk_app_support}/AdskLicensing/Current/helper/AdskLicensingInstHelper"
default_date_format="+%Y-%m-%d %H:%M:%S"
script_exit_code=0
local_log="/dev/null"

##################################################
# Functions

write_to_log() {
	# This function writes to 'stdout' and the globally defined log file.
	# Arguments
	# 	message = (str) Message that will be written to a log file
	# 	no_timestamp = (flag) Do not append time stamp to message
	# 	-e = (flag) Parse Escape characters in message
	# 	-n = (flag) Do not append newline after message
	# 	-no_tee = (flag) Do not write message to log file
	local message="${1}"

	while (( "$#" )); do
		# Loop through the passed arguments
		case "${2}" in
			-no_timestamp )
				local no_time_stamp="true"
			;;
			-e )
				local parse_escape_characters="true"
			;;
			-n )
				local no_newline="true"
			;;
			-no_tee )
				local no_tee="true"
			;;
		esac
		shift
	done

	if [[ ! "${no_time_stamp}" == "true" ]]; then
		local time_stamp
		time_stamp=$( get_time_stamp )
		message="${time_stamp} | ${message}"
	fi

	if [[ "${no_tee}" == "true" ]]; then
		if [[ "${no_newline}" == "true" ]]; then
			echo -n "${message}"
		elif [[ "${parse_escape_characters}" == "true" ]]; then
			echo -e "${message}"
		else
			echo "${message}"
		fi
	else
		if [[ "${no_newline}" == "true" ]]; then
			echo -n "${message}" | /usr/bin/tee -a "${local_log}"
		elif [[ "${parse_escape_characters}" == "true" ]]; then
			echo -e "${message}" | /usr/bin/tee -a "${local_log}"
		else
			echo "${message}" | /usr/bin/tee -a "${local_log}"
		fi
	fi
}

# shellcheck disable=SC2120
get_time_stamp() {
	# Helper function to provide a standard date-time stamp
	# Arguments
	# 	date_format = (str) Date format to use; otherwise the default will be used
	local date_format="${1}"

	if [[ -z "${date_format}" ]]; then
		date_format="${default_date_format}"
	fi

	/bin/date "${date_format}"
}

exit_script() {
	# This function handles the exit process of the script.

	# Arguments
	# 	$1 = (int) exit code to exit the script with
	local exit_code="${1}"

	if [[ $exit_code -eq 0 ]]; then
		exist_status="COMPLETE"
	else
		exist_status="FAILED"
	fi

	write_to_log "*****  License AutoCAD Process:  ${exist_status}  *****"
	exit "${exit_code}"
}

##################################################
# Bits staged, license software...

write_to_log "*****  License AutoCAD Process:  START  *****"

# Turn on case-insensitive pattern matching
shopt -s nocasematch

# Determine License Type
case "${4}" in
	"T&R" | "Teaching and Research" | "Academic" )
		license_type="Academic"
	;;
	"Admin" | "Administrative" )
		license_type="Administrative"
	;;
	* )
		write_to_log "[Error] Invalid License Type provided"
		exit_script 1
	;;
esac

# Determine License Mechanism
case "${5}" in
	"LM" | "License Manager" | "Network" )
		license_mechanism="NETWORK"

		if [[ $license_type == "Academic" ]]; then

			# For 2019 and older
			license_contents="SERVER licser1.company.com 000000000000 12345
SERVER licser2.company.com 000000000000 12345
SERVER licser3.company.com 000000000000 12345
USE_SERVER"
			# For 2020 and newer
			license_servers="12345@licser1.company.com,12345@licser2.company.com,12345@licser3.company.com"

		elif [[ $license_type == "Administrative" ]]; then

			# For 2019 and older
			license_contents="SERVER licser4.company.com 000000000000 67890
SERVER licser5.company.com 000000000000 67890
SERVER licser6.company.com 000000000000 67890
USE_SERVER"
			# For 2020 and newer
			license_servers="67890@licser4.company.com,67890@licser5.company.com,27005@licser6.company.com"

		fi
	;;
	"Stand Alone" | "Local" | "Serial" )
		write_to_log "[Error] Local license is not supported"
		exit_script 2
	# 	license_mechanism="Local"
	# 	if [[ $license_type == "Academic" ]]; then
	# 		# Functionality would need to be added to support a local license
	# 		write_to_log "Functionality would need to be added to support a local license."
	# 	elif [[ $license_type == "Administrative" ]]; then
	# 		# Functionality would need to be added to support a local license
	# 		write_to_log "Functionality would need to be added to support a local license."
	# 	fi
	;;
	* )
		write_to_log "[Error] Invalid License Mechanism requested"
		exit_script 2
	;;
esac

# Turn off case-insensitive pattern matching
shopt -u nocasematch

write_to_log "Licensing Type:  ${license_type}"
write_to_log "Licensing Mechanism:  ${license_mechanism}"
write_to_log "Searching for installed AutoCAD applications..."

# Find all install AutoCAD versions.
app_paths=$( /usr/bin/find -E /Applications -iregex ".*[/]AutoCAD 20[0-9]{2}[.]app" -type d -prune )

# Verify that a AutoCAD Application was found.
if [[ -z "${app_paths}" ]]; then
	write_to_log "[Error] An instance of AutoCAD was not found"
	exit_script 3
else

	# If the machine has multiple AutoCAD Applications, loop through them...
	while IFS=$'\n' read -r app_path; do

		write_to_log "Application:  ${app_path}"

		# Get the .app's version (just to verify the version and not assume)
		app_version=$(
			/usr/bin/defaults read "${app_path}/Contents/Info.plist" CFBundleName | \
				/usr/bin/awk -F "AutoCAD " '{print $2}'
		)

		write_to_log "Application Version:  ${app_version}"

		if [[ $app_version -le 2019 ]]; then

			# Set the Network License file path for this version
			network_license="${license_directory}/${app_version}"

			# Check if the directory exists
			if [[ ! -d "${network_license}" ]]; then
				/bin/mkdir -p "${network_license}"
			fi

			write_to_log "Applying licensing configuration..."
			cat "${license_contents}" > "${network_license}/LicPath.lic"
			exit_code1=$?

			cat "_${license_mechanism}" > "${network_license}/LGS.data"
			exit_code2=$?

			if [[ $exit_code1 != 0 || $exit_code2 != 0 ]]; then
				write_to_log "[Error] Failed to create license files"
				script_exit_code=6
			fi

		else

			write_to_log "Checking if app version is registered with the licensing service..."
			registered_apps=$( "${autodesk_lic_helper}" list 2>&1 )
			registered_apps_exit=$?

			if [[ $registered_apps_exit != 0 ]]; then
				write_to_log "[Error] Failed to query the Autodesk Licensing Service"
				write_to_log "Exit Code:  ${registered_apps_exit}\nService reported:  ${registered_apps}" -e
				exit_script 4
			fi

			app_found=$( JSON="${registered_apps}" VERSION="${app_version}" LICENSE_SERVERS="${license_servers}" \
				/usr/bin/osascript -l JavaScript << EndOfScript
				// Safely import variables
				const json_string = $.NSProcessInfo.processInfo.environment.objectForKey("JSON").js
				const version = $.NSProcessInfo.processInfo.environment.objectForKey("VERSION").js
				const license_servers = $.NSProcessInfo.processInfo.environment.objectForKey("LICENSE_SERVERS").js

				// Parse the JSON string into an object
				const json_object = JSON.parse(json_string)
				let num_found_apps = json_object.length

				if ( num_found_apps == 0 ) {
					"No products found"
				}
				else {
					for ( let entry of json_object ) {
						if ( entry["sel_prod_ver"].split(".")[0] == version ) {
							if ( entry["lic_server_type"] == "2" &&
								JSON.stringify(entry["lic_servers"]) === JSON.stringify(license_servers.split(","))
							) {
								"Already licensed"
							}
							else {
								entry["sel_prod_key"]+ ";" + entry["sel_prod_ver"]
							}
							break
						}
						else {
							"No matching versions found"
						}
					}
				}
EndOfScript
)

			if [[ "${app_found}" == "No products found" ]]; then
				write_to_log "[Error] No product registered with the Licensing Service!"
				script_exit_code=5
				continue
			elif [[ "${app_found}" == "No matching versions found" ]]; then
				write_to_log "[Error] A matching product version was not registered with the Licensing Service!"
				script_exit_code=6
				continue
			elif [[ "${app_found}" == "Already licensed" ]]; then
				write_to_log "Product version is already registered with the Licensing Service"
				continue
			fi

			product_key=$( echo "${app_found}" | /usr/bin/awk -F ';' '{print $1}' )
			product_version=$( echo "${app_found}" | /usr/bin/awk -F ';' '{print $2}' )
			write_to_log "Product Key:  ${product_key}"
			write_to_log "Product Version:  ${product_version}"

			change_results=$( "${autodesk_lic_helper}" change --prod_key "${product_key}" \
				--prod_ver "${product_version}" --lic_method NETWORK --lic_server_type REDUNDANT \
				--lic_servers "${license_servers}"
			)
			exit_code3=$?

			if [[ $exit_code3 != 0 ]]; then
				write_to_log "[Error] Failed to license product {key '${product_key}'/version '${product_version}'}"
				write_to_log "Exit Code:  ${exit_code3}\nService reported:  ${change_results}" -e
				script_exit_code=7
			fi

			write_to_log "Successfully licensed product {key '${product_key}'/version '${product_version}}'"

		fi

	done < <( echo "${app_paths}" )
fi

write_to_log "AutoCAD has been activated!"
exit_script $script_exit_code