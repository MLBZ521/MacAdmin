#!/opt/ManagedFrameworks/Python.framework/Versions/Current/bin/python3

"""
Script Name:  jamf_CollectDiagnostics.py
By:  Zack Thompson / Created:  8/22/2019
Version:  1.5.0 / Updated:  12/03/2021 By:  ZT

Description:  This script allows you to upload a compressed 
    zip of specified files to a computers' inventory record.

"""

import argparse
import base64
import csv
import datetime
from Foundation import NSBundle
import json
import objc
import os
import plistlib
import requests
import shutil
import sqlite3
import subprocess
import sys
import zipfile


# Jamf Function to obfuscate credentials.
def DecryptString(inputString, salt, passphrase):
    """
    Usage: >>> DecryptString("Encrypted String", "Salt", "Passphrase")
    """

    return runUtility(
        "echo '{inputString}' | /usr/bin/openssl enc -aes256 -d -a -A -S '{salt}' -k '{passphrase}'".format(
            salt=salt, passphrase=passphrase, inputString=inputString))


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
        print ("Error code:  {}".format(error.returncode))
        print ("Error:  {}".format(error))
        process = "error"

    return process


def plistReader(plist_file_path, verbose):
    """A helper function to get the contents of a Property List.
    Args:
        plist_file_path:  A .plist file to read in.
    Returns:
        stdout:  Returns the contents of the plist file.
    """

    if os.path.exists(plist_file_path):
        if verbose:
            print("Opening plist:  {}".format(plist_file_path))

        try:
            # Get the contents of the plist file.
            with open(plist_file_path, "rb") as plist_file:
                plist_Contents = plistlib.load(plist_file)
        except Exception:
            file_cmd = "/usr/bin/file --mime-encoding {}".format(plist_file_path)
            file_response = runUtility(file_cmd)
            file_type = file_response.split(": ")[1].strip()
            if verbose:
                print("File Type:  {}".format(file_type))

            if file_type == "binary":
                if verbose:
                    print("Converting plist...")
                plutil_cmd = "/usr/bin/plutil -convert xml1 {}".format(plist_file_path)
                plutil_response = runUtility(plutil_cmd)

            # Get the contents of the plist file.
            with open(plist_file_path, "rb") as plist_file:
                plist_Contents = plistlib.load(plist_file)
    else:
        print("ERROR:  Unable to locate the specified plist file!")
        sys.exit(3)

    return plist_Contents


# Modified from:  https://stackoverflow.com/a/36211470
def dbTableWriter(database, table):
    """A helper function read the contents of a database table and write to a csv.
    Args:
        database:  A database that can be opened with sqlite
        table:  A table in the database to select
    Returns:
        file:  Returns the abspath of the file.
    """

    file_name = "/private/tmp/{}.csv".format(table)

    # Setup database connection
    db_connect = sqlite3.connect(database)
    database = db_connect.cursor()

    # Execute query
    database.execute("select * from {}".format(table))

    # Write to file
    with open(file_name,"w") as table_csv:
        csv_out = csv.writer(table_csv)
        # Write header
        csv_out.writerow([description[0] for description in database.description])
        # write data
        for result in database:
            csv_out.writerow(result)

    return os.path.abspath(file_name)


# Credit to (Mikey Mike/Froger/Pudquick/etc) for this logic:  
#   https://gist.github.com/pudquick/c7dd1262bd81a32663f0
def get_system(attribute):
    """A helper function to get specific system attributes.
    Args:
        type:  The system attribute desired.
    Returns:
        stdout:  The system attribute value.
    """

    IOKit_bundle = NSBundle.bundleWithIdentifier_("com.apple.framework.IOKit")
    functions = [
        ( "IOServiceGetMatchingService", b"II@" ), 
        ( "IOServiceMatching", b"@*" ), 
        ( "IORegistryEntryCreateCFProperty", b"@I@@I" )
    ]
    objc.loadBundleFunctions(IOKit_bundle, globals(), functions)

    def io_key(keyname):
        return IORegistryEntryCreateCFProperty( 
            int( IOServiceGetMatchingService(
                0, IOServiceMatching(
                    "IOPlatformExpertDevice".encode("utf-8")))), keyname, None, 0)

    def get_hardware_uuid():
        return io_key("IOPlatformUUID")

    # def get_hardware_serial():
    #     return io_key("IOPlatformSerialNumber".encode("utf-8"))

    # def get_board_id():
    #     return str(io_key("board-id".encode("utf-8"))).rstrip("\x00")

    options = {"uuid" : get_hardware_uuid #,
        #    "serial" : get_hardware_serial,
        #    "boardID" : get_board_id
    }

    return options[attribute]()


