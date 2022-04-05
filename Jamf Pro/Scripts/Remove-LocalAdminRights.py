#!/opt/ManagedFrameworks/Python.framework/Versions/Current/bin/python3

###################################################################################################
# Script Name:  Remove-LocalAdminRights.py
# By:  Zack Thompson / Created:  4/20/2020
# Version:  1.1.0 / Updated:  4/1/2022 / By:  ZT
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


def execute_process(command, input=None):
    """
    A helper function for subprocess.

    Args:
        command (str):  The command line level syntax that would be written in a shell script or 
            a terminal window.
        input (str, optional): Any input that should be passed "interactively" to the process 
            being executed.

    Returns:
        dict:  Results in a dictionary
    """

    # Validate that command is not a string
    if not isinstance(command, str):
        raise TypeError("Command must be a str type")

    # Format the command
    command = shlex.split(command)

    # Run the command
    process = subprocess.Popen( command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, 
        shell=False, universal_newlines=True )

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


def execute_dscl(option="-plist", datasource=".", command="-read", parameters=""):
    """Execute dscl and return the values

    Args:
        option (str, optional): The option to use. Defaults to "-plist".
        datasource (str, optional): The node to query. Defaults to ".".
        command (str, optional): The dscl command to run. Defaults to "-read".
        parameters (str, optional): Parameters that will be passed to the command option. Defaults to "".

    Returns:
        dict: A dict of the results from dscl
    """
    results = execute_process(f"/usr/bin/dscl {option} {datasource} {command} {parameters}")

    # Verify command result
    if not results['success']:
        print("Failed to admin group membership!")
        print(results['stderr'])
        sys.exit(2)

    return plistlib.loads(results['stdout'].encode())


def main():
    print('\n*****  Remove-LocalAdminRights process:  START  *****\n')

    ##################################################
    # Define Variables

    # List your environments jps servers and local admins here 
    prod_jps = "https://prod.jps.server.com:8443/"
    prod_protected_admins = ["jma"]
    dev_jps = "https://dev.jps.server.com:8443/"
    dev_protected_admins = ["jmadev"]

    exit_code=0
    jamf_plist = "/Library/Preferences/com.jamfsoftware.jamf.plist"

    ##################################################
    # Build protected_admins list

    protected_admins = ["root"]

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

    # Verify the file exists
    if not os.path.exists(jamf_plist):
        raise Exception("Missing:  com.jamfsoftware.jamf.plist")

    with open(jamf_plist, "rb") as plist:
        jamf_plist_contents = plistlib.load(plist)

    jss_url = jamf_plist_contents['jss_url']

    # Determine which environment we're in
    if jss_url == prod_jps:
        protected_admins.extend(prod_protected_admins)

    elif jss_url == dev_jps:
        protected_admins.extend(dev_protected_admins)
 
    else:
        print("ERROR:  Unknown Jamf Pro environment!")
        sys.exit(1)

    print('Protected Admins:  {}\n\n'.format(protected_admins))

    ##################################################
    # Bits staged...

    # Get the admin group memembership
    results_admin_group_members = execute_dscl(parameters="Groups/admin GroupMembership")
    admin_group = results_admin_group_members.get('dsAttrTypeStandard:GroupMembership')

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
            results = execute_process("/usr/sbin/dseditgroup -o edit -d '{}' -t user admin".format(user))

    		# Check if the removal was successful
            if not results['success']:
                print("{} - FAILED to remove from admin group".format(user))
                print(results['stderr'])
                exit_code=6

            else:
                print("{} - removed from admin group".format(user))

    print("\n")

    # Get an updated list of the local admin group
    results_updated_admin_group_members = execute_dscl(parameters="Groups/admin GroupMembership")
    updated_admin_group = results_updated_admin_group_members.get('dsAttrTypeStandard:GroupMembership')

    # For verbosity in the policy log
    print("Updated local admin group:")
    for user in updated_admin_group:
        print(" - {}".format(user))

    print("\n*****  Remove-LocalAdminRights Process:  COMPLETE  *****")
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
