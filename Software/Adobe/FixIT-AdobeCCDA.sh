#!/bin/bash

###################################################################################################
# Script Name:  FixIT-AdobeApps.sh
# By:  Zack Thompson / Created:  11/8/2021
# Version:  1.0.0 / Updated:  11/8/2021 / By:  ZT
#
# Description:  This script attempts to fix several known and common issues with Adobe's Apps.
#
###################################################################################################

echo -e "*****  Fix-IT - Adobe CC:  START  *****\n"

##################################################
# Define Variables

available_actions="Basic Reset
Advanced Reset
Common CCDA Issues
Common Acrobat Issues
Clear Acrobat Sign-in Credentials"
# Run Adobe's 'Limited Access Repair Tool'

temp_dir="/private/tmp"

##################################################
# Define Functions

exit_check() {
	if [[ $1 != 0 ]]; then
		echo "ERROR:  ${3}"
		echo "Reason:  ${2}"
		echo "Exit Code:  ${1}"
		echo "*****  Fix-IT - Adobe CC:  FAILED  *****"
		exit 2
	fi
}

# Get the Logged In Console User
get_logged_in_user() {

	# Get the Console User
    console_user=$( /usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | 
        /usr/bin/awk '/Name :/ && ! /loginwindow/ { print $3 }' )

	if [[ "${console_user}" = "" ]]; then

		echo "${USER}"

	else

		echo "${console_user}"

	fi

}

# Kill the passed pid
kill_process() {
    # $1:  ID of Process; PID
    # $2:  Name of Process

    echo "Killing process:  ${2}"
    /bin/kill "${1}"

}

backup_file(){
    # $1:  File Path
    # $2:  Type of "backup" to perform; options are:
        # copy:  create a copy, leaving the current file in place
        # move:  rename current file, "erasing" current file

	# If file exists, back it up.
	if [[ -e "${1}" ]]; then

        echo "Backing up:  ${1}"
        dateStamp=$( /bin/date +%Y-%m-%d_%H.%M.%S )

        if [[ "${2}" == "copy" ]]; then

            /bin/cp "${1}" "${1}_${dateStamp}"

        elif [[ "${2}" == "move" ]]; then

            /bin/mv "${1}" "${1}_${dateStamp}"

        fi

	fi

}

get_login_keychain(){

    /usr/bin/security login-keychain | /usr/bin/xargs

}

force_quit_adobe_processes() {

    adobe_processes=$( /bin/ps -ax -o pid,comm | /usr/bin/grep --ignore-case "Adobe" | /usr/bin/grep -v "grep" )

    if [[ -n "${adobe_processes}" ]]; then

        while IFS=$'\n' read adobe_process; do

            adobe_pid=$( echo "${adobe_process}" | /usr/bin/awk -F " " '{print $1}' )
            adobe_process_name=$( echo "${adobe_process}" | /usr/bin/awk -F " /" '{print $2}' )

            # Function kill_process
            kill_process "${adobe_pid}" "${adobe_process_name}"

        done < <( /usr/bin/printf '%s\n' "${adobe_processes}" )

    fi

}

reset_adobe_files() {
    # Source, #5 - #7:  https://helpx.adobe.com/enterprise/kb/resolve-trial-and-license-expired-errors.html
    # Supposedly these items are no longer applicable to versions of the CCDA 2019 and newer per Adobe Support

    user=$( get_logged_in_user )

    declare -a items_To_reset=(
        "/Library/Application Support/Adobe/SLCache" \
        "/Library/Application Support/Adobe/SLStore" \
        "/Users/${user}/Library/Application Support/Adobe/OOBE/opm.db"
    )

    # Loop through the items to reset
    for item in "${items_To_reset[@]}" ; do

        backup_file "${item}" "move"

    done

}

find_keychain_item() {
    # $1:  Keychain query (switches) to search for
    # $2:  Keychain to search within

    # Is item a generic password?
    if [[ $( /usr/bin/security find-generic-password "${1}" "${2}") ]]; then 

        echo "generic"

    # Is item an internet password?
    elif [[ $( /usr/bin/security find-internet-password "${1}" "${2}" ) ]]; then 

        echo "internet"

    fi

}

