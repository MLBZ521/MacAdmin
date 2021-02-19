#!/usr/bin/python
"""
###################################################################################################
# Script Name:  Apple_RepairPrograms.py
# By:  Zack Thompson / Created:  8/24/2019
# Version:  1.1.0 / Updated:  2/12/2021 / By:  ZT
#
# Description:  This script looks up provided devices and checks if they're eligible for a recall program.
#
#   Exchange and Repair Extension Programs:  https://support.apple.com/exchange_repair
#
# Inspired by the following thread on Jamf Nation:  https://www.jamf.com/jamf-nation/discussions/32400/battery-recall-for-15-mid-2015-mbp
#   And the various forked scripts shared by:
#       Nick Tong (https://www.jamf.com/jamf-nation/discussions/32400/battery-recall-for-15-mid-2015-mbp#responseChild186454)
#       Neil Martin (https://soundmacguy.wordpress.com/2019/06/21/2015-macbook-pro-battery-recall-checker-script/)
#       William McGrath (https://gist.github.com/nzmacgeek/ef453c8e96a67ee12d973e4c0594e286)
#       jsherwood (https://www.jamf.com/jamf-nation/discussions/32400/battery-recall-for-15-mid-2015-mbp#responseChild186536)
#
###################################################################################################
"""

import argparse
import csv
import json
import os
import re
import subprocess
import sys
import time
import uuid

try:
    from urllib import request as urllib  # For Python 3
except ImportError:
    import urllib2 as urllib # For Python 2


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


# This function performs the lookup for each serial number against Apple's API
def exchange_lookup(program, serial, guid):

    data = {"serial": serial, "GUID": guid}
    url = "https://qualityprograms.apple.com/snlookup/{program}".format(program=program)

    try:
        # print('Trying urllib...')
        headers = {'Accept': 'application/json'}
        request = urllib.Request(url, data=json.dumps(data), headers=headers)
        response = urllib.urlopen(request)
        statusCode = response.code
        json_response = json.loads(response.read())

    except Exception:
        # If urllib fails, resort to using curl
        sys.exc_clear()
        # print('Trying curl...')
        # Build the command
        curl_cmd = '/usr/bin/curl --silent --show-error --no-buffer --fail --write-out "statusCode:%{{http_code}}" --location --header "Accept: application/json" --data "{data}" --url {url} --request GET'.format(data=data, url=url)
        response = runUtility(curl_cmd)
        json_content, statusCode = response.split('statusCode:')
        json_response = json.loads(json_content)

    return 200, 'json_response'


# This function checks if the model has an available exchange program
def available_exchange_programs(model):
    program_number = []

    mbp15Battery = re.compile("(?:MacBook Pro \(Retina, 15-inch, Mid 2015\))|(?:15-inch Retina MacBook Pro \(Mid 2015\))|(?:MacBookPro11,4)|(?:MacBookPro11,5)")
    if mbp15Battery.search(str(model)):
        # 15-inch MacBook Pro Battery Recall Program
        # https://support.apple.com/15-inch-macbook-pro-battery-recall
        program_number.append("062019")

    mbp13SSD = re.compile("(?:MacBook Pro \(13-inch, 2017, Two Thunderbolt 3 ports\))|(?:13-inch Retina MacBook Pro \(Mid 2017\))|(?:MacBookPro11,4)|(?:MacBookPro14,1)")
    if mbp13SSD.search(str(model)):
        # 13-inch MacBook Pro (non Touch Bar) Solid-State Drive Service Program
        # https://support.apple.com/13-inch-macbook-pro-solid-state-drive-service
        program_number.append("112018")

    mbp13Battery = re.compile("(?:13-inch MacBook Pro \(non Touch Bar\))|(?:13-inch Retina MacBook Pro \(Late 2016\))|(?:13-inch Retina MacBook Pro \(Mid 2017\))|(?:MacBookPro13,1)|(?:MacBookPro14,1)")
    if mbp13Battery.search(str(model)):
        # 13-inch MacBook Pro (non Touch Bar) Battery Replacement Program
        # https://support.apple.com/13inch-macbookpro-battery-replacement
        program_number.append("032018")

    if model == "iPhone 11":
        # iPhone 11 Display Module Replacement Program for Touch Issues
        # https://support.apple.com/iphone-11-display-module-replacement-program
        program_number.append("122020")

    if model == "iPhone 8":
        # iPhone 8 Logic Board Replacement Program
        # https://support.apple.com/iphone-8-logic-board-replacement-program
        program_number.append("082018")

    if model == "iPhone 6S" or model == "iPhone 6 Plus":
        # iPhone 6s and iPhone 6s Plus Service Program for No Power Issues
        # https://support.apple.com/iphone-6s-6s-plus-no-power-issues-program
        program_number.append("102019")

# Discontinued programs

    # if model == "iPhone 6S":
    #     # iPhone 6s Program for Unexpected Shutdown Issues
    #     # https://support.apple.com/iphone6s-unexpectedshutdown
    #     program_number.append("112016")

    # if model == "iPhone 6 Plus":
    #     # iSight Camera Replacement Program for iPhone 6 Plus
    #     # https://support.apple.com/iphone6plus-isightcamera
    #     program_number.append("082015")

    return program_number


