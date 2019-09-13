#!/usr/bin/python
"""
###################################################################################################
# Script Name:  jamf_CollectDiagnostics.py
# By:  Zack Thompson / Created:  8/22/2019
# Version:  1.2.0 / Updated:  8/27/2019 / By:  ZT
#
# Description:  This script allows you to upload a compressed zip of specified files to a
#               computers' inventory record.
#
###################################################################################################
"""

import argparse
import base64
import datetime
from Foundation import NSBundle
import json
import objc
import os
import shutil
import subprocess
import sys
import zipfile

try:
    from urllib import request as urllib  # For Python 3
except ImportError:
    import urllib2 as urllib # For Python 2

try:
    from plistlib import dump as custom_plist_Writer  # For Python 3
    from plistlib import load as custom_plist_Reader  # For Python 3
except ImportError:
    from plistlib import writePlist as custom_plist_Writer  # For Python 2
    from plistlib import readPlist as custom_plist_Reader  # For Python 2


# Jamf Funcation to obfuscate credentials.
def DecryptString(inputString, salt, passphrase):
    """Usage: >>> DecryptString("Encrypted String", "Salt", "Passphrase")"""
    result = runUtility('echo \'{inputString}\' | /usr/bin/openssl enc -aes256 -d -a -A -S \'{salt}\' -k \'{passphrase}\''.format(salt=salt, passphrase=passphrase, inputString=inputString))
    return result


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


def plistReader(plistFile, verbose):
    """A helper function to get the contents of a Property List.
    Args:
        plistFile:  A .plist file to read in.
    Returns:
        stdout:  Returns the contents of the plist file.
    """

    if os.path.exists(plistFile):
        if verbose:
            print('Opening plist:  {}'.format(plistFile))

        try:
            plist_Contents = custom_plist_Reader(plistFile)
        except Exception:
            file_cmd = '/usr/bin/file --mime-encoding {}'.format(plistFile)
            file_response = runUtility(file_cmd)
            file_type = file_response.split(': ')[1].strip()
            if verbose:
                print('File Type:  {}'.format(file_type))

            if file_type == 'binary':
                if verbose:
                    print('Converting plist...')
                plutil_cmd = '/usr/bin/plutil -convert xml1 {}'.format(plistFile)
                plutil_response = runUtility(plutil_cmd)

            plist_Contents = custom_plist_Reader(plistFile)
    else:
        print('ERROR:  Unable to locate the specified plist file!')
        sys.exit(3)

    return plist_Contents


# Credit to (Mikey Mike/Froger/Pudquick/etc) for this logic:  https://gist.github.com/pudquick/c7dd1262bd81a32663f0
def get_system(attribute):
    """A helper function to get specific system attributes.
    Args:
        type:  The system attribute desired.
    Returns:
        stdout:  The system attribute value.
    """

    IOKit_bundle = NSBundle.bundleWithIdentifier_('com.apple.framework.IOKit')
    functions = [("IOServiceGetMatchingService", b"II@"), ("IOServiceMatching", b"@*"), ("IORegistryEntryCreateCFProperty", b"@I@@I"),]
    objc.loadBundleFunctions(IOKit_bundle, globals(), functions)

    def io_key(keyname):
        return IORegistryEntryCreateCFProperty(IOServiceGetMatchingService(0, IOServiceMatching("IOPlatformExpertDevice".encode("utf-8"))), keyname, None, 0)

    def get_hardware_uuid():
        return io_key("IOPlatformUUID".encode("utf-8"))

    # def get_hardware_serial():
    #     return io_key("IOPlatformSerialNumber".encode("utf-8"))

    # def get_board_id():
    #     return str(io_key("board-id".encode("utf-8"))).rstrip('\x00')

    options = {'uuid' : get_hardware_uuid #,
        #    'serial' : get_hardware_serial,
        #    'boardID' : get_board_id
    }

    return options[attribute]()