delete_keychain_items() {
    # $1:  Type of Keychain item
    # $2:  Keychain query (switches) to to delete
    # $3:  Keychain to search within

    if [[ "${1}" == "generic" ]]; then 

        /usr/bin/security delete-generic-password "${2}" "${3}"

    elif [[ "${1}" == "internet" ]]; then 

        /usr/bin/security delete-internet-password "${2}" "${3}"

    fi

    # old/original
    # if [[ $( /usr/bin/security find-generic-password \
    #         -s "Adobe User Info" -a "User DT" -C "note" ) ]]; then 

    #     backup_file "$( get_login_keychain )" "copy"

    #     echo "Deleting the \`Adobe User Info\` Keychain Note..."
    #     /usr/bin/security delete-generic-password \
    #         -s "Adobe User Info" -a "User DT" -C "note"

    # fi

}

delete_from_keychain_Adobe_User_Info() {

    login_Keychain=$( get_login_keychain )
    query=(-s "Adobe User Info" -a "User DT" -C "note")
    keychain_type=$( find_keychain_item "${query[@]}" "${login_Keychain}" )

    if [[  -n "${keychain_type}" ]]; then 

        backup_file "$( get_login_keychain )" "copy"

        echo "Deleting the \`Adobe User Info\` Keychain Note..."
        delete_keychain_items "${keychain_type}" "${query[@]}" "${login_Keychain}"

    fi

    unset keychain_type

    # old/original
    # if [[ $( /usr/bin/security find-generic-password \
    #         -s "Adobe User Info" -a "User DT" -C "note" ) ]]; then 

    #     backup_file "$( get_login_keychain )" "copy"

    #     echo "Deleting the \`Adobe User Info\` Keychain Note..."
    #     /usr/bin/security delete-generic-password \
    #         -s "Adobe User Info" -a "User DT" -C "note"

    # fi

}

remove_from_keychain_Acrobat_All() {

    login_Keychain=$( get_login_keychain )

    # Get all Adobe Entires
    all_Acrobat_Keychain_entries=$( 
        /usr/bin/security dump-keychain -r "${login_Keychain}" \
        | /usr/bin/grep '0x00000007 <blob>=' \
        | /usr/bin/awk -F '0x00000007 <blob>=' '{print $2}' \
        | /usr/bin/sed 's/"//g' \
        | /usr/bin/grep --extended-regexp --ignore-case "Acrobat|Adobe\.APS"
    )

    if [[ -n "${all_Acrobat_Keychain_entries}" ]]; then

        backup_file "${login_Keychain}" "copy"

        while IFS=$'\n' read Acrobat_Keychain_entry; do
            
            query=(-l "${Acrobat_Keychain_entry}")

            keychain_type=$( find_keychain_item "${query[@]}" "${login_Keychain}" )

            if [[  -n "${keychain_type}" ]]; then 

                echo "Deleting Keychain item:   ${Acrobat_Keychain_entry}"
                delete_keychain_items "${keychain_type}" "${query[@]}" "${login_Keychain}"

            fi

            unset keychain_type

        done < <( /usr/bin/printf '%s\n' "${all_Acrobat_Keychain_entries}" )

    fi

}

remove_from_keychain_Adobe_All() {

    login_Keychain=$( get_login_keychain )

    # Get all Adobe Entires
    all_Adobe_Keychain_entries=$( 
        /usr/bin/security dump-keychain -r "${login_Keychain}" \
        | /usr/bin/grep '"svce"<blob>=' \
        | /usr/bin/awk -F '"svce"<blob>=' '{print $2}' \
        | /usr/bin/sed 's/"//g' \
        | /usr/bin/grep --ignore-case "Adobe"
    )

    if [[ -n "${all_Adobe_Keychain_entries}" ]]; then

        backup_file "${login_Keychain}" "copy"

        while IFS=$'\n' read Adobe_Keychain_entry; do

            query=(-l "${Adobe_Keychain_entry}")

            keychain_type=$( find_keychain_item "${query[@]}" "${login_Keychain}" )

            if [[  -n "${keychain_type}" ]]; then 

                echo "Deleting Keychain item:   ${Adobe_Keychain_entry}"
                delete_keychain_items "${keychain_type}" "${query[@]}" "${login_Keychain}"

            fi

            unset keychain_type

            # echo "Deleting Keychain item:   ${Adobe_Keychain_entry}"
            # /usr/bin/security  delete-generic-password -l "${Adobe_Keychain_entry}"

        done < <( /usr/bin/printf '%s\n' "${all_Adobe_Keychain_entries}" )

    fi

}

