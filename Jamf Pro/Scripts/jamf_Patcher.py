#!/opt/ManagedFrameworks/Python.framework/Versions/Current/bin/python3

###################################################################################################
# Script Name:  jamf_Patcher.py
# By:  Zack Thompson / Created:  7/10/2019
# Version:  1.0.1 / Updated:  10/22/2021 / By:  ZT
#
# Description:  This script handles patching of applications with user notifications.
#
###################################################################################################

import os
import platform
import plistlib
import signal
import subprocess
import sys

try:
    import requests # Use requests if available
except ImportError:
    from urllib import request as urllib  # For Python 3

def runUtility(command,  errorAction='continue'):
    """A helper function for subprocess.
    Args:
        command:  String containing the commands and arguments that will be passed to a shell.
    Returns:
        stdout:  output of the command
    """
    if errorAction == 'continue':
        try:
            process = subprocess.check_output(command, shell=True)
        except:
            process = "continue"
    else:
        try:
            process = subprocess.check_output(command, shell=True)
        except subprocess.CalledProcessError as error:
            print ('Error code:  {}'.format(error.returncode))
            print ('Error:  {}'.format(error))
            process = "error"

    return process

def plistReader(plistFile):
    """A helper function to get the contents of a Property List.
    Args:
        plistFile:  A .plist file to read in.
    Returns:
        stdout:  Returns the contents of the plist file.
    """

    if os.path.exists(plistFile):
        # print('Reading {}...'.format(plistFile))

        try:
            plist_Contents = plistlib.load(plistFile)
        except Exception:
            file_cmd = '/usr/bin/file --mime-encoding {}'.format(plistFile)
            file_response = runUtility(file_cmd)
            file_type = file_response.split(': ')[1].strip()
            # print('File Type:  {}'.format(file_type))

            if file_type == 'binary':
                # print('Converting plist...')
                plutil_cmd = '/usr/bin/plutil -convert xml1 {}'.format(plistFile)
                plutil_response = runUtility(plutil_cmd)

            plist_Contents = plistlib.load(plistFile)
    else:
        print('Something\'s terribly wrong here...')

    return plist_Contents

def promptToPatch(**parameters):

    # Prompt user to quit app.
    prompt = '"{}" -windowType "{}" -title "{}" -icon "/private/tmp/{}Icon.png" -heading "{}" -description "{}" -button1 OK -timeout 3600 -countdown -countdownPrompt "If you wish to delay this patch, please make a selection in " -alignCountdown center -lockHUD -showDelayOptions ", 600, 3600, 86400"'.format(parameters.get('jamfHelper'), parameters.get('windowType'), parameters.get('title'), parameters.get('applicationName'), parameters.get('heading'), parameters.get('description'))
    selection = runUtility(prompt)
    print('SELECTION:  {}'.format(selection))

    if selection == "1":
        print('User selected to patch now.')
        killAndInstall(**parameters)

    elif selection[:-1] == "600":
        print('DELAY:  600 seconds')
        delayDaemon(delayTime=600, **parameters)

    elif selection[:-1] == "3600":
        print('DELAY:  3600 seconds')
        delayDaemon(delayTime=3600, **parameters)

    elif selection[:-1] == "86400":
        print('DELAY:  86400 seconds')
        delayDaemon(delayTime=86400, **parameters)

    elif selection == "243":
        print('TIMED OUT:  user did not make a selection')
        killAndInstall(**parameters)

    else:
        print('Unknown action was taken at prompt.')
        killAndInstall(**parameters)

def killAndInstall(**parameters):

    try:
        print('Attempting to close app if it\'s running...')
        # Get PID of the application
        print('Process ID:  {}'.format(parameters.get('status').split(' ')[0]))
        pid = int(parameters.get('status').split(' ')[0])

        # Kill PID
        os.kill(pid, signal.SIGTERM) #or signal.SIGKILL
    except:
        print('Unable to terminate app, assuming it was manually closed...')

    print('Performing install...')

    # Run Policy
    runUtility(parameters.get('installPolicy'))
    # print('Test run, don\'t run policy!')

    prompt = '"{}" -windowType "{}" -title "{}" -icon "/private/tmp/{}Icon.png" -heading "{}" -description "{}" -button1 OK -timeout 60 -alignCountdown center -lockHUD'.format(parameters.get('jamfHelper'), parameters.get('windowType'), parameters.get('title'), parameters.get('applicationName'), parameters.get('heading'), parameters.get('descriptionComplete'))
    runUtility(prompt)