def apiGET(**parameters):
    """A helper function that performs a GET to the Jamf API.  Attempts to first use the python urllib2 library, but if that fails, falls back to the system curl.
    Args:
        jps_url:  Jamf Pro Server URL
        jps_credentials:  base64 encoded credentials
        endpoint:  API Endpoint
    Returns:
        stdout:  json data from the response contents
    """

    url = parameters.get('jps_url') + 'JSSResource' + parameters.get('endpoint')
    if parameters.get('verbose'):
        print('API URL:  {}'.format(url))

    try:
        if parameters.get('verbose'):
            print('Trying urllib...')
        headers = {'Accept': 'application/json', 'Authorization': 'Basic ' + parameters.get('jps_credentials')}
        request = urllib.Request(url, headers=headers)
        response = urllib.urlopen(request)
        statusCode = response.code
        json_response = json.loads(response.read())

    except Exception:
        # If urllib fails, resort to using curl.
        sys.exc_clear()
        if parameters.get('verbose'):
            print('Trying curl...')
        # Build the command.
        curl_cmd = '/usr/bin/curl --silent --show-error --no-buffer --fail --write-out "statusCode:%{{http_code}}" --location --header "Accept: application/json" --header "Authorization: Basic {jps_credentials}" --url {url} --request GET'.format(jps_credentials=parameters.get('jps_credentials'), url=url)
        response = runUtility(curl_cmd)
        json_content, statusCode = response.split('statusCode:')
        json_response = json.loads(json_content)

    return statusCode, json_response


def apiPOST(**parameters):
    """A helper function that performs a POST to the Jamf API.  Attempts to first use the python urllib2 library, but if that fails, falls back to the system curl.
    Args:
        jps_url:  Jamf Pro Server URL
        jps_credentials:  base64 encoded credentials
        endpoint:  API Endpoint
        file_to_upload:  A file to upload
        archive_size = size of the archive
    Returns:
        stdout:  the response contents
    """

    url = parameters.get('jps_url') + 'JSSResource' + parameters.get('endpoint')
    if parameters.get('verbose'):
        print('API URL:  {}'.format(url))
    if parameters.get('verbose'):
        print('Uploading file:  {}'.format(parameters.get('file_to_upload')))

    ##### Unable to quite get urllib to work at the moment...
    # try:
    # if parameters.get('verbose'):  print('Trying urllib...')
    # basename = os.path.basename(parameters.get('file_to_upload'))
    # # headers = {'Content-Disposition': 'name="{0}"'.format(parameters.get('file_to_upload')), 'Authorization': 'Basic ' + parameters.get('jps_credentials'), 'Content-Type': 'multipart/form-data', 'Content-Length': parameters.get('archive_size')}
    # headers = {'Authorization': 'Basic ' + parameters.get('jps_credentials'), "Content-type" : "application/zip", 'Content-Length': parameters.get('archive_size')}
    # request = urllib.Request(url, open(parameters.get('file_to_upload'), "rb"), headers=headers)
    # response = urllib.urlopen(request)
    # statusCode = response.code
    # content = response.read()

    # except Exception:
        # If urllib fails, resort to using curl.
        # sys.exc_clear()
    if parameters.get('verbose'):
        print('Trying curl...')
    # Build the command.
    curl_cmd = '/usr/bin/curl --silent --show-error --no-buffer --fail --write-out "statusCode:%{{http_code}}" --location --header "Accept: application/json" --header "Authorization: Basic {jps_credentials}" --url {url} --request POST --form name=@{file_to_upload}'.format(jps_credentials=parameters.get('jps_credentials'), url=url, file_to_upload=parameters.get('file_to_upload'))
    response = runUtility(curl_cmd)
    content, statusCode = response.split('statusCode:')

    return statusCode, content


