#!/opt/ManagedFrameworks/Python.framework/Versions/Current/bin/python3

####################################################################################################
# Script Name:  jamf_Patcher.py
# By:  Zack Thompson / Created:  7/10/2019
# Version:  1.3.1 / Updated:  9/20/2023 / By:  ZT
#
# Description:  This script handles patching of applications with user notifications.
#
####################################################################################################

import logging
import os
import platform
import plistlib
import re
import shlex
import signal
import subprocess
import sys

try:
	import requests # Use requests if available
except ImportError:
	from urllib import request as urllib  # For Python 3


def log_setup():
	"""Setup logging"""

	# Create logger
	logger = logging.getLogger("Jamf Pro Patcher")
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
log = log_setup()


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


def plist_reader(plist_file_path):
	"""A helper function to get the contents of a Property List file.

	Args:
		plist_file_path (str):  A .plist file path to read in.
	Returns:
		stdout:  Returns the contents of the plist file.
	"""

	if os.path.exists(plist_file_path):
		log.debug(f"Reading {plist_file_path}...")

		with open(plist_file_path, "rb") as plist_file:

			try:
				plist_contents = plistlib.load(plist_file)
			except Exception:
				file_cmd = f"/usr/bin/file --mime-encoding {plist_file}"
				file_response = execute_process(file_cmd).get("stdout")
				file_type = file_response.split(": ")[1].strip()
				log.debug(f"File Type:  {file_type}")

				if file_type == "binary":
					log.debug("Converting plist...")
					plutil_cmd = f"/usr/bin/plutil -convert xml1 {plist_file}"
					_ = execute_process(plutil_cmd)

				plist_contents = plistlib.load(plist_file)
	else:
		log.warning("Something's terribly wrong here...")

	return plist_contents


def plist_writer(contents, plist_file_path):
	"""A helper function to write the contents of a Property List file.

	Args:
		contents (str):  The content to write to a plist file.
		plist_file_path (str):  A .plist file path to read in.
	"""

	with open(plist_file_path, "wb") as plist_file:
		plistlib.dump(contents, plist_file)


def prompt_to_patch(**parameters):
	"""Uses Jamf Helper to prompt a user to patch a software title,
	optionally allowing them to delay the patch.

	Args:
		parameters (kwargs):  Key word arguments
	"""

	# Prompt user to quit app.
	prompt = (
		f"'{parameters.get('jamf_helper')}' "
		f"-windowType '{parameters.get('window_type')}' "
		f"-title '{parameters.get('title')}' "
		f"-icon '{parameters.get('icon')}' "
		f"-iconSize '{parameters.get('icon_size')}' "
		f"-heading '{parameters.get('heading')}' "
		f"-description '{parameters.get('description')}' "
		"-button1 OK "
		"-timeout 3600 "
		"-countdown "
		"-countdownPrompt 'If you wish to delay this patch, please make a selection in ' "
		"-alignCountdown center "
		"-lockHUD "
		"-showDelayOptions ', 600, 3600, 86400' "
	)

	selection = execute_process(prompt).get("stdout")
	log.debug(f"User delay selection:  {selection}")

	if selection == "1":
		log.info("User selected to patch now.")
		kill_and_install(**parameters)

	elif selection[:-1] == "600":
		log.info("DELAY:  600 seconds")
		create_delay_daemon(delayTime=600, **parameters)

	elif selection[:-1] == "3600":
		log.info("DELAY:  3600 seconds")
		create_delay_daemon(delayTime=3600, **parameters)

	elif selection[:-1] == "86400":
		log.info("DELAY:  86400 seconds")
		create_delay_daemon(delayTime=86400, **parameters)

	elif selection == "243":
		log.info("TIMED OUT:  user did not make a selection")
		kill_and_install(**parameters)

	else:
		log.info("Unknown action was taken at prompt.")
		kill_and_install(**parameters)


