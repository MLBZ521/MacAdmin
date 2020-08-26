#!/usr/bin/python
###################################################################################################
# Script Name:  license_AutoCAD.py
# By:  Zack Thompson / Created:  8/21/2020
# Version:  1.0.0 / Updated:  8/21/2020 / By:  ZT
#
# Description:  This script applies the license for AutoCAD 2020 and newer.
#
# Reference:  
#   https://knowledge.autodesk.com/support/autocad/learn/caas/sfdcarticles/sfdcarticles/Use-Installer-Helper.html
#   https://knowledge.autodesk.com/customer-service/download-install/activate/find-serial-number-product-key/product-key-look
#
###################################################################################################

import json
import os
import shlex
import subprocess
import sys


def runUtility(command):
    """
    A helper function for subprocess.

    Args:
        command:  The command line level syntax that would be written in a 
        shell script or a terminal window.  (str)
    Returns:
        Results in a dictionary.
    """

    # Validate that command is not a string
    if not isinstance(command, str):
        raise TypeError('Command must be a str type')

    # Format the command
    command = shlex.split(command)

    # Run the command
    process = subprocess.Popen( command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, 
        shell=False, universal_newlines=True )
    (stdout, stderr) = process.communicate()

    result_dict = {
        "stdout": (stdout).strip(),
        "stderr": (stderr).strip() if stderr != None else None,
        "exitcode": process.returncode,
        "success": True if process.returncode == 0 else False
    }

    return result_dict


def main():

    print("*****  License AutoCAD process:  START  *****")

    ##################################################
    # Define Script Parameters

    # Determine License Type
    if sys.argv[4] in ["T&R", "Teaching and Research", "Academic"]:

        license_type="Academic"

    elif sys.argv[4] in ["Admin", "Administrative"]:

        license_type="Administrative"

    else:

		print("ERROR:  Invalid License Type provided")
		print("*****  License AutoCAD process:  FAILED  *****")
		sys.exit(1)

    # Determine License Mechanism
    if sys.argv[5] in ["LM", "License Manager", "Network"]:

        license_mechanism="Network"

        if license_type == "Academic":

            license_servers = "12345@licser1.company.com,12345@licser2.company.com,12345@licser3.company.com"

        elif license_type == "Administrative":

            license_servers = "67890@licser4.company.com,67890@licser5.company.com,67890@licser6.company.com"

    elif sys.argv[5] in ["Stand Alone", "Local"]:

        license_mechanism="Local"

    else:

		print("ERROR:  Invalid License Mechanism provided")
		print("*****  License AutoCAD process:  FAILED  *****")
		sys.exit(2)

    ##################################################
    # Define Variables
    exit_code = 0
    autodesk_lic_helper = "/Library/Application Support/Autodesk/AdskLicensing/Current/helper/AdskLicensingInstHelper"

    ##################################################
    # Bits staged...

    print("License Type:  {}".format(license_type))
    print("License Mechanism:  {}".format(license_mechanism))

    # Verify the license helper binary exists
    if not os.path.exists(autodesk_lic_helper):

        print("ERROR:  AutoCAD was not found!")
        print("*****  License AutoCAD process:  FAILED  *****")
    	sys.exit(3)

    # Check for registered applications
    list_results = runUtility( "'{}' list".format(autodesk_lic_helper) )

    if not list_results['success']:

        print("ERROR:  Failed to query the AutoDesk Licensing Service")
        print("Return Code {}".format(list_results['exitcode']))
        print("stderr:\n{}".format(list_results['stderr']))
        print("stdout:\n{}".format(list_results['stdout']))
        print("*****  License AutoCAD process:  FAILED  *****")
        sys.exit(4)

    # Load the JSON results
    list_json_results = json.loads(list_results['stdout'])

    # Verify at least one application was registered
    if len(list_json_results) == 0:

        print("ERROR:  The AutoDesk Licensing Service does not have a registered AutoCAD \
            application!")
        print("*****  License AutoCAD process:  FAILED  *****")
        sys.exit(5)

    # Loop through the results
    for app in list_json_results:

        product_key = app["sel_prod_key"]
        product_version = app["sel_prod_ver"]

        print("Product Key:  {}".format(product_key))
        print("Product Version:  {}".format(product_version))

        if license_mechanism == "Network":

            change_results = runUtility( "'{}' change --prod_key '{}' --prod_ver '{}' \
                --lic_method NETWORK --lic_server_type REDUNDANT --lic_servers '{}'".format(
                    autodesk_lic_helper, product_key, product_version, license_servers ) )

        else license_mechanism == "Local"

            # Functionality would need to be added to support a local license
            print("Functionality would need to be added to support a local license.")

        if not change_results['success']:

            print("ERROR:  Failed license AutoDesk product key '{}' product version '{}'".format(
                product_key, product_version ) )
            print("Return Code {}".format(change_results['exitcode']))
            print("stderr:\n{}".format(change_results['stderr']))
            print("stdout:\n{}".format(change_results['stdout']))
            print("*****  License AutoCAD process:  FAILED  *****")
            exit_code = (10)

        print("Successfully licensed product key '{}' and version '{}'.".format(
            product_key, product_version))

    print("*****  License AutoCAD process:  COMPLETE  *****")
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
