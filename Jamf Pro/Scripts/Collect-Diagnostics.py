#!/opt/ManagedFrameworks/Python.framework/Versions/Current/bin/python3

"""
Script Name:  Collect-Diagnostics.py
By:  Zack Thompson / Created:  8/22/2019
Version:  1.10.0 / Updated:  12/4/2023 By:  ZT

Description:  This script allows you to upload a compressed
	zip of specified files to a computers' inventory record.

"""

import argparse
import csv
import datetime
import json
import logging
import mimetypes
import os
import plistlib
import re
import shlex
import sqlite3
import subprocess
import sys
import zipfile

from typing import Union

import objc
import requests

from cryptography.fernet import Fernet
from Foundation import NSBundle, NSString


CLASSIC_API_ENDPOINTS = {
	"computers_by_udid": "JSSResource/computers/udid",
}

PRO_API_ENDPOINTS = {
	"auth_details": "api/v1/auth",
	"auth_token": "api/v1/auth/token",
	"computer_attachments": "api/v1/computers-inventory/{id}/attachments"
}


####################################################################################################
# Common Helper Functions


def log_setup(name):
	"""Setup logging"""

	# Create logger
	logger = logging.getLogger(name)
	logger.setLevel(logging.DEBUG)
	# Create file handler which logs even debug messages
	# file_handler = logging.FileHandler("/var/log/JamfPatcher.log")
	# file_handler.setLevel(logging.INFO)
	# Create console handler with a higher log level
	console_handler = logging.StreamHandler()
	console_handler.setLevel(logging.INFO)
	# Create formatter and add it to the handlers
	formatter = logging.Formatter(
		"%(asctime)s | %(levelname)s | %(name)s:%(lineno)s - %(funcName)20s() | %(message)s")
	# file_handler.setFormatter(formatter)
	console_handler.setFormatter(formatter)
	# Add the handlers to the logger
	# logger.addHandler(file_handler)
	logger.addHandler(console_handler)
	return logger


# Initialize logging
log = log_setup(name="CollectDiagnostics")


def decrypt_string(key, encrypted_string):
	"""
	A helper function to decrypt a string with a given secret key.

	Args:
		key:  Secret key used to decrypt the passed string.  (str)
		string:  String to decrypt. (str)
	Returns:
		The unencrypted string as a str.
	"""

	f = Fernet(key.encode())
	decrypted_string = f.decrypt(encrypted_string.encode())

	return decrypted_string.decode()


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


def db_table_writer(database, table):
	"""A helper function read the contents of a database table and write to a csv.

	Borrowed and modified from:  https://stackoverflow.com/a/36211470

	Args:
		database:  A database that can be opened with sqlite
		table:  A table in the database to select
	Returns:
		file:  Returns the abspath of the file.
	"""

	file_name = f"/private/tmp/{table}.csv"

	# Setup database connection
	db_connect = sqlite3.connect(database)
	database = db_connect.cursor()

	# Execute query
	database.execute(f"select * from {table}")

	# Write to file
	with open(file_name,"w") as table_csv:
		csv_out = csv.writer(table_csv)
		# Write header
		csv_out.writerow([description[0] for description in database.description])
		# Write data
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
		return IORegistryEntryCreateCFProperty(
			IOServiceGetMatchingService(0, service), key, None, 0)

	def get_hardware_uuid():
		return io_key("IOPlatformUUID")

	# def get_hardware_serial():
	# 	return io_key("IOPlatformSerialNumber")

	# def get_board_id():
	# 	try:
	# 		return bytes(io_key("board-id")).decode().rstrip("\x00")
	# 	except TypeError:
	# 		return ""

	# def get_model_id():
	# 	return bytes(io_key("model")).decode().rstrip("\x00")

	# def lookup_model(lookup_code):
	# 	xml = requests.get(f"https://support-sp.apple.com/sp/product?cc={lookup_code}").text

	# 	try:
	# 		tree = ElementTree.fromstringlist(xml)
	# 		return tree.find(".//configCode").text

	# 	except ElementTree.ParseError as err:
	# 		log.info(f"Failed to retrieve model name:  {err.strerror}")
	# 		return ""


	# serial_number = get_hardware_serial()
	# sn_length = len(serial_number)
	# model = ""

	# if sn_length == 10:
	# 	results = execute_process("/usr/sbin/ioreg -arc IOPlatformDevice -k product-name")

	# 	if results.get("success"):
	# 		plist_contents = plistlib.loads(results.get("stdout").encode())
	# 		model = plist_contents[0].get("product-name").decode().rstrip("\x00")

	# elif sn_length == 12:
	# 	model = lookup_model(serial_number[-4:])

	# elif sn_length == 11:
	# 	model = lookup_model(serial_number[-3:])

	return {
		# "serial_number": serial_number,
		"uuid": get_hardware_uuid(),
		# "board_id": get_board_id(),
		# "model_id": get_model_id(),
		# "model_friendly": model
	}