def apiGET(**parameters):
    """A helper function that performs a GET to the Jamf API.  
    Attempts to first use the Python `requests` library, 
    but if that fails, falls back to the system curl.

    Args:
        jps_url:  Jamf Pro Server URL
        jps_credentials:  base64 encoded credentials
        endpoint:  API Endpoint
    Returns:
        stdout:  json data from the response contents
    """

    url = "{}JSSResource{}".format(parameters.get("jps_url"), parameters.get("endpoint"))

    if parameters.get("verbose"):
        print("API URL:  {}".format(url))

    try:
        if parameters.get("verbose"):
            print("Trying `requests`...")
        headers = {
            "Accept": "application/json", 
            "Authorization": "Basic {}".format(parameters.get("jps_credentials"))
            }
        response = requests.get(url, headers=headers)
        statusCode = response.status_code
        json_response = response.json()

    except Exception:
        # If `requests` fails, resort to using curl.

        if parameters.get("verbose"):
            print("Trying curl...")

        # Build the command.
        curl_cmd = "/usr/bin/curl --silent --show-error --no-buffer --fail --write-out \
            'statusCode:%{{http_code}}' --location --header 'Accept: application/json' \
            --header 'Authorization: Basic {jps_credentials}' --url {url} --request GET".format(
                jps_credentials=parameters.get("jps_credentials"), url=url)
        response = runUtility(curl_cmd)
        json_content, statusCode = response.split(b"statusCode:")
        json_response = json.loads(json_content)

    return statusCode, json_response


def apiPOST(**parameters):
    """A helper function that performs a POST to the Jamf API.  
    Attempts to first use the python `requests` library, 
    but if that fails, falls back to the system curl.

    Args:
        jps_url:  Jamf Pro Server URL
        jps_credentials:  base64 encoded credentials
        endpoint:  API Endpoint
        file_to_upload:  A file to upload
        archive_size = size of the archive
    Returns:
        stdout:  the response contents
    """

    url = "{}JSSResource{}".format(parameters.get("jps_url"), parameters.get("endpoint"))

    if parameters.get("verbose"):
        print("API URL:  {}".format(url))
        print("Uploading file:  {}".format(parameters.get("file_to_upload")))

    # try:
        ##### Unable to get requests nor urllib to work...
        # if parameters.get("verbose"):
        #     print("Trying `requests`...")

        # files = {
        #     "name": (None, open(parameters.get("file_to_upload"), "rb"))
        # }

        # body, content_type = requests.models.RequestEncodingMixin._encode_files(files, {})
        # headers = {
        #     "Authorization": "Basic {}".format(parameters.get("jps_credentials")), 
        #     "Content-Type": content_type
        # }
        # response = requests.post(url, data=body, headers=headers)
        # statusCode = response.status_code
        # content = response.text

    # except Exception:
        # If urllib fails, resort to using curl.

    if parameters.get("verbose"):
        print("Trying curl...")

    # Build the command.
    curl_cmd = "/usr/bin/curl --silent --show-error --no-buffer --fail --write-out \
        'statusCode:%{{http_code}}' --location --header 'Accept: application/json' \
        --header 'Authorization: Basic {jps_credentials}' --url {url} --request POST \
        --form name=@{file_to_upload}".format(
            jps_credentials=parameters.get("jps_credentials"), url=url, 
            file_to_upload=parameters.get("file_to_upload")
        )

    response = runUtility(curl_cmd)
    content, statusCode = response.split(b"statusCode:")

    return statusCode, content