def delayDaemon(**parameters):

    # Configure for delay.
    if os.path.exists(parameters.get('patchPlist')):
        patchPlist_contents = plistReader(parameters.get('patchPlist'))
        patchPlist_contents.update( { parameters.get('applicationName') : "Delayed" } )
        plistlib.dump(patchPlist_contents, parameters.get('patchPlist'))
    else:
        patchPlist_contents = { parameters.get('applicationName') : "Delayed" }
        plistlib.dump(patchPlist_contents, parameters.get('patchPlist'))

    print('Creating the Patcher launchDaemon...')

    launchDaemon_plist = {
    "Label" : "com.github.mlbz521.jamf.patcher",
    'ProgramArguments' : ["/usr/local/jamf/bin/jamf", "policy", "-id", "{}".format(parameters.get('patchID'))],
    'StartInterval' : parameters.get('delayTime'),
    'AbandonProcessGroup' : True
    }

    plistlib.dump(launchDaemon_plist, parameters.get('launchDaemonLocation'))

    if os.path.exists(parameters.get('launchDaemonLocation')):

        # Check if the LaucnhDaemon is running, if so restart it in case a change was made to the plist file.
        # Determine proper launchctl syntax based on OS Version
        if parameters.get('osMinorVersion') >= 11:
            launchctl_print = '/bin/launchctl print system/{} > /dev/null 2>&1; echo $?'.format(parameters.get('launchDaemonLabel'))
            exitCode = runUtility(launchctl_print)
            # print('exitCode:  {}'.format(exitCode))

            if int(exitCode) == 0:
                print('Patcher launchDaemon is currently started; stopping now...')
                launchctl_bootout = '/bin/launchctl bootout system/{}'.format(parameters.get('launchDaemonLabel'))
                runUtility(launchctl_bootout)

            print('Loading Patcher launchDaemon...')
            launchctl_bootstrap = '/bin/launchctl bootstrap system {}'.format(parameters.get('launchDaemonLocation'))
            runUtility(launchctl_bootstrap)

            launchctl_enable = '/bin/launchctl enable system/{}'.format(parameters.get('launchDaemonLabel'))
            runUtility(launchctl_enable)

        elif parameters.get('osMinorVersion') <= 10:
            launchctl_list = '/bin/launchctl list {} > /dev/null 2>&1; echo $?'.format(parameters.get('launchDaemonLabel'))
            exitCode = runUtility(launchctl_list)

            if  int(exitCode) == 0:
                print('Patcher launchDaemon is currently started; stopping now...')
                launchctl_unload = '/bin/launchctl unload {}'.format(parameters.get('launchDaemonLocation'))
                runUtility(launchctl_unload)

            print('Loading Patcher launchDaemon...')
            launchctl_enable = '/bin/launchctl load {}'.format(parameters.get('launchDaemonLocation'))
            runUtility(launchctl_enable)

def cleanUp(**parameters):
    print('Performing cleanup...')

    # Clean up patchPlist.
    if os.path.exists(parameters.get('patchPlist')):
        patchPlist_contents = plistReader(parameters.get('patchPlist'))

        if patchPlist_contents.get(parameters.get('applicationName')):
            patchPlist_contents.pop(parameters.get('applicationName'), None)
            print('Removing previously delayed app:  {}'.format(parameters.get('applicationName')))
            plistlib.dump(patchPlist_contents, parameters.get('patchPlist'))
        else:
            print('App not listed in patchPlist:  {}'.format(parameters.get('applicationName')))

    # Check if the LaunchDaemon is running.
    # Determine proper launchctl syntax based on OS Version.
    if parameters.get('osMinorVersion') >= 11:
        launchctl_print = '/bin/launchctl print system/{} > /dev/null 2>&1; echo $?'.format(parameters.get('launchDaemonLabel'))
        exitCode = runUtility(launchctl_print)

        if int(exitCode) == 0:
            print('Stopping the Patcher launchDaemon...')
            launchctl_bootout = '/bin/launchctl bootout system/{}'.format(parameters.get('launchDaemonLabel'))
            runUtility(launchctl_bootout)

    elif parameters.get('osMinorVersion') <= 10:
        launchctl_list = '/bin/launchctl list {} > /dev/null 2>&1; echo $?'.format(parameters.get('launchDaemonLabel'))
        exitCode = runUtility(launchctl_list)

        if int(exitCode) == 0:
            print('Stopping the Patcher launchDaemon...')
            launchctl_unload = '/bin/launchctl unload {}'.format(parameters.get('launchDaemonLabel'))
            runUtility(launchctl_unload)

    if os.path.exists(parameters.get('launchDaemonLocation')):
        os.remove(parameters.get('launchDaemonLocation'))

