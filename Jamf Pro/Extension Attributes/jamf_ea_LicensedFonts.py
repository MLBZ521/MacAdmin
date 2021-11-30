#!/opt/ManagedFrameworks/Python.framework/Versions/Current/bin/python3

###################################################################################################
# Script Name:  jamf_ea_LicensedFonts.py
# By:  Zack Thompson / Created:  1/12/2019
# Version:  1.2.1 / Updated:  10/22/2021 / By:  ZT
#
# Description:  A Jamf Extension Attribute to check if any Licensed Fonts are installed.
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
    """
    Provide a directory and the files within are checked using regex against the string.
    
    Args:
        path:  A directory path
    Returns:
        count:  an [int] of files matching the string
    """

    count = 0

    try:

        # Get all the files in the directory.
        files = os.listdir(path)

        # Loop over the files.
        for afile in files:

            # Check the file via regex and ignore case.
            if re.search(r'(Name_or_Prefix_of_Font_Here)', file, flags=re.IGNORECASE):  # Substitute "Name_or_Prefix_of_Font_Here" with the font you're looking for.
                count += 1

    except:
        pass

    return count


def main():

    # Define Variables
    cmd_all_Users = "/usr/bin/dscl . list /Users"
    home_directories = []
    system_accounts = ['cas', 'cascom', 'daemon', 'Guest', 'nobody', 'root']
    user_Font_Count = 0

    # Get a list of all user accounts on this system.
    all_users = (runUtility(cmd_all_Users))["stdout"].split()

    # Loop over each user.
    for user in all_users:

        # Ignore any system accounts or known ignorable accounts.
        if ( user[0] != '_' ) and ( user not in system_accounts ):

            # Get the home directory of each user account.
            cmd_Home_Directory = "/usr/bin/dscl . read /Users/{} NFSHomeDirectory".format(user)
            home_directory = ((runUtility(cmd_Home_Directory))["stdout"].replace('NFSHomeDirectory: ', '')).strip()
            home_directories.append(home_directory)

    # Check the System Fonts folder (aka available to all users).
    system_Font_Count = check("/Library/Fonts")

    # Loop over each home directory.
    for directory in home_directories:

        # Calculate if the local accounts have matching fonts.
        user_Font_Count = user_Font_Count + check(directory + "/Library/Fonts")

    # Sum of system and user fonts.
    quantity = system_Font_Count + user_Font_Count

    # Return the results.
    if quantity == 0:
        print ("<result>Not Installed</result>")
    else:
        print ("<result>Installed</result>")


if __name__ == "__main__":
    main()