def kill_and_install(**parameters):
	"""Kills the application by PID, if running and then executes
	the Jamf Pro Policy to update the application.

	Args:
		parameters (kwargs):  Key word arguments
	"""

	try:
		log.info("Attempting to close app if it's running...")
		# Kill PID
		os.kill(parameters.get("pid"), signal.SIGTERM) #or signal.SIGKILL
	except Exception:
		log.info("Unable to terminate app, assuming it was manually closed...")

	log.info("Performing install...")

	# Run Policy
	if not parameters.get("testing"):
		execute_process(parameters.get("install_policy"))

	prompt = (
		f"'{parameters.get('jamf_helper')}' "
		f"-windowType '{parameters.get('window_type')}' "
		f"-title '{parameters.get('title')}' "
		f"-icon '{parameters.get('icon')}' "
		f"-iconSize '{parameters.get('icon_size')}' "
		f"-heading '{parameters.get('heading')}' "
		f"-description '{parameters.get('description_complete')}' "
		"-button1 OK "
		"-timeout 60 "
		"-alignCountdown center "
		"-lockHUD "
	)

	execute_process(prompt)


def create_delay_daemon(**parameters):
	"""Creates a LaunchDaemon based on the user selected delay time
	which will the call a "Delayed Patch" Policy in Jamf Pro.

	Args:
		parameters (kwargs):  Key word arguments
	"""

	application_name = parameters.get("application_name")
	launch_daemon_label = parameters.get('launch_daemon_label')
	launch_daemon_location = parameters.get("launch_daemon_location")
	os_version = parameters.get("os_version")
	patch_plist = parameters.get("patch_plist")

	# Configure for delay.
	if os.path.exists(patch_plist):
		patch_plist_contents = plist_reader(patch_plist)
		patch_plist_contents.update( { application_name : "Delayed" } )
	else:
		patch_plist_contents = { application_name : "Delayed" }

	plist_writer(patch_plist_contents, patch_plist)

	log.info("Creating the Patcher LaunchDaemon...")

	launch_daemon_plist = {
		"Label": launch_daemon_label,
		"ProgramArguments": [
			"/usr/local/jamf/bin/jamf",
			"policy",
			"-id",
			f"{parameters.get('patch_id')}",
		],
		"StartInterval": parameters.get("delayTime"),
		"AbandonProcessGroup": True,
	}

	plist_writer(launch_daemon_plist, launch_daemon_location)

	if os.path.exists(launch_daemon_location):
		start_daemon(os_version, launch_daemon_label, launch_daemon_location)


def clean_up(**parameters):
	"""Cleans up a configured delay for the application
	and stops and deletes the delay LaunchDaemon.

	Args:
		parameters (kwargs):  Key word arguments
	"""

	log.info("Performing cleanup...")

	application_name = parameters.get("application_name")
	launch_daemon_label = parameters.get('launch_daemon_label')
	launch_daemon_location = parameters.get("launch_daemon_location")
	os_version = parameters.get("os_version")
	patch_plist = parameters.get("patch_plist")

	# Clean up patch_plist.
	if os.path.exists(patch_plist):
		patch_plist_contents = plist_reader(patch_plist)

		if patch_plist_contents.get(application_name):
			patch_plist_contents.pop(application_name, None)
			log.info(f"Removing previously delayed app:  {application_name}")
			plist_writer(patch_plist_contents, patch_plist)
		else:
			log.info(f"App not listed in patch_plist:  {application_name}")

	# Stop LaunchDaemon before deleting it
	stop_daemon(os_version, launch_daemon_label, launch_daemon_location)

	if os.path.exists(launch_daemon_location):
		os.remove(launch_daemon_location)


def execute_launchctl(sub_cmd, service_target):
	"""A helper function to run launchctl.

	Args:
		sub_cmd (str): A launchctl subcommand (option)
		service_target (str): A launchctl service target (parameter)

	Returns:
		bool | str: Depending on `exit_code_only`, returns either a bool or
			the output from launchctl
	"""

	return execute_process(f"/bin/launchctl {sub_cmd} {service_target}")


def is_daemon_running(os_version, launch_daemon_label):
	"""Checks if the daemon is running.

	Args:
		os_version (int): Used to determines the proper launchctl
			syntax based on OS Version of the device
		launch_daemon_label (str): The LaunchDaemon's Label

	Returns:
		bool: True or False whether or not the LaunchDaemon is running
	"""

	if os_version >= 10.11:
		exit_code = execute_launchctl("print", f"system/'{launch_daemon_label}'").get("exitcode")

	elif os_version <= 10.10:
		exit_code = execute_launchctl("list", f"'{launch_daemon_label}'").get("exitcode")

	return exit_code == 0


