#!/opt/ManagedFrameworks/Python.framework/Versions/Current/bin/python3

"""
###################################################################################################
# Script Name:  jamf_ea_UpTime.py
# By:  Zack Thompson / Created:  8/24/2019
# Version:  1.0.1 / Updated:  11/30/2021 / By:  ZT
#
# Description:  A Jamf Pro Extension Attribute to get the up time of a device.
#
###################################################################################################
"""

import subprocess
import time

def runUtility(command):
    """A helper function for subprocess.
    Args:
        command:  String containing the commands and arguments that will be passed to a shell.
    Returns:
        stdout:  output of the command
    """

    try:
        process = subprocess.check_output(command, shell=True)
    except subprocess.CalledProcessError as error:
        print ('Error code:  {}'.format(error.returncode))
        print ('Error:  {}'.format(error))
        process = "error"

    return process


# Function by Mr. B (https://stackoverflow.com/a/24542445)
def display_time(seconds, granularity=2):
    result = []
    intervals = (
        ('weeks', 604800),  # 60 * 60 * 24 * 7
        ('days', 86400),    # 60 * 60 * 24
        ('hours', 3600),    # 60 * 60
        ('minutes', 60),
        ('seconds', 1),
    )

    for name, count in intervals:
        value = seconds // count
        if value:
            seconds -= value * count
            if value == 1:
                name = name.rstrip('s')
            result.append("{} {}".format(value, name))
    return ', '.join(result[:granularity])


def main():

    # Get current time from epoch
    current_epoch = time.time()

    # Get boot time from epoch
    boot_epoch = runUtility('/usr/sbin/sysctl kern.boottime | /usr/bin/awk \'{print $5}\' | /usr/bin/tr -d ,').strip()

    # Get time since boot in epoch
    since_boot = int(current_epoch)-int(boot_epoch)

    # Transform to a friendly human readable time format
    result = display_time(since_boot, 5)

    print("<result>{}</result>".format(result))

if __name__ == "__main__":
    main()
