#!/opt/ManagedFrameworks/Python.framework/Versions/Current/bin/python3

###################################################################################################
# Script Name:  jamf_Patcher.py
# By:  Zack Thompson / Created:  7/10/2019
# Version:  1.1.0 / Updated:  9/20/2023 / By:  ZT
#
# Description:  This script handles patching of applications with user notifications.
#
###################################################################################################

import os
import platform
import plistlib
import signal
import subprocess
import sys

try:
    import requests # Use requests if available
except ImportError:
    from urllib import request as urllib  # For Python 3


def run_utility(command,  continue_on_error=True):
    """A helper function for subprocess.
    Args:
        command (str):  String containing the commands and
            arguments that will be passed to a shell.
        continue_on_error (bool):  Whether to continue on error or not
    Returns:
        stdout:  output of the command
    """

    try:
        return subprocess.check_output(command, shell=True)

    except subprocess.CalledProcessError as error:

        if continue_on_error:
            return "continue"

        print(f"Error code:  {error.returncode}\nError:  {error}")
        return "error"


def plist_reader(plist_file):
    """A helper function to get the contents of a Property List file.
    Args:
        plist_file (str):  A .plist file path to read in.
    Returns:
        stdout:  Returns the contents of the plist file.
    """

    if os.path.exists(plist_file):
        # print(f"Reading {plist_file}...")

        try:
            plist_contents = plistlib.load(plist_file)
        except Exception:
            file_cmd = f"/usr/bin/file --mime-encoding {plist_file}"
            file_response = run_utility(file_cmd)
            file_type = file_response.split(": ")[1].strip()
            # print(f"File Type:  {file_type}")

            if file_type == "binary":
                # print("Converting plist...")
                plutil_cmd = f"/usr/bin/plutil -convert xml1 {plist_file}"
                _ = run_utility(plutil_cmd)

            plist_contents = plistlib.load(plist_file)
    else:
        print("Something's terribly wrong here...")

    return plist_contents


def prompt_to_patch(**parameters):
    """Uses Jamf Helper to prompt a user to patch a software title,
    optionally allowing them to delay the patch.

    Args:
        parameters (kwargs):  Key word arguments
    """

    # Prompt user to quit app.
    prompt = f"""\
        '{parameters.get("jamf_helper")}' \
            -window_type '{parameters.get("window_type")}' \
            -title '{parameters.get("title")}' \
            -icon '{parameters.get("icon")}' \
            -heading '{parameters.get("heading")}' \
            -description '{parameters.get("description")}' \
            -button1 OK \
            -timeout 3600 \
            -countdown \
            -countdownPrompt 'If you wish to delay this patch, please make a selection in ' \
            -alignCountdown center \
            -lockHUD \
            -showDelayOptions ', 600, 3600, 86400' \
    """

    selection = run_utility(prompt)
    print(f"SELECTION:  {selection}")

    if selection == "1":
        print("User selected to patch now.")
        kill_and_install(**parameters)

    elif selection[:-1] == "600":
        print("DELAY:  600 seconds")
        create_delay_daemon(delayTime=600, **parameters)

    elif selection[:-1] == "3600":
        print("DELAY:  3600 seconds")
        create_delay_daemon(delayTime=3600, **parameters)

    elif selection[:-1] == "86400":
        print("DELAY:  86400 seconds")
        create_delay_daemon(delayTime=86400, **parameters)

    elif selection == "243":
        print("TIMED OUT:  user did not make a selection")
        kill_and_install(**parameters)

    else:
        print("Unknown action was taken at prompt.")
        kill_and_install(**parameters)