def start_daemon(os_version, launch_daemon_label, launch_daemon_location):
	"""Starts a daemon, if it is running, it will be restarted in
	case a change was made to the plist file.

	Args:
		os_version (int): Used to determines the proper launchctl
			syntax based on OS Version of the device
		launch_daemon_label (str): The LaunchDaemon's Label
		launch_daemon_location (str): The file patch to the LaunchDaemon
	"""

	if is_daemon_running(os_version, launch_daemon_label):
		restart_daemon(os_version, launch_daemon_label, launch_daemon_location)
		start_daemon(os_version, launch_daemon_label, launch_daemon_location)

	else:
		log.info("Loading LaunchDaemon...")

		if os_version >= 10.11:
			execute_launchctl("bootstrap", f"system '{launch_daemon_location}'")
			execute_launchctl("enable", f"system/'{launch_daemon_label}'")

		elif os_version <= 10.10:
			execute_launchctl("load", launch_daemon_location)


def restart_daemon(os_version, launch_daemon_label, launch_daemon_location):
	"""Restarts a daemon if it is running.

	Args:
		os_version (int): Used to determines the proper launchctl
			syntax based on OS Version of the device
		launch_daemon_label (str): The LaunchDaemon's Label
		launch_daemon_location (str): The file patch to the LaunchDaemon
	"""

	if is_daemon_running(os_version, launch_daemon_label):
		log.info("LaunchDaemon is currently started; stopping now...")
		stop_daemon(os_version, launch_daemon_label, launch_daemon_location)


def stop_daemon(os_version, launch_daemon_label, launch_daemon_location):
	"""Stops a daemon.

	Args:
		os_version (int): Used to determines the proper launchctl
			syntax based on OS Version of the device
		launch_daemon_label (str): The LaunchDaemon's Label
		launch_daemon_location (str): The file patch to the LaunchDaemon
	"""

	if is_daemon_running(os_version, launch_daemon_label):
		log.info("Stopping the LaunchDaemon...")

		if os_version >= 10.11:
			execute_launchctl("bootout", f"system/'{launch_daemon_label}'")
		elif os_version <= 10.10:
			execute_launchctl("unload", f"'{launch_daemon_location}'")

	else:
		log.info("LaunchDaemon not running")


def get_major_minor_os_version():

	os_version = platform.mac_ver()[0]

	if os_version.count('.') > 1:
		os_version = os_version.rsplit('.', maxsplit=1)[0]

	return float(os_version)


def value_to_bool(value):
	"""Checks if the the value is true or false.

	Args:
		value (str):  The value that will be checked for true/false

	Returns:
		True or false based on the value
	"""

	if re.match(r"^[Yy]([Ee][Ss])?|[Tt]([Rr][Uu][Ee])?$", value):
		return True
	elif re.match(r"^[Nn]([Oo])?|[Ff]([Aa][Ll][Ss][Ee])?$", value):
		return False
	else:
		log.warning(f"An invalid value was passed for the testing parameter:  {value}")


