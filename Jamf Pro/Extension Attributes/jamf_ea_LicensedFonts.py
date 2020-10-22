#!/usr/bin/python

###################################################################################################
# Script Name:  jamf_ea_LicensedFonts.py
# By:  Zack Thompson / Created:  1/12/2019
# Version:  1.1.0 / Updated:  10/21/2020 / By:  ZT
#
# Description:  A Jamf Extension Attribute to check if any Licensed Fonts are installed.
#
###################################################################################################

import re
import os
import subprocess

def runUtility(command):
    """A helper function for subprocess.
    Args:
        command:  List containing command and arguments in a list
    Returns:
        stdout:  output of the command
    """
    try:
        process = subprocess.check_output(command)
    except subprocess.CalledProcessError as error:
        print ('return code = ', error.returncode)
        print ('result = ', error)  

    return process

def check(dir):
    """Provide a directory and the files within are checked using regex against the string.
    Args:
        dir:  A directory path
    Returns:
        count:  an [int] of files matching the string
    """

    count = 0 

    try:
        # Get all the files in the directory.
        files = os.listdir(dir)

        # Loop over the files.
        for file in files:
            # Check the file via regex and ignore case.
            if re.search(r'(Name_or_Prefix_of_Font_Here)', file, flags=re.IGNORECASE):  # Substitute "Name_or_Prefix_of_Font_Here" with the font you're looking for.
                count += 1
    except:
        pass

    return count

def main():

    # Define Variables
    cmd_all_Users = ['/usr/bin/dscl', '.', 'list', '/Users']
    home_directories = []
    system_accounts = ['daemon', 'Guest', 'nobody', 'root']  # Add your Jamf Management Account to this dictionary.
    user_Font_Count = 0

    # Get a list of all user accounts on this system.
    all_users = (runUtility(cmd_all_Users)).split()

    # Loop over each user.
    for user in all_users:
        # Ignore any system accounts or known ignorable accounts.
        if ( user[0] != '_' ) and ( user not in system_accounts ):
            # Get the home directory of each user account.
            cmd_Home_Directory = ['/usr/bin/dscl', '.', 'read', '/Users/' + user, 'NFSHomeDirectory']
            home_directory = ((runUtility(cmd_Home_Directory)).replace('NFSHomeDirectory: ', '')).strip()
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