def main():
    print('*****  jamf_Patcher process:  START  *****')

    ##################################################
    # Define Script Parameters
    print('All args:  {}'.format(sys.argv))
    departmentName = sys.argv[4] # "My Organization Technology Office"
    applicationName = sys.argv[5] # "zoom"
    iconID = sys.argv[6] # "https://jps.server.com:8443/icon?id=49167"
    patchID = sys.argv[7]
    policyID = sys.argv[8]

    ##################################################
    # Define Variables
    jamfPS = plistReader('/Library/Preferences/com.jamfsoftware.jamf.plist')['jss_url']
    patchPlist = '/Library/Preferences/com.github.mlbz521.jamf.patcher.plist'
    jamfHelper = '/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper'
    launchDaemonLabel = 'com.github.mlbz521.jamf.patcher.{}'.format(applicationName)
    launchDaemonLocation = '/Library/LaunchDaemons/{}.plist'.format(launchDaemonLabel)
    osMinorVersion = platform.mac_ver()[0].split('.')[1]
    installPolicy = '/usr/local/jamf/bin/jamf policy -id {}'.format(policyID)

    ##################################################
    # Define jamfHelper window values
    title="Security Patch Notification"
    windowType="hud"
    description = '{name} will be updated to patch a security vulnerability.  Please quit {name} to apply this update.\n\nIf you have questions, please contact your deskside support group.'.format(name=applicationName)
    descriptionForce = '{name} will be updated to patch a security vulnerability.  Please quit {name} within the allotted time to apply this update.\n\nIf you have questions, please contact your deskside support group.'.format(name=applicationName)
    descriptionComplete = '{} has been patched!\n\n.'.format(applicationName)
    icon = '/private/tmp/{}Icon.png'.format(applicationName)

    if departmentName:
        heading = 'My Organization - {}'.format(departmentName)
    else:
        heading = 'My Organization'

    ##################################################
    # Bits staged...

    psCheck = '/bin/ps -ax -o pid,command | /usr/bin/grep -E "/Applications/{}" | /usr/bin/grep -v "grep" 2> /dev/null'.format(applicationName)
    status = runUtility(psCheck)
    print('APP STATUS:  {}'.format(status))

    if status == "continue":
        print('{} is not running, installing now...'.format(applicationName))
        runUtility(installPolicy)
        # print('Test run, don\'t run policy!')

        cleanUp(applicationName=applicationName, patchPlist=patchPlist, launchDaemonLabel=launchDaemonLabel, launchDaemonLocation=launchDaemonLocation, osMinorVersion=osMinorVersion)

    else:
        print('{} is running...'.format(applicationName))

        # Download the icon from the JPS
        iconURL = '{}icon?id={}'.format(jamfPS, iconID)
        try:
            iconImage = requests.get(iconURL)
            open('/private/tmp/{}Icon.png'.format(applicationName), 'wb').write(iconImage.content)
        except:
            sys.exc_clear()
            urllib.urlretrieve(iconURL, filename='/private/tmp/{}Icon.png'.format(applicationName))

        if os.path.exists(patchPlist):
            patchPlist_contents = plistReader(patchPlist)
            delayCheck = patchPlist_contents.get(applicationName)

            if delayCheck:
                print('STATUS:  Patch has already been delayed; forcing upgrade.')

                # Prompt user with one last warning.
                prompt = '"{}" -windowType "{}" -title "{}" -icon "/private/tmp/{}Icon.png" -heading "{}" -description "{}" -button1 OK -timeout 600 -countdown -countdownPrompt \'{} will be force closed in \' -alignCountdown center -lockHUD > /dev/null 2>&1'.format(jamfHelper, windowType, title, applicationName, heading, descriptionForce, applicationName)
                runUtility(prompt)

                killAndInstall(status=status, installPolicy=installPolicy, applicationName=applicationName, jamfHelper=jamfHelper, windowType=windowType, title=title, heading=heading, descriptionComplete=descriptionComplete)
 
                cleanUp(applicationName=applicationName, patchPlist=patchPlist, launchDaemonLabel=launchDaemonLabel, launchDaemonLocation=launchDaemonLocation, osMinorVersion=osMinorVersion, patchPlist_contents=patchPlist_contents)

            else:
                print('STATUS:  Patch has not been delayed; prompting user.')
                promptToPatch(applicationName=applicationName, patchID=patchID, patchPlist=patchPlist, jamfHelper=jamfHelper, windowType=windowType, title=title, heading=heading, description=description, descriptionComplete=descriptionComplete, launchDaemonLabel=launchDaemonLabel, launchDaemonLocation=launchDaemonLocation, osMinorVersion=osMinorVersion, status=status, installPolicy=installPolicy)
        else:
            print('STATUS:  Patch has not been delayed; prompting user.')
            promptToPatch(applicationName=applicationName, patchID=patchID, patchPlist=patchPlist, jamfHelper=jamfHelper, windowType=windowType, title=title, heading=heading, description=description, descriptionComplete=descriptionComplete, launchDaemonLabel=launchDaemonLabel, launchDaemonLocation=launchDaemonLocation, osMinorVersion=osMinorVersion, status=status, installPolicy=installPolicy)

    print('*****  jamf_Patcher process:  SUCCESS  *****')

if __name__ == "__main__":
    main()