reset_ccda_service_config() {
    # Sources:
        # https://helpx.adobe.com/enterprise/kb/apps-tab-disabled.html
        # https://web.archive.org/web/20190727025154/https://helpx.adobe.com/creative-cloud/kb/apps-tab-missing.html

    adobe_config_path="/Library/Application Support/Adobe/OOBE/Configs"
    adobe_service_config_path="${adobe_config_path}/ServiceConfig.xml"

    if [[ -e "${adobe_service_config_path}" ]]; then

        # /bin/cat "${adobe_service_config_path}" \
        # | /usr/bin/xmllint --format - \
        # | xpath_tool ".panel/[name='AppsPanel']/visible"

        apps_panel_visible_value=$( 
            /bin/cat "${adobe_service_config_path}" \
            | /usr/bin/grep -o "<panel>.*</panel>" \
            | /usr/bin/awk -F "<name>AppsPanel</name>" '{print $2}' \
            | /usr/bin/grep -o "<visible>.*</visible>" \
            | /usr/bin/sed -e 's/<[^/>]*>//g' \
            | /usr/bin/sed -e 's/<[^>]*>//g' 
        )

        if [[ "${apps_panel_visible_value}" != "true" ]]; then

            echo "AppsPanel is currently hidden, setting it to visible..."
            /usr/bin/sed -i '' \
            's-<panel><name>AppsPanel</name><visible>.*</visible></panel>-<panel><name>AppsPanel</name><visible>true</visible></panel>-' \
            "${adobe_service_config_path}"

        fi

        self_install_enabled_value=$( 
            /bin/cat "${adobe_service_config_path}" \
            | /usr/bin/grep -o "<feature>.*</feature>" \
            | /usr/bin/awk -F "<name>SelfServeInstalls</name>" '{print $2}' \
            | /usr/bin/grep -o "<enabled>.*</enabled>" \
            | /usr/bin/sed -e 's/<[^/>]*>//g' \
            | /usr/bin/sed -e 's/<[^>]*>//g' 
        )

        if [[ "${self_install_enabled_value}" != "true" ]]; then

            echo "SelfServeInstalls is currently disabled, setting it to enabled..."
            /usr/bin/sed -i '' \
            's-<feature><name>SelfServeInstalls</name><visible>.*</visible></feature>-<panel><name>AppsPanel</name><enabled>true</enabled></panel>-' \
            "${adobe_service_config_path}"

        fi

    fi

}

reset_acrobat_license() {
    # Source:  https://community.adobe.com/t5/acrobat-discussions/error-sorry-something-went-wrong-please-try-launching-acrobat-first-or-contact-your-administrator/td-p/11325282/page/2

    acrobat_plist="/Library/Preferences/com.adobe.acrobat.pro.plist"

    backup_file "${acrobat_plist}" "move"

    /usr/bin/defaults write "${acrobat_plist}" IsNGLEnforced -bool "true"

}

reset_user_oobe_folder() {
    # Source:  https://helpx.adobe.com/creative-cloud/kb/creative-cloud-app-doesnt-open.html

    user=$( get_logged_in_user )

    Adobe_OOBE_folder="/Users/${user}/Library/Application Support/Adobe/OOBE"

    backup_file "${Adobe_OOBE_folder}" "move"

}

