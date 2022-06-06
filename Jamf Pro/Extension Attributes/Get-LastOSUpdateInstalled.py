#!/opt/ManagedFrameworks/Python.framework/Versions/Current/bin/python3
"""
Script Name:  Get-LastOSUpdateInstalled.py
By:  Zack Thompson / Created:  8/23/2019
Version:  1.7.0 / Updated:  5/24/2022 / By:  ZT

Description:  A Jamf Pro Extension Attribute to pull the last operating system update installed.

Additional info:

Update history can be found in or with:
  * /Library/Receipts/InstallHistory.plist
  * /private/var/db/softwareupdate/journal.plist
  * softwareupdate --history [ --all ]
  * system_profiler SPInstallHistoryDataType [ -detaillevel [ mini | basic | full ] ]

Most of these provide the same information, just through a different interface, that said I'd
assume that `InstallHistory.plist` is what the other tools references.

However, things seemed to have changed with Big Sur.  `softwareupdate` seems to be looking at
`journal.plist` and historical information before Big Sur seems to be cleared after an upgrade.
`InstallHistory.plist` still contains everything, but it also "counts" using
`softwareupdate --fetch-full-installer [ --full-installer-version <version> ]` to download an
`Install macOS <version>.app` as an "install", so it affects the logic of this script.
While I believe I've accounted for it, in this last update, I think it would be better to just
parse `journal.plist` for OS updates that were _actually_ applied to the hardware.

"""

import os
import re
import platform
import plistlib
import shlex
import subprocess

from datetime import timezone # datetime, timedelta
from pkg_resources import parse_version


def execute_process(command, input=None):
    """
    A helper function for subprocess.

    Args:
        command (str):  The command line level syntax that would be written in a 
            shell script or a terminal window

    Returns:
        dict:  Results in a dictionary
    """

    # Validate that command is not a string
    if not isinstance(command, str):
        raise TypeError("Command must be a str type")

    # Format the command
    command = shlex.split(command)

    # Run the command
    process = subprocess.Popen( 
        command, 
        stdin=subprocess.PIPE, 
        stdout=subprocess.PIPE, 
        stderr=subprocess.PIPE, 
        shell=False, 
        universal_newlines=True 
    )

    if input:
        (stdout, stderr) = process.communicate(input=input)

    else:
        (stdout, stderr) = process.communicate()

    return {
        "stdout": (stdout).strip(),
        "stderr": (stderr).strip() if stderr != None else None,
        "exitcode": process.returncode,
        "success": True if process.returncode == 0 else False
    }


def utc_to_local(utc_dt):

    return utc_dt.replace(tzinfo=timezone.utc).astimezone(tz=None)


def update_journal():
    # For macOS Big Sur and newer
    update_journal_plist = "/private/var/db/softwareupdate/journal.plist"

    # Verify file exists
    if os.path.exists(update_journal_plist):

        # Open the journal
        with open(update_journal_plist, "rb") as update_journal_path:

            # Load the journal.plist
            plist_Contents = plistlib.load(update_journal_path)

            # Loop through the history...
            for update in reversed(plist_Contents):

                if update.get("__isSoftwareUpdate") and update.get("__isMobileSoftwareUpdate"):

                    # If the title includes the version, don"t repeat the version string
                    if re.search(update.get("version"), update.get("title")):

                        local_time_stamp = utc_to_local(update.get("installDate"))
                        return f"{update.get('title')} @ {str(local_time_stamp)}"

                    else:

                        local_time_stamp = utc_to_local(update.get("installDate"))
                        return f"{update.get('title')} @ {update.get('version')} {str(local_time_stamp)}"

    else:
        print("Missing journal.plist")


