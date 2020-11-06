#!/bin/bash

###################################################################################################
# Script Name:  jamf_db_maint.sh
# By:  Zack Thompson / Created:  2/28/2020
# Version:  1.0.0 / Updated:  2/28/2020 / By:  ZT
#
# Description:  This script is used to perform database maintenance on the Jamf Pro database.
#
###################################################################################################

# Function to display help text
displayHelp() {
echo "
usage:  jamf-db_maint.sh [ --step | --full ] | [ -help ]

Info:	This script is used to perform database maintenance on the
        Jamf Pro database.

Actions:
	-s | --step     Modify one database table at a time and 
        then prompt to continue.

	-f | --full     Complete the script without prompting
        to continue.

	-h | --help     Displays this help dialog.
"
}

##################################################
# Process Defined Variables

# Work through the passed arguments
if [[ -n "${1}" ]]; then
    
    case "${1}" in
        "-s" | "--step" )
            fullSpeedAhead="No"
        ;;
        "-f" | "--full" )
            fullSpeedAhead="Yes"
        ;;
        "-h" | "--help" )
            displayHelp
            exit 0
        ;;
        * )
            echo "Unknown argument"
            displayHelp
            exit 1
        ;;
    esac

else

    read -p "Do you want to be prompted before modifying each table? [y|n]  " answer

    # Turn on case-insensitive pattern matching
    shopt -s nocasematch

    case "${answer}" in
        "Yes" | "y" )
            fullSpeedAhead="No"
        ;;
        "No" | "n" | "no" )
            fullSpeedAhead="Yes"
        ;;
        * )
            displayHelp
            exit 1
        ;;
    esac

    # Turn off case-insensitive pattern matching
    shopt -u nocasematch

fi

# Prompt for username
read -p "MySQL username:  " mysqlUser

# Securely prompt for password
IFS= read -rsp "MySQL password:  " MYSQL_PWD

# Export MySQL Password to clear warning
export MYSQL_PWD
echo ""

# Prompt for a directory to save a log file
read -p "Provide directory where log file will be saved:  " logDirectory

# Prompt for the database
read -p "Provide the name of the Jamf Pro database:  " jamfDatabase

mysqlBinary="/usr/bin/mysql"
logFile="${logDirectory}/jamf_DBMaintenance.log"

if [[ ! -d "${logDirectory}" ]]; then
    mkdir "${logDirectory}"
fi

# Verify the MySQL Binary is at the expected location, if not, prompt for it
if [[ ! -x "${mysqlBinary}" ]]; then
    read -p "Path to MySQL Binary: " mysqlBinary
fi

##################################################
# Setup Functions

# This function hanldes running SQL queries
mysqlHelper() {
    mysqlQuery="${1}"
    result=$( $mysqlBinary --user="${mysqlUser}" --database="${jamfDatabase}" --table -vvv --execute="${mysqlQuery}" | sed 's/Bye//' )
    verboseHelper "No" "${result}"
}

# This function writes to stdout and the defined log file
verboseHelper() {
    stampIt="${1}"
    message="${2}"

    if [[ "${stampIt}" == "Yes" ]]; then
        echo "$( date +%Y-%m-%d\ %H:%M:%S ):  ${message}"
        echo "$( date +%Y-%m-%d\ %H:%M:%S ):  ${message}" >> "${logFile}"
    else
        echo "${message}"
        echo -e "${message}\n" >> "${logFile}"
    fi
}

# The function will promte to continue or exit early
decisionCheck()  {

    # Turn on case-insensitive pattern matching
    shopt -s nocasematch
    echo ""

    if [[ "${1}" == "tableMaint" ]]; then
        read -p "Continue maintenance on the next table? [y|n]  " decision
    
    elif [[ "${1}" == "tableDrop" ]]; then
        read -p "Drop the backup tables? [y|n]  " decision

    fi

    if [[ -n "${decision}" ]]; then

        case "${decision}" in
            "Yes" | "y" | "ye" )
                echo "Continuing on..."
            ;;
            * )
                verboseHelper "Yes" "Elected to stop maintenance"
                echo "Log written to:  "${logFile}""
                # Clear the environment variable
                unset MYSQL_PWD
                exit 2
            ;;
        esac

    else

        echo "Please provide an answer"
        decisionCheck
    fi

    echo ""
    # Turn off case-insensitive pattern matching
    shopt -u nocasematch

}

##################################################
# Bits Staged

echo ""
echo "**************************************************"
echo "**************************************************"
echo ""

## Clean up unused VPP Icons
verboseHelper "No" "-- ##################################################"
verboseHelper "Yes" "*****  Database maintenance started  *****"
verboseHelper "No" ""
verboseHelper "Yes" "-- icons table"