def main():
	log.info("*****  jamf_Patcher process:  START  *****")

	##################################################
	# Define Script Parameters
	log.info(f"All args:  {sys.argv}")
	department_name = sys.argv[4] # "<Organization's> Technology Office"
	application_name = sys.argv[5] # "zoom.us"
	icon_id = sys.argv[6] # "https://jps.server.com:8443/icon?id=49167"
	patch_id = sys.argv[7]
	policy_id = sys.argv[8]
	log_level = sys.argv[9]
	testing = sys.argv[10]

	if testing:
		testing = value_to_bool(testing)

	if log_level:
		for handler in log.handlers:
			match log_level:
				case "DEBUG":
					handler.setLevel(logging.DEBUG)
				case "INFO":
					handler.setLevel(logging.INFO)

	##################################################
	# Define Variables
	jamf_pro_server = plist_reader("/Library/Preferences/com.jamfsoftware.jamf.plist")["jss_url"]
	patch_plist = "/Library/Preferences/com.github.mlbz521.jamf.patcher.plist"
	jamf_helper = "/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
	launch_daemon_label = f"com.github.mlbz521.jamf.patcher.{application_name}"
	launch_daemon_location = f"/Library/LaunchDaemons/{launch_daemon_label}.plist"
	os_version = get_major_minor_os_version()
	install_policy = f"/usr/local/jamf/bin/jamf policy -id {policy_id}"

	##################################################
	# Define jamfHelper window values
	title="Security Patch Notification"
	window_type="utility"
	heading = "My Organization"
	description = (f"{application_name} needs to be updated to patch a security vulnerability.  "
		f"Please quit {application_name} to apply this update.\n\nIf you have questions, "
		"please contact your deskside support group.")
	description_force = (f"{application_name} will be updated to patch a security vulnerability.  "
		f"Please quit {application_name} within the allotted time to apply this update.\n\n"
		"If you have questions, please contact your deskside support group.")
	description_complete = f"{application_name} has been patched!\n\n."
	local_icon_path = f"/private/tmp/{application_name}_icon.png"
	icon_size = "150"

	if department_name:
		heading = f"{heading} - {department_name}"

	##################################################
	# Bits staged...

	parameters = {
		"application_name": application_name,
		"patch_plist": patch_plist,
		"launch_daemon_label": launch_daemon_label,
		"launch_daemon_location": launch_daemon_location,
		"os_version": os_version,
		"patch_id": patch_id,
		"install_policy": install_policy,
		"testing": testing
	}

	jamf_helper_parameters = {
		"jamf_helper": jamf_helper,
		"window_type": window_type,
		"title": title,
		"heading": heading,
		"description": description,
		"description_complete": description_complete,
		"icon": local_icon_path,
		"icon_size": icon_size
	}

	# Check if application is running.
	process_check = "/bin/ps -ax -o pid,command"
	results = execute_process(process_check)

	app_running = re.findall(
		rf".*/Applications/{application_name}.*", results.get("stdout"), re.MULTILINE)
	log.debug(f"Application status:  {app_running}")

	if not app_running:
		log.info(f"{application_name} is not running, installing now...")

		if not testing:
			execute_process(install_policy)

		clean_up(**parameters)

	else:
		log.info(f"{application_name} is running...")

		# Get PID of the application
		for value in app_running[0].split(" "):
			if pid := re.match(r"(\d)+", value):
				log.debug(f"Process ID:  {pid[0]}")
				parameters |= {"pid": int(pid[0])}
				break

		# Download the icon from the JPS
		icon_url = f"{jamf_pro_server}api/v1/icon/download/{icon_id}"

		try:
			downloaded_icon = requests.get(icon_url)
			open(local_icon_path, "wb").write(downloaded_icon.content)
		except Exception:
			sys.exc_clear()
			urllib.urlretrieve(icon_url, filename=local_icon_path)

		if (
			os.path.exists(patch_plist) and
			# Delay Check
			(patch_plist_contents := plist_reader(patch_plist).get(application_name))
		):

			log.info("Patch has already been delayed; forcing upgrade...")

			# Prompt user with one last warning.
			prompt = (
				f"'{jamf_helper}' "
				f"-windowType '{window_type}' "
				f"-title '{title}' "
				f"-icon '{local_icon_path}' "
				f"-iconSize '{icon_size}' "
				f"-heading '{heading}' "
				f"-description '{description_force}' "
				"-button1 OK "
				"-timeout 600 "
				"-countdown "
				f"-countdownPrompt '{application_name} will be force closed in ' "
				"-alignCountdown center "
				"-lockHUD "
				"> /dev/null 2>&1"
			)

			execute_process(prompt)
			kill_and_install(**parameters, **jamf_helper_parameters)
			clean_up(patch_plist_contents=patch_plist_contents, **parameters)

		else:
			log.info("Patch has not been delayed; prompting user...")
			prompt_to_patch(**parameters, **jamf_helper_parameters)

	log.info("*****  jamf_Patcher process:  SUCCESS  *****")

if __name__ == "__main__":
	main()
