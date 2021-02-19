#!/usr/bin/python

###################################################################################################
# Script Name:  Uninstall-Fonts.py
# By:  Zack Thompson / Created:  2/18/2021
# Version:  1.0.0 / Updated:  2/18/2021 / By:  ZT
#
# Description:  Removes the specified Fonts from the system and user directories, if they exist.
#
###################################################################################################

import re
import os
import shlex
import subprocess


def runUtility(command):
    """
    A helper function for subprocess.

    Args:
        command:  The command line level syntax that would be written in shell or a terminal window.  (str)
    Returns:
        Results in a dictionary.
    """

    # Validate that command is not a string
    if not isinstance(command, str):
        raise TypeError('Command must be a str type')

    # Format the command
    command = shlex.split(command)

    # Run the command
    process = subprocess.Popen( command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=False, universal_newlines=True )
    (stdout, stderr) = process.communicate()

    result_dict = {
        "stdout": (stdout).strip(),
        "stderr": (stderr).strip() if stderr != None else None,
        "status": process.returncode,
        "success": True if process.returncode == 0 else False
    }

    return result_dict


def check(path):
    """Provide a directory and the files within are checked using regex against the string.
    Args:
        path:  A directory path
    Returns:
        count:  an [int] of files matching the string
    """

    try:

        # Get all the files in the directory.
        files = os.listdir(path)

        # Loop over the files.
        for afile in files:

            # Check the file via regex and ignore case.
            if re.search(r'(Name_or_Prefix_of_Font_Here)', afile, flags=re.IGNORECASE):  # Substitute "Name_or_Prefix_of_Font_Here" with the font you're looking for.

                os.remove(os.path.join(path, afile))

    except:
        pass


def main():

    # Define Variables
    cmd_all_Users = "/usr/bin/dscl . list /Users"
    directories = [ "" ] # First entry will be used for /Library
    system_accounts = ['daemon', 'Guest', 'nobody', 'root']

    # Get a list of all user accounts on this system
    all_users = (runUtility(cmd_all_Users))["stdout"].split()

    # Loop over each user
    for user in all_users:

        # Ignore any system accounts or known ignorable accounts
        if ( user[0] != '_' ) and ( user not in system_accounts ):

            # Get the home directory of each user account
            cmd_Home_Directory = "/usr/bin/dscl . read /Users/{} NFSHomeDirectory".format(user)
            home_directory = ((runUtility(cmd_Home_Directory))["stdout"].replace('NFSHomeDirectory: ', '')).strip()
            directories.append(home_directory)

    # Loop over each directory to delete fonts from
    for directory in directories:

        check(directory + "/Library/Fonts")


if __name__ == "__main__":
    main()