def archiver(path, archive, mode="a"):
	"""A Context Manager for creating or modifying a compressed archive.

	Args:
		path (str): Path to a file or directory to include in the archive
		archive (str): Path to the archive file; will be created if it does not exist
		mode (str, optional): The mode that will be used to open the archive. Defaults to "a".
	"""

	log.info(f"Archiving:  {os.path.abspath(path)}")

	if os.path.exists(path):

		with zipfile.ZipFile(archive, mode, zipfile.ZIP_DEFLATED) as zip_file:

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
		log.warning("Unable to locate the specified file!")


def write_to_file(file, data):
	"""A simple helper function to write data to a file.

	Args:
		file (str): Path to where the file should be written
		data (str): Contents that will be written to the file
	"""

	with open(file, "w") as file_object:
		file_object.write(data)


##################################################
# Jamf Pro Helper Functions

def jamf_pro_url():
	"""
	Helper function to return the Jamf Pro URL the device is enrolled with
	"""

	# Define Variables
	jamf_plist = "/Library/Preferences/com.jamfsoftware.jamf.plist"

	# Get the systems' Jamf Pro Server
	if os.path.exists(jamf_plist):

		with open(jamf_plist, "rb") as jamf_plist_file:
			jamf_plist_contents = plistlib.load(jamf_plist_file)

		jps_url = jamf_plist_contents.get("jss_url")
		log.debug(f"Jamf Pro Server URL:  {jps_url}")
		return jps_url

	else:
		log.error("Missing the Jamf Pro configuration file!")
		sys.exit(1)


JPS_URL = jamf_pro_url()


def jamf_pro_api(api_account: dict, method: str, endpoint: str,
	receive_content_type: str = "json", send_content_type = "xml",
	data: Union[str, dict, None] = None, **kwargs):
	"""Helper function to interact with the Jamf Pro API(s).

	Args:
		api_account (dict): Dict contain the username and password to use
			when interacting with the Jamf Pro API.
		method (str): HTTP Method that should be used.
		endpoint (str): The API's endpoint URL
		receive_content_type (str, optional): The content type to request the API to
			respond with. Defaults to "json".
		send_content_type (str, optional): The content type that will be sent to the API.
			Defaults to "xml".
		data (str | dict | None, optional): A data payload that will be sent to the API.
			Defaults to None.

	Returns:
		requests.response: A request.response object
	"""

	if not api_account.get("api_token"):
		api_account |= get_token(
			api_account.get("username"),
			api_account.get("password")
		)

	# Setup API URL and Headers
	url = f"{JPS_URL}{endpoint}"
	headers = {
		"Authorization": f"jamf-token {api_account.get('api_token')}",
		"Accept": f"application/{receive_content_type}",
		"Content-Type": f"application/{send_content_type}"
	}

	if kwargs.get("headers"):
		headers |= kwargs.get("headers")

	try:

		if method == "get":

			return requests.get(url=url, headers=headers)

		elif method in { "post", "create" }:

			if upload_file := kwargs.get("file"):

				content_type = mimetypes.guess_type(upload_file)[0]
				headers.pop("Content-Type")

				file = {
					"file": (
						upload_file,
						open(upload_file, "rb"),
						content_type
					)
				}

				return requests.post(
					url = url,
					headers = headers,
					files = file
				)


			return requests.post(
				url = url,
				headers = headers,
				data = data
			)

		elif method in { "put", "update" }:

			return requests.put(
				url = url,
				headers = headers,
				data = data
			)

		elif method == "delete":

			return requests.delete(
				url = url,
				headers = headers
			)

	except Exception:

		log.error("Failed to connect to the Jamf Pro Server.")