reset_host_file() {
    # Source:  https://helpx.adobe.com/x-productkb/policy-pricing/activation-network-issues.html#reset-host-file

    hosts_file="/private/etc/hosts"

    if /usr/bin/grep --ignore-case --quiet "Adobe" "${hosts_file}"; then

        echo "Host file contains Adobe entries, removing them..."
        backup_file "${hosts_file}" "copy"
        /usr/bin/sed -i '' 's/.*[Aa][Dd][Oo][Bb][Ee].*//' "${hosts_file}"

    fi

}

run_limited_access_repair_tool() {
    # Source:  https://helpx.adobe.com/creative-cloud/kb/limited_access_repair_tool.html
    # This tool doesn't do anything different than the `reset_host_file` function above, saving for "just in case"

    curl_exit_status=$( cd ${temp_dir} && /usr/bin/curl \
        --silent --show-error --fail \
        --url "https://download.macromedia.com/pub/developer/cleaner/mac/AdobeLimitedAccessRepairTool.dmg" \
        --compressed \
        --remote-name \
        --remote-header-name
        )

    curl_exit_code=$?
    exit_check $curl_exit_code "${curl_exit_status}" "Failed to download the Limited Access Repair Tool!"

    # Find the downloaded .dmg file in the specified directory
    tool_dmg=$( /usr/bin/find -E "${temp_dir}" -iregex ".*AdobeLimitedAccessRepairTool[.]dmg" -type f -prune -maxdepth 1 )

    # Mount the dmg
    if [[ -e "${tool_dmg}" ]]; then

        user=$( get_logged_in_user )

        echo "Mounting:  ${tool_dmg}"
        su - "${user}" -c "/usr/bin/hdiutil attach \"${tool_dmg}\" \
            -nobrowse -noverify -noautoopen -quiet"
        /bin/sleep 2

    else

        exit_check 1 "Missing .dmg" "Failed to locate the downloaded tool!"

    fi

    # Find mounted Limited Access Repair Tool disk images and then the app and the executable within
    tool_mount=$( /usr/bin/find -E "/Volumes" -iregex ".*LimitedAccessRepairtool.*" -type d -prune -maxdepth 1 )
    tool_app_executable=$( /usr/bin/find -E "${tool_mount}" -iregex ".*[.]app/Contents/MacOS/Limited Access Repair tool" -prune )

    # Run the Limited Access Repair Tool
    echo "Running Limited Access Repair tool..."
    tool_exit_status=$( "${tool_app_executable}" )
    tool_exit_code=$?
    exit_check $tool_exit_code "${tool_exit_status}" "Failed to run the Limited Access Repair Tool!"

}

run_Acrobat_NGLEnableTool() {
    # Source:  https://helpx.adobe.com/acrobat/kb/troubleshoot-activation.html#error-opening-acrobat-mac

    curl_exit_status=$( cd ${temp_dir} && /usr/bin/curl \
        --silent --show-error --fail \
        --url "https://helpx.adobe.com/content/dam/help/en/acrobat/kb/troubleshoot-activation/jcr_content/main-pars/download_section_cop/download-1/AcroNGLEnableTool.zip" \
        --compressed \
        --remote-name \
        --remote-header-name
        )

    curl_exit_code=$?
    exit_check $curl_exit_code "${curl_exit_status}" "Failed to download the Acrobat Tool!"

    # Find the downloaded .zip file in the specified directory
    tool_zip=$( /usr/bin/find -E "${temp_dir}" -iregex ".*AcroNGLEnableTool[.]zip" -type f -prune -maxdepth 1 )

    # Unzip the tool
    if [[ -e "${tool_zip}" ]]; then

        echo "Extracting the tool:  ${tool_dmg}"
        /usr/bin/unzip -qq "${tool_zip}" "AcroNGLEnableTool" -d "${temp_dir}"

    else

        exit_check 1 "Missing .zip" "Failed to locate the downloaded tool!"

    fi

    # Set permissions (just in case)
    /bin/chmod 755 "${temp_dir}/AcroNGLEnableTool"

    # Run the Acrobat Tool
    echo "Running Acrobat tool..."
    user=$( get_logged_in_user )
    tool_exit_status=$( su - "${user}" -c "\"${temp_dir}/AcroNGLEnableTool\"" )
    tool_exit_code=$?
    exit_check $tool_exit_code "${tool_exit_status}" "Failed to run the Acrobat Tool!"

}


