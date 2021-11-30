#!/opt/ManagedFrameworks/Python.framework/Versions/Current/bin/python3
"""
###################################################################################################
# Script Name:  Query-32BitApps.py
# By:  Zack Thompson / Created:  3/23/2020
# Version:  1.0.1 / Updated:  10/22/2021 / By:  ZT
#
# Description:  For OS versions older than 10.15, queries system_profiler for 32bit Apps that are not Apple, first party Apps.
#
#   Inspired by Rich Trouton's rendition:
#       https://derflounder.wordpress.com/2019/01/30/detecting-installed-32-bit-applications-on-macos-mojave/
#
###################################################################################################
"""

import logging
import platform
import plistlib
import subprocess
import sys
from distutils.version import LooseVersion

def runUtility(command):
    """A helper function for subprocess.
    Args:
        command:  Must be a string.
    Returns:
        Results in a dictionary.
    """

    # Validate that command is not a string
    if not isinstance(command, str):
        raise TypeError('Command must be a str type')

    process = subprocess.Popen( command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=False )
    (stdout, stderr) = process.communicate()

    result_dict = {
        "stdout": (stdout).strip(),
        "stderr": (stderr).strip() if stderr != None else None,
        "status": process.returncode,
        "success": True if process.returncode == 0 else False
    }

    return result_dict

# Setup logging
def log_setup():
    # Create logger
    logger = logging.getLogger('Query-32BitApps')
    logger.setLevel(logging.DEBUG)
    # Create file handler which logs even debug messages
    file_handler = logging.FileHandler('/var/log/32bitApps_inventory.log')
    file_handler.setLevel(logging.INFO)
    # Create formatter and add it to the handlers
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    file_handler.setFormatter(formatter)
    # Add the handlers to the logger
    logger.addHandler(file_handler)


def main():

    if LooseVersion(platform.mac_ver()[0]) < LooseVersion('10.14.*'):

        # Setup logging
        log_setup()
        logger = logging.getLogger('Query-32BitApps')
        logger.info('Checking for 32bit Apps...')

        no32bitApps=True

        cmd = "/usr/sbin/system_profiler -xml SPApplicationsDataType -detailLevel full -timeout 0"
        results = runUtility(cmd)

        if not results['success']:
            logger.error("Failed to run system_profiler:  ")
            logger.error(results['stdout'])
            logger.error(results['stderr'])
            sys.exit(1)

        # Get the results
        xml = plistlib.readPlistFromString(results['stdout'])

        if xml:
            # All 32bit Apps
            all_thirty_two_bit_apps = [ app for app in xml[0].get("_items") if app['has64BitIntelCode'] == "no"]

            if all_thirty_two_bit_apps:
                # All 32bits Apps that are not Apple Apps
                non_apple_thirty_two_bit_apps = [app for app in all_thirty_two_bit_apps if app['obtained_from'] != "apple"]

                if non_apple_thirty_two_bit_apps:
                    no32bitApps=False

                    # Loop trough each App
                    for app in non_apple_thirty_two_bit_apps:
                        logger.info(app.get('path'))

        if no32bitApps == False:
            print('<result>Yes</result>')
        else:
            print('<result>No</result>')

        logger.info('Check complete.')

    else:
        print('<result>No</result>')

if __name__ == "__main__":
    main()
