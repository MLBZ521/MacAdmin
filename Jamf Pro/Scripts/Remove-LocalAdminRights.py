#!/opt/ManagedFrameworks/Python.framework/Versions/Current/bin/python3

###################################################################################################
# Script Name:  Remove-LocalAdminRights.py
# By:  Zack Thompson / Created:  4/20/2020
# Version:  1.0.1 / Updated:  10/22/2021 / By:  ZT
#
# Description:  This script removes accounts from the local admin group; accounts that need to 
# 		remain in the admin group can be specified in Jamf Pro script parameters
#
###################################################################################################

import os
import plistlib
import re
import shlex
import subprocess
import sys

def runUtility(command):
    """A helper function for subprocess.
    Args:
        command:  Must be a string.
    Returns:
        Results in a dictionary.
    """

    # Validate that command is a string
    if not isinstance(command, str):
        raise TypeError('Command must be in a str')

    # Format the command
    command = shlex.split(command)

    # Run the command
    process = subprocess.Popen( command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=False )

    # Execute the command
    (stdout, stderr) = process.communicate()

    # Return a result dictionary
    return {
        "stdout": (stdout).strip(),
        "stderr": (stderr).strip() if stderr != None else None,
        "status": process.returncode,
        "success": True if process.returncode == 0 else False
    }


def plistFile_Reader(plistFile):
    """A helper function to get the contents of a Property List.
    Args:
        plistFile:  A .plist file to read in.
    Returns:
        stdout:  Returns the contents of the plist file.
    """

    # Verify the file exists
    if os.path.exists(plistFile):

        try:
            # Read the plist file
            plist_Contents = plistlib.readPlist(plistFile)

        except Exception:

            # If it fails, check the encoding
            result_encoding = runUtility('/usr/bin/file --mime-encoding {}'.format(plistFile))

            # Verify command result
            if not result_encoding['success']:
                print("ERROR:  failed to get the file encoding of:  {}".format(plistFile))
                print(result_encoding['stderr'])
                sys.exit(4)

            # Get the result of the command
            file_encoding = result_encoding['stdout'].split(': ')[1].strip()

            if file_encoding == 'binary':
                # Convert the file t xml if it's in binary format
                plutil_response = runUtility('/usr/bin/plutil -convert xml1 {}'.format(plistFile))

                # Verify command result
                if not plutil_response['success']:
                    print("ERROR:  failed to convert the file encoding on:  {}".format(plistFile))
                    print(plutil_response['stderr'])
                    sys.exit(5)

                # Read the plist file again
                plist_Contents = plistlib.readPlist(plistFile)

    else:
        print('ERROR:  Unable to locate the plist file:  {}'.format(plistFile))
        sys.exit(3)
    
    return plist_Contents


def main():
    print('\n*****  Remove-LocalAdminRights process:  START  *****\n')

    ##################################################
    # Define Variables

    exitCode=0
    protected_admins = []
    jamf_plist = "/Library/Preferences/com.jamfsoftware.jamf.plist"
    prod_jps = "https://prod.jps.server.com:8443/"
    dev_jps = "https://dev.jps.server.com:8443/"

    ##################################################
    # Build protected_admins list

    protected_admins.append("root")

    # Loop through the passed script parameters
    for arg in sys.argv[4:]:

        if len(arg) != 0:

            if re.search(",", arg):

                comma_args = arg.split(",", -1)
                arg_list = [ account.strip() for account in comma_args ]
                protected_admins.extend(arg_list)

            else:
                protected_admins.append(arg)

    # Check the local environment and add the proper accounts
    # Read the Jamf Plist to get the current environment
    jamf_plist_contents = plistFile_Reader(jamf_plist)
    jss_url = jamf_plist_contents['jss_url']

    # Determine which environment we're in
    if jss_url == prod_jps:
        protected_admins.append("jma")

    elif jss_url == dev_jps:
        protected_admins.extend(["jmadev"])
    else:
        print("ERROR:  Unknown Jamf Pro environment!")
        sys.exit(1)

    print('Protected Admins:  {}\n\n'.format(protected_admins))

    ##################################################
    # Bits staged...

    # Get a list of the current admin group
    results = runUtility("/usr/bin/dscl -plist . -read Groups/admin GroupMembership")

    # Verify command result
    if not results['success']:
        print("Failed to admin group membership!")
        print(results['stderr'])
        sys.exit(2)

    # Get the admin group memembership
    plist_contents = plistlib.readPlistFromString(results['stdout'])
    admin_group = plist_contents.get('dsAttrTypeStandard:GroupMembership')

    # For verbosity in the policy log
    print("The following accounts are in the local admin group:")
    for user in admin_group:
        print("  - {}".format(user))

    print("\n")

    # Loop through the admin users
    for user in admin_group:

	    # Check if the admin user is a protected_admin
        if user not in protected_admins:

    		# Remove user from the admin group
            results = runUtility("/usr/sbin/dseditgroup -o edit -d '{}' -t user admin".format(user))

    		# Check if the removal was successful
            if not results['success']:
                print("{} - FAILED to remove from admin group".format(user))
                print(results['stderr'])
                exitCode=6

            else:
                print("{} - removed from admin group".format(user))

    print("\n")

    # Get an updated list of the local admin group
    updated_results = runUtility("/usr/bin/dscl -plist . -read Groups/admin GroupMembership")

    # Verify command result
    if not updated_results['success']:
        print("Failed to admin group membership!")
        print(results['stderr'])
        sys.exit(2)

    # Get the admin group memembership
    updated_plist_contents = plistlib.readPlistFromString(updated_results['stdout'])
    updated_admin_group = updated_plist_contents.get('dsAttrTypeStandard:GroupMembership')

    # For verbosity in the policy log
    print("Updated local admin group:")
    for user in updated_admin_group:
        print(" - {}".format(user))

    print("\n*****  Remove-LocalAdminRights Process:  COMPLETE  *****")
    sys.exit(exitCode)


if __name__ == "__main__":
    main()
