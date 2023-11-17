#!/opt/ManagedFrameworks/Python.framework/Versions/Current/bin/python3

"""
Script Name:  Collect-Diagnostics.py
By:  Zack Thompson / Created:  8/22/2019
Version:  1.6.1 / Updated:  5/2/2022 By:  ZT

Description:  This script allows you to upload a compressed 
    zip of specified files to a computers' inventory record.

"""

import argparse
import base64
import csv
import datetime
import json
import os
import plistlib
import re
import shlex
import sqlite3
import subprocess
import sys
import zipfile

from Foundation import NSBundle, NSString
import objc
import requests


# Jamf Function to obfuscate credentials.
def DecryptString(inputString, salt, passphrase):
    """
    Usage: >>> DecryptString("Encrypted String", "Salt", "Passphrase")
    """

    return execute_process(
        "/usr/bin/openssl enc -aes256 -d -a -A -S '{salt}' -k '{passphrase}'".format(
            salt=salt, passphrase=passphrase), input=inputString)["stdout"]


def execute_process(command, input=None):
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
        raise TypeError("Command must be a str type")

    # Format the command
    command = shlex.split(command)

    # Run the command
    process = subprocess.Popen( 
        command, 
        stdin=subprocess.PIPE, 
        stdout=subprocess.PIPE, 
        stderr=subprocess.PIPE, 
        shell=False, 
        universal_newlines=True 
    )

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


def get_system_info():
    """
    A helper function to get specific system attributes.

    Credit:  Mikey Mike/Froger/Pudquick/etc
    Source:  https://gist.github.com/pudquick/c7dd1262bd81a32663f0
    Notes:  Modified from source

    Args:
        attribute:  The system attribute desired.

    Returns:
        stdout:  The system attribute value.
    """

    IOKit_bundle = NSBundle.bundleWithIdentifier_("com.apple.framework.IOKit")
    functions = [
        ("IORegistryEntryCreateCFProperty", b"@I@@I"), 
        ("IOServiceGetMatchingService", b"II@"), 
        ("IOServiceMatching", b"@*")
    ]
    objc.loadBundleFunctions(IOKit_bundle, globals(), functions)

    def io_key(key_name, service_name="IOPlatformExpertDevice"):
        service = IOServiceMatching(service_name.encode("utf-8"))
        key = NSString.stringWithString_(key_name)
        return IORegistryEntryCreateCFProperty(IOServiceGetMatchingService(0, service), key, None, 0)

    def get_hardware_uuid():
        return io_key("IOPlatformUUID")

    # def get_hardware_serial():
    #     return io_key("IOPlatformSerialNumber")

    # def get_board_id():
    #     try:
    #         return bytes(io_key("board-id")).decode().rstrip("\x00")
    #     except TypeError:
    #         return ""

    # def get_model_id():
    #     return bytes(io_key("model")).decode().rstrip("\x00")

    # def lookup_model(lookup_code):
    #     xml = requests.get("https://support-sp.apple.com/sp/product?cc={}".format(lookup_code)).text

    #     try:
    #         tree = ElementTree.fromstringlist(xml)
    #         return tree.find(".//configCode").text

    #     except ElementTree.ParseError as err:
    #         print("Failed to retrieve model name:  {}".format(err.strerror))
    #         return ""


    # serial_number = get_hardware_serial()
    # sn_length = len(serial_number)
    # model = ""

    # if sn_length == 10:
    #     results = execute_process("/usr/sbin/ioreg -arc IOPlatformDevice -k product-name")

    #     if results["success"]:
    #         plist_contents = plistlib.loads(results["stdout"].encode())
    #         model = plist_contents[0].get("product-name").decode().rstrip("\x00")

    # elif sn_length == 12:
    #     model = lookup_model(serial_number[-4:])

    # elif sn_length == 11:
    #     model = lookup_model(serial_number[-3:])

    return { 
        # "serial_number": serial_number,
        "uuid": get_hardware_uuid(),
        # "board_id": get_board_id(),
        # "model_id": get_model_id(),
        # "model_friendly": model
    }


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

    except Exception as error:
        print("Requests error:\n{}".format(error))
        # If `requests` fails, resort to using curl.

        if parameters.get("verbose"):
            print("Trying curl...")

        # Build the command.
        curl_cmd = "/usr/bin/curl --silent --show-error --no-buffer --fail --write-out \
            'statusCode:%{{http_code}}' --location --header 'Accept: application/json' \
            --header 'Authorization: Basic {jps_credentials}' --url {url} --request GET".format(
                jps_credentials=parameters.get("jps_credentials"), url=url)
        response = execute_process(curl_cmd)['stdout']
        json_content, statusCode = response.split("statusCode:")
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

    response = execute_process(curl_cmd)['stdout']
    content, statusCode = response.split("statusCode:")

    return statusCode, content


