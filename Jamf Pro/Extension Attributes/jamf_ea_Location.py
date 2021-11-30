#!/opt/ManagedFrameworks/Python.framework/Versions/Current/bin/python3

"""
###################################################################################################
# Script Name:  jamf_ea_Location.py
# By:  Zack Thompson / Created:  8/24/2019
# Version:  1.1.0 / Updated:  11/30/2021 / By:  ZT
#
# Description:  A Jamf Pro Extension Attribute to get the physical location of a device.
#
###################################################################################################
"""

import json
import requests
import subprocess


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


def webLookup(url):
    """A helper function that performs a GET to the provided url.  Attempts to first use the python urllib2 library, but if that fails, falls back to the system curl.
    Args:
        url:  a URL to query
    Returns:
        stdout:  json data from the response contents
    """

    try:
        print('Trying requests...')
        headers = {'Accept': 'application/json'}
        response = requests.get(url, headers=headers)
        statusCode = response.status_code
        json_response = response.json()

    except Exception:
        # If urllib fails, resort to using curl
        print('Trying curl...')
        # Build the command
        curl_cmd = '/usr/bin/curl --silent --show-error --no-buffer --fail --write-out "statusCode:%{{http_code}}" --location --header "Accept: application/json" --url {url} --request GET'.format(url=url)
        response = runUtility(curl_cmd)
        json_content, statusCode = response.split(b'statusCode:')
        json_response = json.loads(json_content)

    return statusCode, json_response


def main():

    # Query the API to get the computer ID
    status_code, json_data = webLookup(url='https://ipinfo.io')

    if int(status_code) == 200:
        # Get the attributes
        city = json_data.get('city')
        region = json_data.get('region')
        country = json_data.get('country')
        location = json_data.get('loc')

        print("<result>{city}, {region}, {country} @ {location}</result>".format(city=city, region=region, country=country, location=location))

    else:
        print("<result>Unable to determine location</result>")


if __name__ == "__main__":
    main()