##################################################
# Bits staged...

# Prompt user for actions to take
selected_action=$( osascript << EndOfScript
    tell application "System Events" 
        activate
        choose from list every paragraph of "${available_actions}" ¬
        with multiple selections allowed ¬
        with title "Fix-IT:  Adobe Creative Cloud" ¬
        with prompt "Choose options to perform:" ¬
        OK button name "Select" ¬
        cancel button name "Cancel"
    end tell
EndOfScript
)

if [[ "${selected_action}" == "false" ]]; then

    echo -e "NOTICE:  User canceled the prompt.\n"
    echo "*****  Fix-IT - Adobe CC:  CANCELED  *****"
    exit 0

else

    echo "Selected Actions:  ${selected_action}"

fi

# Prompt user warning
accept_warning=$( osascript << EndOfScript
    tell application "System Events" 
        activate
        display dialog "Notice \n\nAll Adobe processes will be terminated if you continue.  Please save any open files.  \n\nAll setting changes should be recoverable.  Please Contact your Deskside Support if you need additional assistance.  \n\nDo you wish to continue?" ¬
        with title "Fix-IT:  Adobe Creative Cloud" ¬
        buttons {"No", "Yes"} default button 1 ¬
        giving up after 60 ¬
        with icon caution
    end tell
EndOfScript
)

if [[ "${accept_warning}" != "button returned:Yes, gave up:false" ]]; then

    echo -e "NOTICE:  User did not accept warning.\n"
    echo "*****  Fix-IT - Adobe CC:  CANCELED  *****"
    exit 0

fi

# Function force_quit_adobe_processes
force_quit_adobe_processes
force_quit_adobe_processes
# Run it twice...just for kicks

# In case multiple actions were selected, loop through them...
while read -r action; do

    # Determine requested task.
    case "${action}" in

        "Basic Reset" )
            reset_adobe_files
            delete_from_keychain_Adobe_User_Info
        ;;

        "Advanced Reset" )
            reset_adobe_files
            remove_from_keychain_Adobe_All
            remove_from_keychain_Acrobat_All
            reset_host_file
        ;;

        "Common CCDA Issues" )
            reset_ccda_service_config
            reset_user_oobe_folder
        ;;

        "Common Acrobat Issues" )
            run_Acrobat_NGLEnableTool
            reset_acrobat_license
        ;;

        "Clear Acrobat Sign-in Credentials" )
            remove_from_keychain_Acrobat_All
        ;;

        # "Run Adobe's 'Limited Access Repair Tool'" )
        #     run_limited_access_repair_tool
        # ;;

        * )
            echo "ERROR:  Requested task is invalid"
            echo "*****  Fix-IT - Adobe CC:  FAILED  *****"
            exit 2
        ;;

    esac

done < <( echo "${selected_action}" | /usr/bin/tr ',' '\n' )

help_viewer_icon="/System/Library/CoreServices/HelpViewer.app/Contents/Resources/AppIcon.icns"
generic_question_mark_icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericQuestionMarkIcon.icns"

if [[ -e "${help_viewer_icon}" ]]; then

    survey_icon="${help_viewer_icon}"

else

    survey_icon="${generic_question_mark_icon}"

fi

# Prompt for resolution response
survey_response=$( osascript << EndOfScript
    tell application "System Events" 
        activate
        display dialog "Survey \n\nDid this Fix-IT resolve the issue you were experiencing?" ¬
        with title "Fix-IT:  Adobe Creative Cloud" ¬
        buttons {"Yes", "No"} ¬
        with icon POSIX file "${survey_icon}"
    end tell
EndOfScript
)

if [[ "${survey_response}" != "button returned:Yes" ]]; then

    echo -e "NOTICE:  User respond that the Fix-IT did not resolve the issue.\n"
    echo "*****  Fix-IT - Adobe CC:  FAILED  *****"
    exit 1

else

    echo "*****  Fix-IT - Adobe CC:  COMPLETE  *****"
    exit 0

fi
