#!/opt/ManagedFrameworks/Python.framework/Versions/Current/bin/python3

"""
Script Name:  Install-BomgarJumpClient.py
By:  Zack Thompson / Created:  3/2/2020
Version:  1.4.2 / Updated:  1/4/2022 / By:  ZT

Description:  Installs a Bomgar Jump Client with the passed parameters
"""

import argparse
import objc
import os
import plistlib
import re
import shlex
import subprocess
import sys
from Cocoa import NSBundle
from SystemConfiguration import SCDynamicStoreCopyConsoleUser
from xml.etree import ElementTree

import requests

def execute_process(command):
    """
    A helper function for subprocess.

    Args:
        command (str):  The command line level syntax that would be written in a 
            shell script or a terminal window

    Returns:
        dict:  Results in a dictionary
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

    return {
        "stdout": (stdout).strip(),
        "stderr": (stderr).strip() if stderr != None else None,
        "exitcode": process.returncode,
        "success": True if process.returncode == 0 else False
    }


def get_system(attribute):
    """A helper function to get specific system attributes.

    Credit:  Mikey Mike/Froger/Pudquick/etc
    Source:  https://gist.github.com/pudquick/c7dd1262bd81a32663f0

    Args:
        attribute:  The system attribute desired.

    Returns:
        stdout:  The system attribute value.
    """

    IOKit_bundle = NSBundle.bundleWithIdentifier_('com.apple.framework.IOKit')
    functions = [
        ("IOServiceGetMatchingService", b"II@"), 
        ("IOServiceMatching", b"@*"), 
        ("IORegistryEntryCreateCFProperty", b"@I@@I")
    ]
    objc.loadBundleFunctions(IOKit_bundle, globals(), functions)

    def io_key(keyname):
        return IORegistryEntryCreateCFProperty(
            IOServiceGetMatchingService(
                0, IOServiceMatching(
                    "IOPlatformExpertDevice".encode("utf-8"))), keyname, None, 0)

    # def get_hardware_uuid():
    #     return io_key("IOPlatformUUID".encode("utf-8"))

    def get_hardware_serial():
        return io_key("IOPlatformSerialNumber")

    # def get_board_id():
    #     return str(io_key("board-id".encode("utf-8"))).rstrip('\x00')

    options = {'serial' : get_hardware_serial #,
        #    'uuid' : get_hardware_uuid,
        #    'boardID' : get_board_id
    }

    return options[attribute]()

def get_model(serial_number):
    """A helper function to get the friendly model.
    Args:
        serial_number:  Devices' Serial Number.
    Returns:
        stdout:  friendly model name or "".
    """

    if len(serial_number) == 12:
        lookup_code = serial_number[-4:]
    elif len(serial_number) == 11:
        lookup_code = serial_number[-3:]
    else:
        print("Unexpected serial number length:  {}".format(serial_number))
        return ""

    lookup_url = "https://support-sp.apple.com/sp/product?cc={}".format(lookup_code)

    xml = requests.get(lookup_url).text

    try:
        tree = ElementTree.fromstringlist(xml)
        return tree.find('.//configCode').text

    except ElementTree.ParseError as err:
        print("Failed to retrieve model name:  {}".format(err.strerror))
        return ""

def mount(pathname):
    """A helper function to mount a volume and return the mount path.
    Args:
        pathname:  Path to a dmg to mount.
    Returns:
        stdout:  Returns the path to the mounted volume.
    """

    mount_cmd = "/usr/bin/hdiutil attach -plist -mountrandom /private/tmp -nobrowse {}".format(
        pathname)

    results = execute_process(mount_cmd)

    if not results['success']:
        print("ERROR:  failed to mount:  {}".format(pathname))
        print(results['stdout'])
        print(results['stderr'])
        sys.exit(2)

    # Read output plist.
    xml = plistlib.loads(results['stdout'].encode())

    # Find mount point.
    for part in xml.get("system-entities", []):
        if "mount-point" in part:
            # print("mount_point:  {}".format(part["mount-point"]))
            return part["mount-point"]

    print("mounting {} failed:  unexpected output from hdiutil".format(pathname))

def main():
    print('\n*****  install_Bomgar process:  START  *****\n')

    # Reset sys.argv to reformat parameters being passed from Jamf Pro.
    orig_argv = sys.argv
    # print('original_paramters:  {}'.format(orig_argv))

    sys.argv = []
    # sys.argv.append(orig_argv[0])
    for arg in orig_argv[1:]:
        if len(arg) != 0:
            sys.argv.extend(arg.split(" ", 1))

    print('paramters:  {}\n'.format(sys.argv))

    ##################################################
    # Define Script Parameters

    parser = argparse.ArgumentParser(description="This script installs a Bomgar Jump Client with the passed parameters.")

    parser.add_argument('--key', '-k', help='Sets the Jump Client Key.', required=True)
    parser.add_argument('--group', '-g', help='Sets the Jump Client Group.  You must pass the Jump Group "code_name".', required=False)
    parser.add_argument('--tag', '-t', help='Sets the Jump Client Tag.', required=False)
    parser.add_argument('--name', '-a', help='Sets the Jump Client Name.  default value:  <Full Name>, <Username>', required=False)
    parser.add_argument('--comments', '-c', help='Sets the Jump Client Comments.  default value:  <Friendly Model Name>, <Serial Number>', required=False)
    parser.add_argument('--site', '-s', default="bomgar.company.org", help='Associates the Jump Client with the public portal which has the given hostname as a site address.  default value:  bomgar.company.org', required=False)
    parser.add_argument('--policy-present', '-p', help='Policy that controls the permission policy during a support session if the customer is present at the console.  You must pass the Policy\'s "code_name".', required=False)
    # parser.add_argument('--policy-not-present', '-n', default="Policy-Unattended-Jump", help='Policy that controls the permission policy during a support session if the customer is not present at the console.  You must pass the Policy's "code_name".', required=False)
    parser.add_argument('--policy-not-present', '-n', help='Policy that controls the permission policy during a support session if the customer is not present at the console.  You must pass the Policy\'s "code_name".', required=False)

    args, unknown = parser.parse_known_args(sys.argv)
    # print("parsed_parameters:  {}".format(args))
    # sys.exit(0)

    # Set the Jump Client Key
    jumpKey = args.key

    # Set the Jump Client Group
    if args.group is None:
        jumpGroup = ""
    else:
        jumpGroup = "--jc-jump-group 'jumpgroup:{}'".format(args.group)

    # Set the Jump Client Tag
    if args.tag is None:
        jumpTag = ""
    else:
        jumpTag = "--jc-tag '{}'".format(args.tag)

    # Set the Jump Client Name
    if args.name is None:
        # Get the Console User
        username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]
        console_user = [username,""][username in [u"loginwindow", None, u""]]

        # Verify that a console user was present
        if console_user:
            # Get the Console Users' Full Name
            full_name_cmd = "/usr/bin/dscl . -read \"/Users/{}\" dsAttrTypeStandard:RealName".format(
                console_user)
            full_name_results = execute_process(full_name_cmd)

            if full_name_results['success']:
                full_name = re.sub("RealName:\s+", "", full_name_results['stdout'])

                if "Setup User (_mbsetupuser)" != "{} ({})".format(full_name, console_user):
                    jumpName = "--jc-name '{} ({})'".format(full_name, console_user)

                else:
                    jumpName = ""

            else:
                # In case something goes wrong with dscl, set to none
                jumpName = ""

        else:
            # If a console user was not present, set to none
            jumpName = ""
    else:
        jumpName = "--jc-name '{}'".format(args.name)

    # Set the Jump Client Comments
    if args.comments is None:
        serial_number = get_system("serial")
        model_friendly = get_model(serial_number)
        jumpComments = "--jc-comments '{}, {}'".format(model_friendly, serial_number)
    else:
        jumpComments = "--jc-comments '{}'".format(args.comments)

    # Set the Jump Client Site
    if args.site is None:
        jumpSite = ""
    else:
        jumpSite = "--jc-public-site-address '{}'".format(args.site)

    # Set the Jump Client Console User Not Present Policy
    if args.policy_not_present is None:
        jumpPolicyNotPresent = ""
    else:
        jumpPolicyNotPresent = "--jc-session-policy-not-present '{}'".format(
            args.policy_not_present)

    # Set the Jump Client Console User Present Policy
    if args.policy_present is None:
        jumpPolicyPresent = ""
    else:
        jumpPolicyPresent = "--jc-session-policy-present '{}'".format(args.policy_present)

    ##################################################
    # Define Variables

    parameters = [ 
        jumpGroup, jumpSite, jumpPolicyNotPresent, jumpTag, 
        jumpName, jumpComments, jumpPolicyPresent 
    ]
    install_parameters = " ".join( filter( None, parameters ) )
    bomgar_dmg = ""
    mount_point = ""
    install_app = ""

    ##################################################
    # Bits staged...

    for a_file in os.listdir("/private/tmp"):
        if re.search(r'(bomgar-scc-)[a-z0-9]+[.](dmg)', a_file):
            bomgar_installer = os.path.join("/private/tmp", a_file)
            os.rename(bomgar_installer, "/tmp/bomgar-scc-{}.dmg".format(jumpKey))
            bomgar_dmg = "/tmp/bomgar-scc-{}.dmg".format(jumpKey)
            break

    if os.path.exists(bomgar_dmg):
        mount_point = mount(bomgar_dmg)
    else:
        print("ERROR:  Bomgar DMG was not found at the expected location!")
        print('*****  install_Bomgar process:  FAILED  *****')
        sys.exit(1)

    # print("mount_point:  {}".format(mount_point))

    try:
        for a_file in os.listdir(mount_point):
            if re.search(r'.+[.](app)', a_file):
                install_app = os.path.join(mount_point, a_file)
                break

        # print("install_app:  {}".format(install_app))

        if os.path.exists(install_app):
            # Build the command.
            install_cmd = "'{}/Contents/MacOS/sdcust' --silent {}".format(
                install_app, install_parameters)
            print("install_cmd:  {}".format(install_cmd))

            results = execute_process(install_cmd)

            if not results['success']:
                print("ERROR:  failed to install Bomgar Jump Client")
                print("Results:  {}".format(results['stderr']))
                sys.exit(2)

            # print("Results:  {}".format(results['stdout']))
        else:
            print("ERROR:  Bomgar Jump Client installer was not found at the expected location!")
            print('*****  install_Bomgar process:  FAILED  *****')
            sys.exit(2)

        print('*****  install_Bomgar process:  SUCCESS  *****')

    finally:

        unmount_cmd = "/usr/bin/hdiutil detach {}".format(mount_point)
        results = execute_process(unmount_cmd)

        if not results['success']:
            print("ERROR:  failed to mount:  {}".format(mount_point))
            print(results['stdout'])
            print(results['stderr'])
            sys.exit(2)

if __name__ == "__main__":
    main()