def main():
    # print("All calling args:  {}".format(sys.argv))

    ##################################################
    # Define Script Parameters

    parser = argparse.ArgumentParser(
        description="This script allows you to upload a compressed zip \
            of specified files to a computers' inventory record")
    collection = parser.add_mutually_exclusive_group()

    parser.add_argument("--api-username", "-u", 
        help="Provide the encrypted string for the API Username", required=True)
    parser.add_argument("--api-password", "-p", 
        help="Provide the encrypted string for the API Password", required=True)
    collection.add_argument("--defaults", default=True, 
        help="Collects the default files.", required=False)
    collection.add_argument("--file", "-f", type=str, nargs=1, 
        help="Specify specific file to collect.", required=False)
    collection.add_argument("--directory", "-d", metavar="/path/to/directory/", type=str, 
        help="Specify a specific directory to collect.", required=False)
    parser.add_argument("--quiet", "-q", action="store_true", 
        help="Do not print verbose messages.", required=False)

    args = parser.parse_known_args()
    args = args[0]

    print("Argparse args:  {}".format(args))
    # sys.exit(0)

    if len(sys.argv) > 1:
        if args.file:
            upload_items = []
            upload_items.append((args.file[0]).strip())
        elif args.directory:
            upload_items = (args.directory).strip()
        elif args.defaults:
            upload_items = [
                "/private/var/log/jamf.log", 
                "/private/var/log/install.log", 
                "/private/var/log/system.log", 
                "/private/var/log/jamf_RecoveryAgent.log", 
                "/private/var/log/jamf_ReliableEnrollment.log", 
                "/private/var/log/32bitApps_inventory.log", 
                "/opt/ManagedFrameworks/EA_History.log"
                ]

            # Setup databases that we want to collect info from
            db_kext = {}
            database_items = []
            db_kext["database"] = "/var/db/SystemPolicyConfiguration/KextPolicy"
            db_kext["tables"] = [ "kext_policy_mdm", "kext_policy" ]
            database_items.append(db_kext)

        if args.quiet:
            verbose = False
        else:
            verbose = True
    else:
        parser.print_help()
        sys.exit(0)

    ##################################################
    # Define Variables

    jamf_plist = "/Library/Preferences/com.jamfsoftware.jamf.plist"
    jps_api_user = (
        DecryptString(
            (args.api_username).strip(), 
            "<SALT>", 
            "<PASSPHRASE>"
        )).strip().decode()
    jps_api_password = (
        DecryptString(
            (args.api_password).strip(), 
            "<SALT>", 
            "<PASSPHRASE>")
        ).strip().decode()
    jps_credentials = (
        base64.b64encode(
            "{}:{}".format(jps_api_user, jps_api_password).encode() 
        )).decode()
    time_stamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    archive_file = "/private/tmp/{}_logs".format(time_stamp)
    archive_max_size = 40000000

    # Get the systems' Jamf Pro Server
    if os.path.exists(jamf_plist):
        jamf_plist_contents = plistReader(jamf_plist, verbose)
        jps_url = jamf_plist_contents["jss_url"]
        if verbose:
            print("Jamf Pro Server URL:  {}".format(jps_url))
    else:
        print("ERROR:  Missing the Jamf Pro configuration file!")
        sys.exit(1)

    # Get the system's UUID
    hw_UUID = get_system("uuid")
    if verbose:
        print("System UUID:  {}".format(hw_UUID))

    ##################################################
    # Bits staged...

    if verbose:
        print("Requested files:  {}".format(upload_items))
        if database_items:
            print("Requested databases:  {}".format(database_items))

    if args.directory:
        if os.path.exists(upload_items):
            parent_directory = os.path.abspath(os.path.join(upload_items, os.pardir))
            shutil.make_archive(archive_file, "zip", parent_directory, upload_items )
        else:
            print("ERROR:  Unable to locate the provided directory!")
            sys.exit(4)
    else:
        zip_file = zipfile.ZipFile("{}.zip".format(archive_file), "w")
        for upload_item in upload_items:
            if verbose:
                print("Archiving file:  {}".format(os.path.abspath(upload_item)))
            if os.path.exists(upload_item):
                zip_file.write(os.path.abspath(upload_item), compress_type=zipfile.ZIP_DEFLATED)
            else:
                print("WARNING:  Unable to locate the specified file!")
        for database_item in database_items:
            if os.path.exists(database_item["database"]):
                if verbose:
                    print(
                        "Archiving tables from database:  {}".format(
                            os.path.abspath(database_item["database"])))
                for table in database_item["tables"]:
                    if verbose:
                        print("Creating csv and archiving table:  {}".format(table))
                    file_name = dbTableWriter(database_item["database"], table)
                    zip_file.write(os.path.abspath(file_name), compress_type=zipfile.ZIP_DEFLATED)
            else:
                print("WARNING:  Unable to locate the specified file!")

        zip_file.close()

    archive_size = os.path.getsize("{}.zip".format(archive_file))
    if verbose:
        print("Archive name:  {}.zip".format(archive_file))
        print("Archive size:  {}".format(archive_size))

    if archive_size > archive_max_size:
        print("Aborting:  File size is larger than allowed!")
        sys.exit(2)

    # Query the API to get the computer ID
    status_code, json_data = apiGET(
        jps_url=jps_url, 
        jps_credentials=jps_credentials, 
        endpoint="/computers/udid/{uuid}".format(uuid=hw_UUID), 
        verbose=verbose
    )

    if int(status_code) == 200:
        computer_id = json_data.get("computer").get("general").get("id")
        if verbose:
            print("Computer ID:  {}".format(computer_id))
    else:
        print("ERROR:  Failed to retrieve devices\' computer ID!")
        sys.exit(5)

    # Upload file via the API
    status_code, content = apiPOST(
        jps_url=jps_url, 
        jps_credentials=jps_credentials, 
        endpoint="/fileuploads/computers/id/{id}".format(id=computer_id), 
        file_to_upload="{}.zip".format(archive_file), 
        archive_size=archive_size, 
        verbose=verbose
    )

    if int(status_code) == 204:
        if content:
            if verbose:
                print("Response:  {}".format(content))
        print("Upload complete!")
    else:
        print("ERROR:  Failed to upload file to the JPS!")
        sys.exit(6)


if __name__ == "__main__":
    main()