def main():
    # print('All calling args:  {}'.format(sys.argv))

    ##################################################
    # Define Script Parameters

    parser = argparse.ArgumentParser(description="This script allows you to upload a compressed zip of specified files to a computers' inventory record")
    collection = parser.add_mutually_exclusive_group()

    parser.add_argument('--api-username', '-u', help='Provide the encrypted string for the API Username', required=True)
    parser.add_argument('--api-password', '-p', help='Provide the encrypted string for the API Password', required=True)
    collection.add_argument('--defaults', default=True, help='Collects the default files.', required=False)
    collection.add_argument('--file', '-f', type=str, nargs=1, help='Specify specific file to collect.', required=False)
    collection.add_argument('--directory', '-d', metavar='/path/to/directory/', type=str, help='Specify a specific directory to collect.', required=False)
    parser.add_argument('--quiet', '-q', action='store_true', help='Do not print verbose messages.', required=False)

    args = parser.parse_known_args()
    args = args[0]

    print('Argparse args:  {}'.format(args))

    if len(sys.argv) > 1:
        if args.file:
            upload_items = []
            upload_items.append((args.file[0]).strip())
        elif args.directory:
            upload_items = (args.directory).strip()
        elif args.defaults:
            upload_items = ['/private/var/log/jamf.log', '/private/var/log/install.log', '/private/var/log/system.log']

        if args.quiet:
            verbose = False
        else:
            verbose = True
    else:
        parser.print_help()
        sys.exit(0)

    ##################################################
    # Define Variables

    jamf_plist = '/Library/Preferences/com.jamfsoftware.jamf.plist'
    jps_api_user = (DecryptString((args.api_username).strip(), '8e12a14a386166c2', '0a0bd294022f2091e8484814')).strip()
    jps_api_password = (DecryptString((args.api_password).strip(), '596880db0d4d45a1', 'c045f87e5e7a47e3fd56110a')).strip()
    jps_credentials = base64.b64encode(jps_api_user + ':' + jps_api_password)
    time_stamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    archive_file = '/private/tmp/{}_logs'.format(time_stamp)
    archive_max_size = 40000000

    # Get the systems' Jamf Pro Server
    if os.path.exists(jamf_plist):
        jamf_plist_contents = plistReader(jamf_plist, verbose)
        jps_url = jamf_plist_contents['jss_url']
        if verbose:
            print('Jamf Pro Server URL:  {}'.format(jps_url))
    else:
        print('ERROR:  Missing the Jamf Pro configuration file!')
        sys.exit(1)

    # Get the system's UUID
    hw_UUID = get_system('uuid')
    if verbose:
        print('System UUID:  {}'.format(hw_UUID))

    ##################################################
    # Bits staged...

    if verbose:
        print('Requested files:  {}'.format(upload_items))

    if args.directory:
        if os.path.exists(upload_items):
            parent_directory = os.path.abspath(os.path.join(upload_items, os.pardir))
            shutil.make_archive(archive_file, 'zip', parent_directory, upload_items )
        else:
            print('ERROR:  Unable to locate the provided directory!')
            sys.exit(4)
    else:
        zip_file = zipfile.ZipFile('{}.zip'.format(archive_file), 'w')
        for upload_item in upload_items:
            if verbose:
                print('Archiving file:  {}'.format(os.path.abspath(upload_item)))
            if os.path.exists(upload_item):
                zip_file.write(os.path.abspath(upload_item), compress_type=zipfile.ZIP_DEFLATED)
            else:
                print('WARNING:  Unable to locate the specified file!')
        zip_file.close()

    archive_size = os.path.getsize('{}.zip'.format(archive_file))
    if verbose:
        print('Archive name:  {}.zip'.format(archive_file))
        print('Archive size:  {}'.format(archive_size))

    if archive_size > archive_max_size:
        print('Aborting:  File size is larger than allowed!')
        sys.exit(2)

    # Query the API to get the computer ID
    status_code, json_data = apiGET(jps_url=jps_url, jps_credentials=jps_credentials, endpoint='/computers/udid/{uuid}'.format(uuid=hw_UUID), verbose=verbose)

    if int(status_code) == 200:
        computer_id = json_data.get('computer').get('general').get('id')
        if verbose:
            print('Computer ID:  {}'.format(computer_id))
    else:
        print('ERROR:  Failed to retrieve devices\' computer ID!')
        sys.exit(5)

    # Upload file via the API
    status_code, content = apiPOST(jps_url=jps_url, jps_credentials=jps_credentials, endpoint='/fileuploads/computers/id/{id}'.format(id=computer_id), file_to_upload='{}.zip'.format(archive_file), archive_size=archive_size, verbose=verbose)

    if int(status_code) == 204:
        if content:
            if verbose:
                print('Response:  {}'.format(content))
        print('Upload complete!')
    else:
        print('ERROR:  Failed to upload file to the JPS!')
        sys.exit(6)

if __name__ == "__main__":
    main()