def install_history():
    # For macOS Catalina and older
    install_history_plist = "/Library/Receipts/InstallHistory.plist"

    # Verify file exists
    if os.path.exists(install_history_plist):

        # Define the updates that we're concerned with
        pattern_process_names = re.compile(
            "(?:installer)|(?:macOS Installer)|(?:OS X Installer)|(?:softwareupdated)")
        pattern_display_names = re.compile(
            "(?:macOS .+ Beta)|(?:macOS 12.+)|(?:macOS 11.+)|(?:macOS Catalina 10\.15\.\d)|(?:macOS 10\.14\.\d Update)|(?:Install macOS High Sierra)|(?:macOS Sierra Update)|(?:OS X El Capitan Update)|(?:Security Update \d\d\d\d-\d\d\d).*")
        pattern_package_identifiers = re.compile(
            "(?:com\.apple\.pkg\.macOSBrain)|(?:com\.apple\.pkg\.InstallAssistantMAS)")
        pattern_package_identifiers_ignore = re.compile(
            "(?:com\.apple\.pkg\.InstallAssistant\.Seed.*)")

        # Open the journal
        with open(install_history_plist, "rb") as install_history_path:

            # Load the InstallHistory.plist
            plist_Contents = plistlib.load(install_history_path)

        # Loop through the history...
        for update in reversed(plist_Contents):

            if ( pattern_process_names.search(update.get("processName")) and 
                 pattern_display_names.search(update.get("displayName")) ):

                try:
                    for package in update.get("packageIdentifiers"):

                        if pattern_package_identifiers.search(package):
                            # print("Wanted package")
                            continue

                        elif pattern_package_identifiers_ignore.search(package):
                            # print("Unwanted package")
                            break

                        else:
                            # print("Some other unwanted package")
                            break

                except Exception:
                    pass

                display_name = str(update.get("displayName")).lstrip("Install ")

                # If the display name includes the version, don't repeat the version string
                if ( 
                    update.get("displayVersion") is not None 
                    and update.get("displayVersion") != " " 
                    and re.search(update.get("displayVersion"), display_name) 
                ):

                    last_update = display_name

                else:
                    last_update = f"{display_name} {update.get('displayVersion')}"

                if update.get("date"):
                    local_time_stamp = utc_to_local(update.get("date"))
                    last_update = f"{last_update} @ {str(local_time_stamp)}"

                return last_update

    else:
        print("Missing InstallHistory.plist")


def main():

    perform_recon = False
    local_inventory = "/opt/ManagedFrameworks/Inventory.plist"

    if parse_version(platform.mac_ver()[0]) >= parse_version("10.16"):

        last_update = update_journal() or install_history()

    else:

        last_update = install_history()

    if last_update:

        print(f"Last OS update installed:  {last_update}")

        # Check if local inventory exists
        if os.path.exists(local_inventory):

            # Open the local inventory 
            with open(local_inventory, "rb") as local_inventory_path:
                plist_Contents = plistlib.load(local_inventory_path)

            last_reported = plist_Contents.get("last_reported_os_update_installed", None)

            if last_reported:
                print(f"Last reported OS update installed:  {last_update}")

            if (
                plist_Contents.get("last_os_update_installed_within_24hours", False) and
                last_update != last_reported
            ):
                print("OS has been updated, performing recon...")
                perform_recon = True

            else:
                print("OS has not been updated.")

            plist_Contents.pop("last_os_update_installed_within_24hours", None)

        else:
            # If the device doesn't have a local inventory register, it's unknown if the device 
            # has reported its most recent OS update to Jamf Pro.
            print("Device doesn't have a local inventory register, performing recon...")
            plist_Contents = {}
            perform_recon = True

        # Update the values
        plist_Contents["last_os_update_installed"] = last_update

    else:

        print("No Updates Installed")
        plist_Contents = { "last_os_update_installed": "No updates installed" }

    # Save the changes
    with open(local_inventory, "wb") as local_inventory_path:
        plistlib.dump(plist_Contents, fp=local_inventory_path)

    if perform_recon:
        # Call a Policy to perform a recon
        execute_process("/usr/local/bin/jamf policy -id 10")


if __name__ == "__main__":
    main()