def kill_and_install(**parameters):
    """Kills the application by PID, if running and then executes
    the Jamf Pro Policy to update the application.

    Args:
        parameters (kwargs):  Key word arguments
    """

    try:
        print("Attempting to close app if it's running...")
        # Get PID of the application
        pid = int(parameters.get("status").split(" ")[0])
        print(f"Process ID:  {pid}")
        # Kill PID
        os.kill(pid, signal.SIGTERM) #or signal.SIGKILL
    except Exception:
        print("Unable to terminate app, assuming it was manually closed...")

    print("Performing install...")

    # Run Policy
    run_utility(parameters.get("install_policy"))
    # print("Test run, don't run policy!")

    prompt = f"""\
        '{parameters.get("jamf_helper")}' \
            -window_type '{parameters.get("window_type")}' \
            -title '{parameters.get("title")}' \
            -icon '{parameters.get("icon")}' \
            -heading '{parameters.get("heading")}' \
            -description '{parameters.get("description_complete")}' \
            -button1 OK \
            -timeout 60 \
            -alignCountdown center \
            -lockHUD \
    """

    run_utility(prompt)


def create_delay_daemon(**parameters):
    """Creates a LaunchDaemon based on the user selected delay time
    which will the call a "Delayed Patch" Policy in Jamf Pro.

    Args:
        parameters (kwargs):  Key word arguments
    """

    application_name = parameters.get("application_name")
    launch_daemon_label = parameters.get('launch_daemon_label')
    launch_daemon_location = parameters.get("launch_daemon_location")
    os_minor_version = parameters.get("os_minor_version")
    patch_plist = parameters.get("patch_plist")

    # Configure for delay.
    if os.path.exists(patch_plist):
        patch_plist_contents = plist_reader(patch_plist)
        patch_plist_contents.update( { application_name : "Delayed" } )
    else:
        patch_plist_contents = { application_name : "Delayed" }

    plistlib.dump(patch_plist_contents, patch_plist)

    print("Creating the Patcher LaunchDaemon...")

    launch_daemon_plist = {
        "Label": "com.github.mlbz521.jamf.patcher",
        "ProgramArguments": [
            "/usr/local/jamf/bin/jamf",
            "policy",
            "-id",
            f"{parameters.get('patch_id')}",
        ],
        "StartInterval": parameters.get("delayTime"),
        "AbandonProcessGroup": True,
    }

    plistlib.dump(launch_daemon_plist, launch_daemon_location)

    if os.path.exists(launch_daemon_location):
        # Start the LaunchDaemon
        start_daemon(os_minor_version, launch_daemon_label, launch_daemon_location)


def clean_up(**parameters):
    """Cleans up a configured delay for the application
    and stops and deletes the delay LaunchDaemon.

    Args:
        parameters (kwargs):  Key word arguments
    """

    print("Performing cleanup...")

    application_name = parameters.get("application_name")
    launch_daemon_label = parameters.get('launch_daemon_label')
    launch_daemon_location = parameters.get("launch_daemon_location")
    os_minor_version = parameters.get("os_minor_version")
    patch_plist = parameters.get("patch_plist")

    # Clean up patch_plist.
    if os.path.exists(patch_plist):
        patch_plist_contents = plist_reader(patch_plist)

        if patch_plist_contents.get(application_name):
            patch_plist_contents.pop(application_name, None)
            print(f"Removing previously delayed app:  {application_name}")
            plistlib.dump(patch_plist_contents, patch_plist)
        else:
            print(f"App not listed in patch_plist:  {application_name}")

    # Stop LaunchDaemon before deleting it
    stop_daemon(os_minor_version, launch_daemon_label, launch_daemon_location)

    if os.path.exists(launch_daemon_location):
        os.remove(launch_daemon_location)


def execute_launchctl(sub_cmd, service_target, exit_code_only=False):
    """A helper function to run launchctl.

    Args:
        sub_cmd (str): A launchctl subcommand (option)
        service_target (str): A launchctl service target (parameter)
        exit_code_only (bool, optional): Whether to report only success or failure.
            Defaults to False.

    Returns:
        bool | str: Depending on `exit_code_only`, returns either a bool or
            the output from launchctl
    """

    launchctl_cmd = f"/bin/launchctl {sub_cmd} {service_target}"

    if exit_code_only:
        launchctl_cmd = f"{launchctl_cmd} > /dev/null 2>&1; echo $?"

    return run_utility(launchctl_cmd)


