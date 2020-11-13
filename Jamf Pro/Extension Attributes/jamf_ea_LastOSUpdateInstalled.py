#!/usr/bin/python
"""
Script Name:  jamf_ea_LastOSUpdateInstalled.py
By:  Zack Thompson / Created:  8/23/2019
Version:  1.3.1 / Updated:  11/13/2020 / By:  ZT

Description:  A Jamf Pro Extension Attribute to pull the last operating system update installed.
"""

import os
import re
from datetime import datetime
from dateutil import tz
import plistlib

def main():

    # Define Variables
    from_zone = tz.tzutc()
    to_zone = tz.tzlocal()
    lastUpdate = ''
    install_history = '/Library/Receipts/InstallHistory.plist'

    # Define the updates that we're concerned with
    patternProcessNames = re.compile("(?:macOS Installer)|(?:OS X Installer)|(?:softwareupdated)")
    patternDisplayName = re.compile("(?:macOS .+ Beta)|(?:macOS 11.+)|(?:macOS Catalina 10\.15\.\d)|(?:macOS 10\.14\.\d Update)|(?:Install macOS High Sierra)|(?:macOS Sierra Update)|(?:OS X El Capitan Update)|(?:Security Update \d\d\d\d-\d\d\d).*")
    patternPackageIdentifiers = re.compile("(?:com\.apple\.pkg\.macOSBrain)|(?:com\.apple\.pkg\.InstallAssistantMAS)")

    # Verify file exists
    if os.path.exists(install_history):

        # Load the InstallHistory.plist
        plist_Contents = plistlib.readPlist(install_history)

        # Loop through the history...
        for update in reversed(plist_Contents):
            if patternProcessNames.search(update["processName"]):
                if patternDisplayName.search(update["displayName"]):

                    try:
                        for package in update["packageIdentifiers"]:
                            if patternPackageIdentifiers.search(package):
                                continue

                    except:
                        pass

                    lastUpdate = ''
                    lastUpdate = lastUpdate + str(update["displayName"]).lstrip('Install ')

                    if update["displayVersion"] and update["displayVersion"] != " ":
                        lastUpdate = lastUpdate + ' ' + update["displayVersion"]

                    if update["date"]:
                        timeStamp = update["date"]
                        timeStamp = timeStamp.replace(tzinfo=from_zone)
                        timeStamp = timeStamp.astimezone(to_zone)
                        lastUpdate = lastUpdate + ' @ ' + str(timeStamp)

                    break

        if lastUpdate:
            print("<result>{}</result>".format(lastUpdate))
        else:
            print("<result>No Updates Installed</result>")

    else:
        print("<result>Missing InstallHistory.plist</result>")


if __name__ == "__main__":
    main()