# This function takes a serial number and it's model, checks for available exchange programs and the loops through each program ID to check if it's eligible
def loop(model, serial):
    results = []

    # Check if model has available exchange program
    programs = available_exchange_programs(model)

    # If available program(s) is found, loop through each
    if programs:
        for program in programs:

            # Query Apple's API to see if device is eligible
            status_code, json_data = exchange_lookup(program, serial, str(uuid.uuid1()))

            # Verify the status code was successful
            if int(status_code) == 200:
                # Get the attributes
                status = json_data["status"]

                # Check if the device is eligible -- if not, move on without track this
                if status == "E00":
                    print("{} is eligible for program:  {}".format(serial, program))
                    results.append(program)

            # Sleep so we don't DDoS Apple!
            time.sleep(10)

    return results


def main():

    ##################################################
    # Define Script Parameters

    parser = argparse.ArgumentParser(description="Apple Exchange and Repair Extension Programs Lookup")
    single_run = parser.add_argument_group('Single Device')
    batch_run = parser.add_argument_group('Batch Process')

    single_run.add_argument('--serialnumber', '-s', metavar='C02LA1K9G7DM', type=str, help='A single serial number', required=False)
    single_run.add_argument('--model', '-m', metavar='MacBookPro11,4', type=str, help='A model or model identifier. \
    Example:  MacBook Pro (Retina, 15-inch, Mid 2015) or 15-inch Retina MacBook Pro (Mid 2015) or MacBookPro11,4', required=False)
    batch_run.add_argument('--input', '-i', metavar='/path/to/input_file.csv', type=str, help='Path to a CSV with a list of serial numbers, and models or model identifiers. \
    Example:  MacBook Pro (Retina, 15-inch, Mid 2015) or 15-inch Retina MacBook Pro (Mid 2015) or MacBookPro11,4', required=False)
    batch_run.add_argument('--output', '-o', metavar='/path/to/output_file.csv', type=str, help='Path to a CSV where devices that are eligible for a repair will be written. \
    WARNING:  If the files exists, it will be overwritten!', required=False)
    # parser.add_argument('--quiet', '-q', action='store_true', help='Do not print verbose messages.', required=False)

    args = parser.parse_args()
    # args = parser.parse_known_args()
    # args = args[0]

    # print('Argparse args:  {}'.format(args))

    ##################################################
    # Bits Staged

    if len(sys.argv) == 0:
        parser.print_help()
        sys.exit(0)
    else:
        if ( args.input or args.output ) and ( args.serialnumber or args.model ):
            parser.print_help()
            parser.exit(status=1, message='\nError:  Unable to mix arguments between parameter groups.\n')

        # if args.quiet:
        #     verbose = False
        # else:
        #     verbose = True

        # If working with a csv...
        if args.input and args.output:
            input_file = args.input
            output_file = args.output
            eligible_devices = []
            serial_fieldname = None
            model_fieldname = None

            if os.path.exists(input_file):
                # Open the provided CSV file
                with open(input_file, 'r') as csv_in:
                    csv_reader = csv.DictReader(csv_in, delimiter=',')

                    # Get the field names so we can parse these for the fields we need as well as use for writing back out later
                    field_names = csv_reader.fieldnames

                    # Common, expected patterns that a column header by look like for what is needed
                    patternSerial = re.compile("[Ss]erial([\s_])?([Nn]umber)?")
                    patternModel = re.compile("[Mm]odel([\s_])?([Ii]dentifier)?")

                    # For each field name, check if one matches
                    for field_name in field_names:
                        if patternSerial.search(field_name):
                            serial_fieldname = field_name
                        if patternModel.search(field_name):
                            model_fieldname = field_name

                    # Verify the column values were found
                    if serial_fieldname == None or model_fieldname == None:
                        print("Aborting:  Unable to correlate the header columns in the CSV file to expected values.")
                        sys.exit(3)

                    # Loop through each row in the CSV file
                    for row in csv_reader:

                        # Pass each row attributes to the loop function
                        results = loop(model=row[model_fieldname], serial=row[serial_fieldname])

                        # Verify a result was found, if so, add it to a tracking list
                        if len(results) != 0:
                            row.update({'Eligible Programs': str(results).strip('[]\'')})
                            eligible_devices.append(row)

                        # if len(eligible_devices) == 2:
                        #     break

                    # Check if any devices were eligible before doing anything else
                    if len(eligible_devices) > 0:

                        # Write to the CSV specified, if it exists, it will be overwritten
                        with open(output_file, mode='w') as csv_out:

                            # Build our new header...
                            header_line = field_names
                            header_line.append("Eligible Programs")
                            writer = csv.DictWriter(csv_out, fieldnames=header_line)
                            writer.writeheader()

                            for device in eligible_devices:
                                writer.writerow(device)
                    else:
                        print('None of the devices provided were eligible for a recall program.')
                        sys.exit(0)
                        
        elif args.serialnumber and args.model:
            # A single serial number and model were provided
            input_serialnumber = args.serialnumber
            input_model = args.model

            # Pass attributes to the loop function
            loop(model=input_model, serial=input_serialnumber)

        else:
            parser.print_help()
            parser.exit(status=1, message='\nError:  Not enough arguments provided.\n')


if __name__ == "__main__":
    main()