def archiver(path, archive, mode="a", verbose=True):
    """A Context Manager for creating or modifying a compressed archive.

    Args:
        path (str): Path to a file or directory to include in the archive
        archive (str): Path to the archive file; will be created if it does not exist
        mode (str, optional): The mode that will be used to open the archive. Defaults to "a".
        verbose (bool, optional): Print verbose messages. Defaults to True.
    """

    if verbose:
        print("Archiving:  {}".format(os.path.abspath(path)))

    if os.path.exists(path):

        with zipfile.ZipFile(archive, 'a', zipfile.ZIP_DEFLATED) as zip_file:

            if os.path.isdir(path):

                for root, dirs, files in os.walk(path):

                    for file in files:

                        zip_file.write(
                            os.path.join(root, file), 
                            os.path.relpath(
                                os.path.join(root, file), 
                                os.path.join(path, '..')
                            )
                        )

            else:

                zip_file.write(os.path.abspath(path), compress_type=zipfile.ZIP_DEFLATED)

    else:
        print("WARNING:  Unable to locate the specified file!")


def main():
    # print("All calling args:  {}\n".format(sys.argv))

    parse_args = []

    for arg in sys.argv:

        if arg != "":

            if re.match(r'.*("|\').*', arg):
                parse_args.extend(shlex.split(arg))

            else:
                parse_args.append(arg)

    # print("Parsed args:  {}\n".format(parse_args))

    ##################################################
    # Define Script Parameters

    parser = argparse.ArgumentParser(
        description="This script allows you to upload a compressed zip \
            of specified files to a computers' inventory record")
    parser.add_argument("--api-username", "-u", 
        help="Provide the encrypted string for the API Username", required=True)
    parser.add_argument("--api-password", "-p", 
        help="Provide the encrypted string for the API Password", required=True)
    parser.add_argument("--defaults", default=True, 
        help="Collects the default files.", required=False)
    parser.add_argument("--file", "-f", metavar="/path/to/file", type=str, nargs="*",
        help="Specify specific file path(s) to collect.  Multiple file paths can be passed.",
        required=False
    )
    parser.add_argument("--directory", "-d", metavar="/path/to/directory/", type=str, nargs="*", 
        help="Specify a specific directory(ies) to collect.  Multiple directories can be passed.", 
        required=False
    )
    parser.add_argument("--quiet", "-q", action="store_true", 
        help="Do not print verbose messages.", required=False)

    args = parser.parse_known_args(args=parse_args)
    args = args[0]

    print("Argparse args:  {}".format(args))
    # sys.exit(0)

    if len(sys.argv) > 1:
        upload_items = []

        if args.file:
            for file in args.file:
                upload_items.append((file).strip())

        if args.directory:
            for folder in args.directory:
                upload_items.append((folder).strip())

        if args.defaults:
            upload_items.extend(
                [
                    "/private/var/log/jamf.log", 
                    "/private/var/log/install.log", 
                    "/private/var/log/system.log", 
                    "/private/var/log/jamf_RecoveryAgent.log", 
                    "/private/var/log/jamf_ReliableEnrollment.log", 
                    "/private/var/log/32bitApps_inventory.log", 
                    "/opt/ManagedFrameworks/EA_History.log"
                ]
            )

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
        )
    ).strip()
    jps_api_password = (
        DecryptString(
            (args.api_password).strip(), 
            "<SALT>", 
            "<PASSPHRASE>"
        )
    ).strip()
    jps_credentials = (
        base64.b64encode(
            "{}:{}".format(jps_api_user, jps_api_password).encode() 
        )).decode()
    time_stamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    archive_file = "/private/tmp/{}_logs.zip".format(time_stamp)
    archive_max_size = 50000000 # 50MB

    # Get the systems' Jamf Pro Server
    if os.path.exists(jamf_plist):
        with open(jamf_plist, "rb") as plist:
            jamf_plist_contents = plistlib.load(plist)

        jps_url = jamf_plist_contents["jss_url"]

        if verbose:
            print("Jamf Pro Server URL:  {}".format(jps_url))
    else:
        print("ERROR:  Missing the Jamf Pro configuration file!")
        sys.exit(1)

    # Get the system's UUID
    hw_UUID = get_system_info().get("uuid")
    if verbose:
        print("System UUID:  {}".format(hw_UUID))

    ##################################################
    # Bits staged...

    if verbose:
        print("Requested files:  {}".format(upload_items))
        if database_items:
            print("Requested databases:  {}".format(database_items))

    for upload_item in upload_items:
        archiver(upload_item, archive=archive_file, verbose=verbose)

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

                archiver(os.path.abspath(file_name), archive=archive_file, verbose=verbose)
        else:
            print("WARNING:  Unable to locate the specified database!")

    archive_size = os.path.getsize(archive_file)

    if verbose:
        print("Archive name:  {}".format(archive_file))
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
        file_to_upload=archive_file, 
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
