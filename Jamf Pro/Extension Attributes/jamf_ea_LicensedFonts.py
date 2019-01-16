#!/usr/bin/python

###################################################################################################
# Script Name:  jamf_ea_LicensedFonts.py
# By:  Zack Thompson / Created:  1/12/2019
# Version:  1.0.0 / Updated:  1/12/2019 / By:  ZT
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
    # Get all the files in the directory.
    files = os.listdir(dir)
    count = 0 

    # Loop over the files.
    for file in files:
        # Check the file via regex and ignore case.
        if re.search(r'(Name_or_Prefix_of_Font_Here)', file, flags=re.IGNORECASE):
            count += 1
    return count

def main():
    
    # Define Variables
    cmd_all_Users = ['/usr/bin/dscl', '.', 'list', '/Users']
    home_directories = []
    system_accounts = ['cas', 'cascom', 'daemon', 'Guest', 'nobody', 'root']
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
        #if directory != '/Users/utotth':
        # Calculate if the local accounts have matching fonts.
        user_Font_Count = user_Font_Count + check(directory + "/Library/Fonts")

    # Sum of system and user fonts.
    quanity = system_Font_Count + user_Font_Count

    # Return the results.
    if quanity == 0:
        print ("<result>Not Installed</result>")
    else:
        print ("<result>Installed</result>")


if __name__ == "__main__":
    main()