def is_daemon_running(os_minor_version, launch_daemon_label):
    """Checks if the daemon is running.

    Args:
        os_minor_version (int): Used to determines the proper launchctl
            syntax based on OS Version of the device
        launch_daemon_label (str): The LaunchDaemon's Label

    Returns:
        bool: True or False whether or not the LaunchDaemon is running
    """

    if os_minor_version >= 11:
        return execute_launchctl("print", f"system/{launch_daemon_label}", exit_code_only=True)

    elif os_minor_version <= 10:
        return execute_launchctl("list", launch_daemon_label, exit_code_only=True)


def start_daemon(os_minor_version, launch_daemon_label, launch_daemon_location):
    """Starts a daemon, if it is running, it will be restarted in
    case a change was made to the plist file.

    Args:
        os_minor_version (int): Used to determines the proper launchctl
            syntax based on OS Version of the device
        launch_daemon_label (str): The LaunchDaemon's Label
        launch_daemon_location (str): The file patch to the LaunchDaemon

    """

    restart_daemon(os_minor_version, launch_daemon_label, launch_daemon_location)

    print("Loading LaunchDaemon...")

    if os_minor_version >= 11:
        execute_launchctl("bootstrap", f"system {launch_daemon_location}")
        execute_launchctl("enable", f"system/{launch_daemon_label}")

    elif os_minor_version <= 10:
        execute_launchctl("load", launch_daemon_location)


def restart_daemon(os_minor_version, launch_daemon_label, launch_daemon_location):
    """Restarts a daemon if it is running.

    Args:
        os_minor_version (int): Used to determines the proper launchctl
            syntax based on OS Version of the device
        launch_daemon_label (str): The LaunchDaemon's Label
        launch_daemon_location (str): The file patch to the LaunchDaemon

    """

    # Check if the LaunchDaemon is running.
    exit_code = is_daemon_running(os_minor_version, launch_daemon_label)

    if int(exit_code) == 0:
        print("LaunchDaemon is currently started; stopping now...")

        if os_minor_version >= 11:
            execute_launchctl("bootout", f"system/{launch_daemon_label}")

        elif os_minor_version <= 10:
            execute_launchctl("unload", launch_daemon_location)


def stop_daemon(os_minor_version, launch_daemon_label, launch_daemon_location):
    """Stops a daemon.

    Args:
        os_minor_version (int): Used to determines the proper launchctl
            syntax based on OS Version of the device
        launch_daemon_label (str): The LaunchDaemon's Label
        launch_daemon_location (str): The file patch to the LaunchDaemon

    """

    # Check if the LaunchDaemon is running.
    exit_code = is_daemon_running(os_minor_version, launch_daemon_label)

    if int(exit_code) == 0:
        print("Stopping the LaunchDaemon...")

        if os_minor_version >= 11:
            execute_launchctl("bootout", f"system/{launch_daemon_label}")
        elif os_minor_version <= 10:
            execute_launchctl("unload", launch_daemon_location)

    else:
        print("LaunchDaemon not running")