def get_token(username: str, password: str):
	"""A helper function use to obtain a Jamf Pro API Token.

	Args:
		username (str): Username for a Jamf Pro account
		password (str): Password for a Jamf Pro account

	Returns:
		dict: Results of the API Token request
	"""

	try:

		# Create a token based on user provided credentials
		response_get_token = requests.post(
			url = f"{JPS_URL}/{PRO_API_ENDPOINTS.get('auth_token')}",
			auth = (username, password)
		)

		if response_get_token.status_code == 200:
			return {
				"api_token": response_get_token.json().get("token"),
			}

		return { "error": "ERROR:  Failed to authenticate with the Jamf Pro Server." }

	except Exception:
		return { "error": "ERROR:  Failed to connect to the Jamf Pro Server." }


####################################################################################################
def main():
	# log.debug(f"All calling args:  {sys.argv}\n")

	parse_args = []

	for arg in sys.argv:

		if arg != "":

			if re.match(r'.*("|\').*', arg):
				parse_args.extend(shlex.split(arg))

			else:
				parse_args.append(arg)

	# log.debug(f"Parsed args:  {parse_args}\n")

	##################################################
	# Define Script Parameters

	parser = argparse.ArgumentParser(
		description="This script allows you to upload a compressed zip \
			of specified files to a computers' inventory record")
	parser.add_argument("--api-username", "-u",
		help="Provide the encrypted string for the API Username.", required=True)
	parser.add_argument("--api-password", "-p",
		help="Provide the encrypted string for the API Password.", required=True)
	parser.add_argument("--secret", "-s", help="Provide the encrypted secret.", required=True)
	parser.add_argument("--defaults", default=True,
		help="Collects the default files.", required=False)
	parser.add_argument("--name", "-n",
		help=("Provide a custom name to tag the resulting archive file with.  This can help to "
		"differentiate what each log file was intending to collect."), required=False)
	parser.add_argument("--maxsize", "-m", type=int, default=50000000, required=False,
		help="Provide a custom max size to override the archive's default 50MB max size.")
	parser.add_argument("--file", "-f", metavar="/path/to/file", type=str, nargs="*",
		help="Specify specific file path(s) to collect.  Multiple file paths can be passed.",
		required=False
	)
	parser.add_argument("--directory", "-d", metavar="/path/to/directory/", type=str, nargs="*",
		help="Specify a specific directory(ies) to collect.  Multiple directories can be passed.",
		required=False
	)
	parser.add_argument("--quiet", "-q", action="store_true",
		help="Do not print verbose/debugging messages.", required=False)

	args, _ = parser.parse_known_args(parse_args)
	log.info(f"Argparse args:  {args}")
	# sys.exit(0)

	if len(sys.argv) < 1:
		parser.print_help()
		sys.exit(0)

	# Set the desired log level
	for handler in log.handlers:
		if args.quiet:
			handler.setLevel(logging.INFO)
		else:
			handler.setLevel(logging.DEBUG)

	if args.name:
		custom_name_tag = re.sub(r'\s', '_', args.name)
		custom_name_tag = f"_{custom_name_tag}"
	else:
		custom_name_tag = ""

	archive_max_size = args.maxsize
	upload_items = []

	if args.file:
		upload_items.extend((file).strip() for file in args.file)

	if args.directory:
		upload_items.extend((folder).strip() for folder in args.directory)

	if args.defaults:
		upload_items.extend(
			[
				"/private/var/log/jamf.log",
				"/private/var/log/install.log",
				"/private/var/log/system.log",
				"/private/var/log/jamf_RecoveryAgent.log",
				"/private/var/log/jamf_ReliableEnrollment.log",
				"/private/var/log/32bitApps_inventory.log",
				"/opt/ManagedFrameworks/Inventory.plist",
				"/opt/ManagedFrameworks/EA_History.log",
				"/opt/ManagedFrameworks/pkg_install.log",
				"/private/tmp/installed_profiles.xml",
				"/private/tmp/apns_status.txt"
			]
		)

		db_kext = {
			"database": "/var/db/SystemPolicyConfiguration/KextPolicy",
			"tables": ["kext_policy_mdm", "kext_policy"],
		}
		database_items = [db_kext]

	##################################################
	# Define Variables

	jps_credentials = {
		"username": decrypt_string(args.secret.strip(), args.api_username.strip()).strip(),
		"password": decrypt_string(args.secret.strip(), args.api_password.strip()).strip()
	}

	time_stamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
	archive_file = f"/private/tmp/{time_stamp}{custom_name_tag}_logs.zip"

	# Get the system's UUID
	hw_UUID = get_system_info().get("uuid")
	log.debug(f"System UUID:  {hw_UUID}")

	##################################################
	# Bits staged...

	log.debug(f"Requested files:  {upload_items}")
	if database_items:
		log.debug(f"Requested databases:  {database_items}")

	# Get installed Configuration Profiles
	installed_profiles = execute_process('/usr/bin/profiles show -cached --output "stdout-xml"')

	if installed_profiles.get("success"):
		write_to_file("/private/tmp/installed_profiles.xml", installed_profiles.get("stdout"))
	else:
		log.warning("Failed to get locally installed profiles!")

	# Get APNS stats
	apns_stats = execute_process(
		'/System/Library/PrivateFrameworks/ApplePushService.framework/apsctl status'
	)

	if apns_stats.get("success"):
		write_to_file("/private/tmp/apns_status.txt", apns_stats.get("stdout"))
	else:
		log.warning("Failed to get APNS stats!")

	for upload_item in upload_items:
		archiver(upload_item, archive=archive_file)

	for database_item in database_items:

		if os.path.exists(database_item.get("database")):
			log.info(
				f"Archiving tables from database:  {os.path.abspath(database_item['database'])}")

			for table in database_item.get("tables"):
				log.info(f"Creating csv and archiving table:  {table}")
				file_name = db_table_writer(database_item.get("database"), table)
				archiver(os.path.abspath(file_name), archive=archive_file)

		else:
			log.warning("Unable to locate the specified database!")

	archive_size = os.path.getsize(archive_file)
	log.debug(f"Archive name:  {archive_file}")
	log.debug(f"Archive size:  {archive_size}")

	if archive_size > archive_max_size:
		log.error("Aborting:  File size is larger than allowed!")
		sys.exit(2)

	# Query the API to get the computer ID
	response_computer_details = jamf_pro_api(
		api_account = jps_credentials,
		method = "get",
		endpoint = f"{CLASSIC_API_ENDPOINTS.get('computers_by_udid')}/{hw_UUID}"
	)

	if int(response_computer_details.status_code) == 200:
		computer_id = response_computer_details.json().get("computer").get("general").get("id")
		log.debug(f"Computer ID:  {computer_id}")
	else:
		log.error("Failed to retrieve devices' computer ID!\n"
			f"API Status Code:  {response_computer_details.status_code}\n"
			f"API Response:  {response_computer_details.json()}"
		)
		sys.exit(5)

	# Upload file via the API
	response_upload_file = jamf_pro_api(
		api_account = jps_credentials,
		method = "post",
		endpoint = f"{PRO_API_ENDPOINTS.get('computer_attachments')}".format(id=computer_id),
		receive_content_type = "json",
		file = archive_file
	)

	if int(response_upload_file.status_code) == 201:
		if result := response_upload_file.content.decode():
			result = json.loads(result)
			log.debug(f"Uploaded file attachment id:  {result.get('id')}")
		log.info("Successfully upload the archive!")
	else:
		log.error("Failed to upload file to the JPS!\n"
			f"API Response:  {response_upload_file.content.decode()}"
		)
		sys.exit(6)


if __name__ == "__main__":
	main()
