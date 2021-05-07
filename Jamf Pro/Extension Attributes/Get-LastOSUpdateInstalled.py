#!/opt/ManagedFrameworks/Python.framework/Versions/Current/bin/python3
"""
Script Name:  Get-LastOSUpdateInstalled.py
By:  Zack Thompson / Created:  8/23/2019
Version:  1.5.0 / Updated:  5/6/2021 / By:  ZT

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

from datetime import datetime, timezone, timedelta, tzinfo
from pkg_resources import parse_version


def utc_to_local(utc_dt):

    return utc_dt.replace(tzinfo=timezone.utc).astimezone(tz=None)


def update_journal():
    # For macOS Big Sur and newer
    update_journal_plist = "/private/var/db/softwareupdate/journal.plist"
    global last_update
    global local_time_stamp

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
                        last_update = "{} @ {}".format(update.get("title"), str(local_time_stamp))

                    else:

                        local_time_stamp = utc_to_local(update.get("installDate"))
                        last_update = "{} @ {} {}".format(
                            update.get("title"), update.get("version"), str(local_time_stamp))

                break

    else:
        print("Missing journal.plist")

    return last_update, local_time_stamp


def intstall_history():
    # For macOS Catalina and older
    install_history_plist = "/Library/Receipts/InstallHistory.plist"
    global last_update
    global local_time_stamp

    # Verify file exists
    if os.path.exists(install_history_plist):

        # Define the updates that we're concerned with
        pattern_process_names = re.compile(
            "(?:installer)|(?:macOS Installer)|(?:OS X Installer)|(?:softwareupdated)")
        pattern_display_names = re.compile(
            "(?:macOS .+ Beta)|(?:macOS 11.+)|(?:macOS Catalina 10\.15\.\d)|(?:macOS 10\.14\.\d Update)|(?:Install macOS High Sierra)|(?:macOS Sierra Update)|(?:OS X El Capitan Update)|(?:Security Update \d\d\d\d-\d\d\d).*")
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

                except:
                    pass

                display_name = str(update.get("displayName")).lstrip("Install ")

                # If the display name includes the version, don't repeat the version string
                if ( not update.get("displayVersion") 
                     and update.get("displayVersion") != " "
                     and re.search(update.get("displayVersion"), display_name) ):

                        last_update = display_name

                else:
                    last_update = "{} {}".format(display_name, update.get("displayVersion"))

                if update.get("date"):
                    local_time_stamp = utc_to_local(update.get("date"))
                    last_update = "{} @ {}".format(last_update, str(local_time_stamp))

                break

    else:
        print("Missing InstallHistory.plist")

    return last_update, local_time_stamp


def main():

    # Define Variables
    os_version = platform.mac_ver()[0]

    if parse_version(os_version) >= parse_version("10.16"):

        last_update, local_time_stamp = update_journal()

        if not last_update:

            last_update, local_time_stamp = intstall_history()

    else:
        
        last_update, local_time_stamp = intstall_history()


    if last_update:

        local_inventory = "/opt/ManagedFrameworks/Inventory.plist"
        current_time = utc_to_local(datetime.now())

        if current_time - timedelta(hours=24) <= local_time_stamp:
            within_24hours = True

        else:
            within_24hours = False

        # Check if local inventory exists
        if os.path.exists(local_inventory):

            # Open the local inventory
            with open(local_inventory, "rb") as local_inventory_path:

                # Load the InstallHistory.plist
                plist_Contents = plistlib.load(local_inventory_path)

        else:
            plist_Contents = {}

        # Update the values
        plist_Contents["last_os_update_installed"] = last_update
        plist_Contents["last_os_update_installed_within_24hours"] = within_24hours

        # Save the changes
        with open(local_inventory, "wb") as local_inventory_path:
            plistlib.dump(plist_Contents, fp=local_inventory_path)

        print("{}".format(last_update))

    else:

        print("No Updates Installed")


if __name__ == "__main__":
    last_update = None
    local_time_stamp = None
    main()