def main():
    print("*****  jamf_Patcher process:  START  *****")

    ##################################################
    # Define Script Parameters
    print(f"All args:  {sys.argv}")
    department_name = sys.argv[4] # "<Organization's> Technology Office"
    application_name = sys.argv[5] # "zoom.us"
    icon_id = sys.argv[6] # "https://jps.server.com:8443/icon?id=49167"
    patch_id = sys.argv[7]
    policy_id = sys.argv[8]

    ##################################################
    # Define Variables
    jamf_pro_server = plist_reader("/Library/Preferences/com.jamfsoftware.jamf.plist")["jss_url"]
    patch_plist = "/Library/Preferences/com.github.mlbz521.jamf.patcher.plist"
    jamf_helper = "/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
    launch_daemon_label = f"com.github.mlbz521.jamf.patcher.{application_name}"
    launch_daemon_location = f"/Library/LaunchDaemons/{launch_daemon_label}.plist"
    os_minor_version = platform.mac_ver()[0].split(".")[1]
    install_policy = f"/usr/local/jamf/bin/jamf policy -id {policy_id}"

    ##################################################
    # Define jamfHelper window values
    title="Security Patch Notification"
    window_type="hud"
    description = f"{application_name} will be updated to patch a security vulnerability.  \
        Please quit {application_name} to apply this update.\n\nIf you have questions, \
        please contact your deskside support group."
    description_force = f"{application_name} will be updated to patch a security vulnerability.  \
        Please quit {application_name} within the allotted time to apply this update.\n\n\
        If you have questions, please contact your deskside support group."
    description_complete = f"{application_name} has been patched!\n\n."
    local_icon_path = f"/private/tmp/{application_name}_icon.png"

    if department_name:
        heading = f"My Organization - {department_name}"
    else:
        heading = "My Organization"

    ##################################################
    # Bits staged...

    process_check = f"/bin/ps -ax -o pid,command | \
        /usr/bin/grep -E '/Applications/{application_name}' | \
        /usr/bin/grep -v 'grep' 2> /dev/null"
    status = run_utility(process_check)
    print(f"APP STATUS:  {status}")

    parameters = {
        "application_name": application_name,
        "patch_plist": patch_plist,
        "launch_daemon_label": launch_daemon_label,
        "launch_daemon_location": launch_daemon_location,
        "os_minor_version": os_minor_version,
        "patch_id": patch_id,
        "status": status,
        "install_policy": install_policy
    }

    jamf_helper_parameters = {
        "jamf_helper": jamf_helper,
        "window_type": window_type,
        "title": title,
        "heading": heading,
        "description": description,
        "description_complete": description_complete,
        "icon": local_icon_path
    }

    if status == "continue":
        print(f"{application_name} is not running, installing now...")
        run_utility(install_policy)
        # print("Test run, don't run policy!")

        clean_up(**parameters)

    else:
        print(f"{application_name} is running...")

        # Download the icon from the JPS
        icon_url = f"{jamf_pro_server}icon?id={icon_id}"

        try:
            downloaded_icon = requests.get(icon_url)
            open(local_icon_path, "wb").write(downloaded_icon.content)
        except Exception:
            sys.exc_clear()
            urllib.urlretrieve(icon_url, filename=local_icon_path)

        if os.path.exists(patch_plist):
            patch_plist_contents = plist_reader(patch_plist)

            # Delay Check
            if patch_plist_contents.get(application_name):
                print("STATUS:  Patch has already been delayed; forcing upgrade.")

                # Prompt user with one last warning.
                prompt = f"\
                    '{jamf_helper}' \
                    -window_type '{window_type}' \
                    -title '{title}' \
                    -icon '{local_icon_path}' \
                    -heading '{heading}' \
                    -description '{description_force}' \
                    -button1 OK \
                    -timeout 600 \
                    -countdown \
                    -countdownPrompt '{application_name} will be force closed in ' \
                    -alignCountdown center \
                    -lockHUD \
                    > /dev/null 2>&1 \
                "

                run_utility(prompt)
                kill_and_install(**parameters, **jamf_helper_parameters)
                clean_up(patch_plist_contents=patch_plist_contents, **parameters)

            else:
                print("STATUS:  Patch has not been delayed; prompting user.")
                prompt_to_patch(**parameters, **jamf_helper_parameters)

        else:
            print("STATUS:  Patch has not been delayed; prompting user.")
            prompt_to_patch(**parameters, **jamf_helper_parameters)

    print("*****  jamf_Patcher process:  SUCCESS  *****")

if __name__ == "__main__":
    main()