verboseHelper "Yes" "-- Get total count"
mysqlHelper "SELECT COUNT(*) FROM icons;"

verboseHelper "Yes" "-- Create a backup of the table"
mysqlHelper "CREATE TABLE icons_backup LIKE icons;"
mysqlHelper "INSERT icons_backup SELECT * FROM icons;"

verboseHelper "Yes" "-- Create a table of icon_id's for all icons in use"
mysqlHelper "CREATE TABLE icons_in_use (icon_id int(11));"

verboseHelper "Yes" "-- Finding all used icon_id's"
mysqlHelper "INSERT into icons_in_use SELECT icon_attachment_id AS id FROM ibooks UNION ALL SELECT icon_attachment_id AS id FROM mobile_device_apps UNION ALL SELECT icon_attachment_id AS id FROM mobile_device_configuration_profiles UNION ALL SELECT icon_attachment_id AS id FROM mac_apps UNION ALL SELECT icon_attachment_id AS id FROM os_x_configuration_profiles UNION ALL SELECT icon_attachment_id AS id FROM self_service_plugins UNION ALL SELECT icon_id AS id FROM vpp_mobile_device_app_license_app UNION ALL SELECT icon_id AS id FROM wallpaper_auto_management_settings UNION ALL SELECT self_service_icon_id AS id FROM os_x_configuration_profiles UNION ALL SELECT self_service_icon_id AS id FROM patch_policies UNION ALL SELECT self_service_icon_id AS id FROM policies UNION ALL SELECT profile_id AS id FROM mobile_device_management_commands WHERE command='Wallpaper' UNION ALL SELECT branding_icon_id AS id FROM self_service UNION ALL SELECT branding_image_id AS id FROM self_service;"

verboseHelper "Yes" "-- Delete VPP App Icons not in use"
mysqlHelper "DELETE FROM icons WHERE icon_id NOT IN ( SELECT icon_id FROM icons_in_use ) AND ( filename IN ( \"100x100bb.jpg\", \"100x100bb.png\", \"1024x1024bb.png\", \"512x512bb.png\" ) OR filename REGEXP \"^[0-9]+.(png|jpg)$\");"

verboseHelper "Yes" "-- Get new total count"
mysqlHelper "SELECT COUNT(*) FROM icons;"

if [[ "${fullSpeedAhead}" == "No" ]]; then
    decisionCheck tableMaint
fi

verboseHelper "No" "-- ##################################################"
verboseHelper "Yes" "-- log_actions table"
## Clean up orphaned records in the log_actions table

verboseHelper "Yes" "-- Get total count"
mysqlHelper "SELECT COUNT(*) FROM log_actions;"

verboseHelper "Yes" "-- Get number of orphaned records"
mysqlHelper "SELECT COUNT(*) FROM log_actions WHERE log_id NOT IN ( SELECT log_id FROM logs );"

verboseHelper "Yes" "-- Rename the original table"
mysqlHelper "RENAME TABLE log_actions TO log_actions_original;"

verboseHelper "Yes" "-- Create new table like the old table"
mysqlHelper "CREATE TABLE log_actions LIKE log_actions_original;"

verboseHelper "Yes" "-- Select the non-orphaned records from the original table"
mysqlHelper "INSERT INTO log_actions SELECT * FROM log_actions_original WHERE log_id IN ( SELECT log_id FROM logs );"

verboseHelper "Yes" "-- Verify no orphaned records"
mysqlHelper "SELECT COUNT(*) FROM log_actions WHERE log_id NOT IN ( SELECT log_id FROM logs );"

verboseHelper "Yes" "-- Get new total count"
mysqlHelper "SELECT COUNT(*) FROM log_actions;"

if [[ "${fullSpeedAhead}" == "No" ]]; then
    decisionCheck tableMaint
fi

verboseHelper "No" "-- ##################################################"
verboseHelper "Yes" "-- mobile_device_extension_attribute_values table"
## Clean up orphaned records in the mobile_device_extension_attribute_values table

verboseHelper "Yes" "-- Get total count"
mysqlHelper "SELECT COUNT(*) FROM mobile_device_extension_attribute_values;"

verboseHelper "Yes" "-- Get number of orphaned records"
mysqlHelper "SELECT COUNT(*) FROM mobile_device_extension_attribute_values WHERE report_id NOT IN ( SELECT report_id FROM reports WHERE mobile_device_id > 0 );"

verboseHelper "Yes" "-- Rename the original table"
mysqlHelper "RENAME TABLE mobile_device_extension_attribute_values TO mobile_device_extension_attribute_values_original;"

verboseHelper "Yes" "-- Create new table like the old table"
mysqlHelper "CREATE TABLE mobile_device_extension_attribute_values LIKE mobile_device_extension_attribute_values_original;"

verboseHelper "Yes" "-- Select the non-orphaned records from the original table"
mysqlHelper "INSERT INTO mobile_device_extension_attribute_values SELECT * FROM mobile_device_extension_attribute_values_original WHERE report_id IN ( SELECT report_id FROM reports WHERE mobile_device_id > 0 );"

verboseHelper "Yes" "-- Verify no orphaned records"
mysqlHelper "SELECT COUNT(*) FROM mobile_device_extension_attribute_values WHERE report_id NOT IN ( SELECT report_id FROM reports WHERE mobile_device_id > 0 );"

verboseHelper "Yes" "-- Get new total count"
mysqlHelper "SELECT COUNT(*) FROM mobile_device_extension_attribute_values;"

if [[ "${fullSpeedAhead}" == "No" ]]; then
    decisionCheck tableMaint
fi

verboseHelper "No" "-- ##################################################"
verboseHelper "Yes" "-- locations table"
## Clean up location records -- remove specific records that are "empty" based on the attributes checked *expect* if it is the latest record

verboseHelper "Yes" "-- Get total count"
mysqlHelper "SELECT COUNT(*) FROM locations;"

verboseHelper "Yes" "-- Get number of valid records"
mysqlHelper "SELECT COUNT(*) FROM locations WHERE ( ( username <> '' OR realname <> '' OR room <> '' OR phone <> '' OR email <> '' OR position <> '' ) OR ( location_id IN ( SELECT last_location_id FROM computers_denormalized ) OR location_id IN ( SELECT last_location_id FROM mobile_devices_denormalized )));"

verboseHelper "Yes" "-- Rename the original tables"
mysqlHelper "RENAME TABLE locations TO locations_original;"

verboseHelper "Yes" "-- Create new table like the old table"
mysqlHelper "CREATE TABLE locations LIKE locations_original;"

verboseHelper "Yes" "-- Select the records that are not completely empty"
mysqlHelper "INSERT INTO locations select * from locations_original WHERE ( ( username <> '' OR realname <> '' OR room <> '' OR phone <> '' OR email <> '' OR position <> '' ) OR ( location_id IN ( SELECT last_location_id FROM computers_denormalized ) OR location_id IN ( SELECT last_location_id FROM mobile_devices_denormalized )));"

verboseHelper "Yes" "-- Get new total count"
mysqlHelper "SELECT COUNT(*) FROM locations;"

if [[ "${fullSpeedAhead}" == "No" ]]; then
    decisionCheck tableMaint
fi

verboseHelper "No" "-- ##################################################"
verboseHelper "Yes" "-- location_history table"
## Clean up orphaned records in the location_history table

verboseHelper "Yes" "-- Get total count"
mysqlHelper "SELECT COUNT(*) FROM location_history;"

verboseHelper "Yes" "-- Get number of orphaned records"
mysqlHelper "SELECT COUNT(*) FROM location_history WHERE location_id IN ( SELECT location_id FROM locations );"

verboseHelper "Yes" "-- Rename the original tables"
mysqlHelper "RENAME TABLE location_history TO location_history_original;"

verboseHelper "Yes" "-- Create new table like the old table"
mysqlHelper "CREATE TABLE location_history LIKE location_history_original;"

verboseHelper "Yes" "-- Select the non-orphaned records from the original table"
mysqlHelper "INSERT INTO location_history SELECT * FROM location_history_original WHERE location_id IN ( SELECT location_id FROM locations );"

verboseHelper "Yes" "-- Verify no orphaned records"
mysqlHelper "SELECT COUNT(*) FROM location_history WHERE location_id NOT IN ( SELECT location_id FROM locations );"

verboseHelper "Yes" "-- Get new total count"
mysqlHelper "SELECT COUNT(*) FROM location_history;"

verboseHelper "No" "-- ##################################################"

echo ""
echo "We're almost done!"
echo ""

verboseHelper "No" "-- ##################################################"
verboseHelper "Yes" "-- Optimize tables"
mysqlHelper "OPTIMIZE TABLE log_actions, mobile_device_extension_attribute_values, locations, location_history, icons;"

echo ""
echo "**************************************************"
echo "**************************************************"
echo "**************************************************"
echo ""
echo "Pausing here..."
echo "Please ensure database health before dropping tables..."

decisionCheck tableDrop

verboseHelper "Yes" "-- ##################################################"
verboseHelper "Yes" "-- Drop original and backup tables"
mysqlHelper "DROP TABLE log_actions_original, mobile_device_extension_attribute_values_original, locations_original, location_history_original, icons_backup, icons_in_use, empty_location_records;"

verboseHelper "Yes" "Maintenance complete!"
echo "Log written to:  ${logFile}"

# Clear the environment variable
unset MYSQL_PWD

exit 0