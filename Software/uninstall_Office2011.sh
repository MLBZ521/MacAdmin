#!/bin/sh
#set -x

###################################################################################################
# Script Name:  uninstall_Office2011.sh
# By:  Zack Thompson / Created:  2/12/2018
# Version:  1.0 / Updated:  2/12/2018 / By:  ZT
#
# Description:  This script combines the Remove2011 script by @pbowden (of Microsoft) and the dockutil utility by Kyle Crawford.
# 		This is done so I don't have to package this and have it provided by a distribution point.  It'll run straight from the JSS.
#
# All credit to the authors:
# 		- https://github.com/pbowden-msft/Remove2011
###################################################################################################

TOOL_NAME="Microsoft Office 2011 for Mac Removal Tool"
TOOL_VERSION="1.5"

## Copyright (c) 2017 Microsoft Corp. All rights reserved.
## Scripts are not supported under any Microsoft standard support program or service. The scripts are provided AS IS without warranty of any kind.
## Microsoft disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a 
## particular purpose. The entire risk arising out of the use or performance of the scripts and documentation remains with you. In no event shall
## Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages whatsoever 
## (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary 
## loss) arising out of the use of or inability to use the sample scripts or documentation, even if Microsoft has been advised of the possibility
## of such damages.

## Set up logging
# All stdout and sterr will go to the log file. Console alone can be accessed through >&3. For console and log use | tee /dev/fd/3
SCRIPT_NAME=$(basename "$0")
WORKING_FOLDER=$(dirname "$0")
LOG_FILE="$TMPDIR""$SCRIPT_NAME.log"
touch "$LOG_FILE"
exec 3>&1 1>>${LOG_FILE} 2>&1

## Formatting support
TEXT_RED='\033[0;31m'
TEXT_YELLOW='\033[0;33m'
TEXT_GREEN='\033[0;32m'
TEXT_BLUE='\033[0;34m'
TEXT_NORMAL='\033[0m'

## Initialize global variables
FORCE_PERM=false
PRESERVE_DATA=true
APP_RUNNING=false
KEEP_LYNC=false
SAVE_LICENSE=false

## Path constants
PATH_OFFICE2011="/Applications/Microsoft Office 2011"
PATH_WORD2011="/Applications/Microsoft Office 2011/Microsoft Word.app"
PATH_EXCEL2011="/Applications/Microsoft Office 2011/Microsoft Excel.app"
PATH_PPT2011="/Applications/Microsoft Office 2011/Microsoft PowerPoint.app"
PATH_OUTLOOK2011="/Applications/Microsoft Office 2011/Microsoft Outlook.app"
PATH_LYNC2011="/Applications/Microsoft Lync.app"
PATH_MAU="/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app"


#####  Creating the dockutil script from this script (so I don't have to package this process)  #####
/bin/cat > "${WORKING_FOLDER}/dockutil" <<createdockutil
#!/usr/bin/python

#####  This file was created by the MS Remove2011 script #####

#   This file is based on or incorporates material from the projects listed below (Third Party IP). The original copyright notice and the license under
#   which Microsoft received such Third Party IP, are set forth below. Such licenses and notices are provided for informational purposes only. Microsoft
#   licenses the Third Party IP to you under the licensing terms for the Microsoft product. Microsoft reserves all other rights not expressly granted 
#   under this agreement, whether by implication, estoppel or otherwise.

#   DOCKUTIL
#   Copyright 2008 Kyle Crawford

#   Provided for Informational Purposes Only 

#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0

#   THIS CODE IS PROVIDED ON AN *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY
#   IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.

#   See the Apache Version 2.0 License for specific language governing permissions and limitations under the License.

#   Send bug reports and comments to kcrwfrd at gmail

# Possible future enhancements
# tie in with application identifier codes for locating apps and replacing them in the dock with newer versions?

import sys, plistlib, subprocess, os, getopt, re, pipes, tempfile, pwd
import platform


# default verbose printing to off
verbose = False
version = '2.0.2'

def usage(e=None):
    """Displays usage information and error if one occurred"""

    print """usage:     %(progname)s -h
usage:     %(progname)s --add <path to item> | <url> [--label <label>] [ folder_options ] [ position_options ] [ plist_location_specification ] [--no-restart]
usage:     %(progname)s --remove <dock item label> | all [ plist_location_specification ] [--no-restart]
usage:     %(progname)s --move <dock item label>  position_options [ plist_location_specification ]
usage:     %(progname)s --find <dock item label> [ plist_location_specification ]
usage:     %(progname)s --list [ plist_location_specification ]
usage:     %(progname)s --version

position_options:
  --replacing <dock item label name>                            replaces the item with the given dock label or adds the item to the end if item to replace is not found
  --position [ index_number | beginning | end | middle ]        inserts the item at a fixed position: can be an position by index number or keyword
  --after <dock item label name>                                inserts the item immediately after the given dock label or at the end if the item is not found
  --before <dock item label name>                               inserts the item immediately before the given dock label or at the end if the item is not found
  --section [ apps | others ]                                   specifies whether the item should be added to the apps or others section

plist_location_specifications:
  <path to a specific plist>                                    default is the dock plist for current user
  <path to a home directory>
  --allhomes                                                    attempts to locate all home directories and perform the operation on each of them
  --homeloc                                                     overrides the default /Users location for home directories

folder_options:
  --view [grid|fan|list|automatic]                              stack view option
  --display [folder|stack]                                      how to display a folder's icon
  --sort [name|dateadded|datemodified|datecreated|kind]         sets sorting option for a folder view

Examples:
  The following adds TextEdit.app to the end of the current user's dock:
           %(progname)s --add /Applications/TextEdit.app

  The following replaces Time Machine with TextEdit.app in the current user's dock:
           %(progname)s --add /Applications/TextEdit.app --replacing 'Time Machine'

  The following adds TextEdit.app after the item Time Machine in every user's dock on that machine:
           %(progname)s --add /Applications/TextEdit.app --after 'Time Machine' --allhomes

  The following adds ~/Downloads as a grid stack displayed as a folder for every user's dock on that machine:
           %(progname)s --add '~/Downloads' --view grid --display folder --allhomes

  The following adds a url dock item after the Downloads dock item for every user's dock on that machine:
           %(progname)s --add vnc://miniserver.local --label 'Mini VNC' --after Downloads --allhomes

  The following removes System Preferences from every user's dock on that machine:
           %(progname)s --remove 'System Preferences' --allhomes

  The following moves System Preferences to the second slot on every user's dock on that machine:
           %(progname)s --move 'System Preferences' --position 2 --allhomes

  The following finds any instance of iTunes in the specified home directory's dock:
           %(progname)s --find iTunes /Users/jsmith

  The following lists all dock items for all home directories at homeloc in the form: item<tab>path<tab><section>tab<plist>
           %(progname)s --list --homeloc /Volumes/RAID/Homes --allhomes

  The following adds Firefox after Safari in the Default User Template without restarting the Dock
           %(progname)s --add /Applications/Firefox.app --after Safari --no-restart '/System/Library/User Template/English.lproj'


Notes:
  When specifying a relative path like ~/Documents with the --allhomes option, ~/Documents must be quoted like '~/Documents' to get the item relative to each home

Bugs:
  Names containing special characters like accent marks will fail


Contact:
  Send bug reports and comments to kcrwfrd at gmail.
""" % dict(progname = os.path.basename(sys.argv[0]))
    if e:
        print ""
        print 'Error processing options:', e
        sys.exit(1)
    sys.exit(0)

def verboseOutput(*args):
    """Used by verbose option (-v) to send more output to stdout"""
    if verbose:
        try:
            print "verbose:", args
        except:
            pass

def main():
    """Parses options and arguments and performs fuctions"""
    # setup our getoput opts and args
    try:
        (optargs, args) = getopt.getopt(sys.argv[1:], 'hv', ["help", "version",
            "section=", "list", "find=", "add=", "move=", "replacing=",
            "remove=", "after=", "before=", "position=", "display=", "view=",
            "sort=", "label=", "type=", "allhomes", "homeloc=", "no-restart", "hupdock="])
    except getopt.GetoptError, e:  # if parsing of options fails, display usage and parse error
        usage(e)

    # setup default values
    global verbose
    add_path = None
    remove_labels = []
    find_label = None
    move_label = None
    after_item = None
    before_item = None
    position = None
    add_path = None
    plist_path = None
    list = False
    all_homes = False
    replace_label = None
    section = None
    displayas = None
    showas = None
    arrangement = None
    tile_type = None
    label_name = None
    home_directories_loc = '/Users'
    restart_dock = True

    for opt, arg in optargs:
        if opt in ("-h", "--help"):
            usage()
        elif opt == "-v":
            verbose = True
        elif opt == "--version":
            print version
            sys.exit(0)
        elif opt == "--add":
            add_path = arg
        elif opt == "--replacing":
            replace_label = arg
        elif opt == "--move":
            move_label = arg
        elif opt == "--find":
            find_label = arg
        elif opt == "--remove":
            remove_labels.append(arg)
        elif opt == "--after":
            after_item = arg
        elif opt == "--before":
            before_item = arg
        elif opt == "--position":
            position = arg
        elif opt == "--label":
            label_name = arg
        elif opt == '--sort':
            if arg == 'name':
                arrangement = 1
            elif arg == 'dateadded':
                arrangement = 2
            elif arg == 'datemodified':
                arrangement = 3
            elif arg == 'datecreated':
                arrangement = 4
            elif arg == 'kind':
                arrangement = 5
            else:
                usage('unsupported --sort argument')
        elif opt == '--view':
            if arg == 'fan':
                showas = 1
            elif arg == 'grid':
                showas = 2
            elif arg == 'list':
                showas = 3
            elif arg == 'auto':
                showas = 0
            else:
                usage('unsupported --view argument')
        elif opt == '--display':
            if arg == 'stack':
                displayas = 0
            elif arg == 'folder':
                displayas = 1
            else:
                usage('unsupported --display argument')
        elif opt == '--type':
            tile_type = arg+'-tile'
        elif opt == '--section':
            section = 'persistent-'+arg
        elif opt == '--list':
            list = True
        elif opt == '--allhomes':
            all_homes = True
        elif opt == '--homeloc':
            home_directories_loc = arg
        elif opt == '--no-restart':
            restart_dock = False

        # for legacy compatibility only
        elif opt == '--hupdock':
            if arg.lower() in ("false", "no", "off", "0"):
                restart_dock = False

    # check for an action
    if add_path == None and not remove_labels and move_label == None and find_label == None and list == False:
        usage('no action was specified')


    # get the list of plists to process
    # if allhomes option was set, get a list of home directories in the homedirectory location
    if all_homes:
        possible_homes = os.listdir(home_directories_loc)
        plist_paths = [ home_directories_loc+'/'+home+'/Library/Preferences/com.apple.dock.plist' for home in possible_homes if os.path.exists(home_directories_loc+'/'+home+'/Library/Preferences/com.apple.dock.plist') and os.path.exists(home_directories_loc+'/'+home+'/Desktop')]
    else: # allhomes was not specified
        # if no plist argument, then use the user's home directory dock plist, otherwise use the arguments provided
        if args == []:
            plist_paths = [ os.path.expanduser('~/Library/Preferences/com.apple.dock.plist') ]
        else:
            plist_paths = args
    # exit if we couldn't find any plists to process
    if len(plist_paths) < 1:
        print 'no dock plists were found'
        sys.exit(1)

    # loop over plist paths
    for plist_path in plist_paths:

        verboseOutput('processing', plist_path)
        # a home directory is allowed as an argument, so if the plist_path is a
        # directory, we append the relative path to the plist
        if os.path.isdir(plist_path):
            plist_path = os.path.join(plist_path,'Library/Preferences/com.apple.dock.plist')

        # verify that the plist exists at the given path
        # and expand and quote it for use when shelling out
        if os.path.exists(os.path.expanduser(plist_path)):
            plist_path = os.path.expanduser(plist_path)
            plist_path = os.path.abspath(plist_path)
            plist_path = pipes.quote(plist_path)
        else:
            print plist_path, 'does not seem to be a home directory or a dock plist'
            sys.exit(1)


        # check for each action and process accordingly
        if remove_labels: # --remove action(s)
            pl = readPlist(plist_path)
            changed = False
            for remove_label in remove_labels:
                if removeItem(pl, remove_label):
                    changed = True
                else:
                    print 'item', remove_label, 'was not found in', plist_path
            if changed:
                commitPlist(pl, plist_path, restart_dock)
        elif list: # --list action
            pl = readPlist(plist_path)
            # print a tab separated line for each item in the plist
            # for each section
            for section in ['persistent-apps', 'persistent-others']:
                # for item in section
                for item in pl[section]:
                    try:
                        # join and print relevant data into a string separated by tabs
                        print '\t'.join((item['tile-data']['file-label'], item['tile-data']['file-data']['_CFURLString'], section, plist_path))
                    except:
                        pass

        elif find_label != None: # --find action
            # since we are only reading the plist, make a copy before converting it to be read
            pl = readPlist(plist_path)
            # set found state
            item_found = False
            # loop through dock items looking for a match with provided find_label
            for section in ['persistent-apps', 'persistent-others']:
                for item_offset in range(len(pl[section])):
                    try:
                        if pl[section][item_offset]['tile-data']['file-label'] == find_label:
                            item_found = True
                            print find_label, "was found in", section, "at slot", item_offset+1, "in", plist_path
                    except:
                        pass
            if not item_found:
                print find_label, "was not found in", plist_path
                if not all_homes:  # only exit non-zero if we aren't processing all homes, because for allhomes, exit status for find would be irrelevant
                    sys.exit(1)

        elif move_label != None: # --move action
            pl = readPlist(plist_path)
            # check for a position option before processing
            if position is None and before_item is None and after_item is None:
                usage('move action requires a position destination')
            # perform the move and save the plist if it was successful
            if moveItem(pl, move_label, position, before_item, after_item):
                commitPlist(pl, plist_path, restart_dock)
            else:
                print 'move failed for', move_label, 'in', plist_path

        elif add_path != None:  # --add action
            if add_path.startswith('~'): # we've got a relative path and relative paths need to be processed by using a path relative to this home directory
                real_add_path = re.sub('^~', plist_path.replace('/Library/Preferences/com.apple.dock.plist',''), add_path) # swap out the full home path for the ~
            else:
                real_add_path = add_path
            # determine smart default values where possible
            if section == None:
                if real_add_path.endswith('.app') or real_add_path.endswith('.app/'): # we've got an application
                    section = 'persistent-apps'
                elif displayas != None or showas != None or arrangement != None: # we've got a folder
                    section = 'persistent-others'

            if tile_type is None:  # if type was not specified, we try to figure that out using the filesystem
                if os.path.isdir(real_add_path) and section != 'persistent-apps': # app bundles are directories too
                    tile_type = 'directory-tile'
                elif re.match('\w*://', real_add_path): # regex to determine a url in the form xyz://abcdef.adsf.com/adsf
                    tile_type = 'url-tile'
                    section = 'persistent-others'
                else:
                    tile_type = 'file-tile'

            if section == None:
                section = 'persistent-others'


            if tile_type != 'url-tile': # paths can't be relative in dock items
                real_add_path = os.path.realpath(real_add_path)


            pl = readPlist(plist_path)
            verboseOutput('adding', real_add_path)
            # perform the add save the plist if it was successful
            if addItem(pl, real_add_path, replace_label, position, before_item, after_item, section, displayas, showas, arrangement, tile_type, label_name):
                commitPlist(pl, plist_path, restart_dock)
            else:
                print 'item', add_path, 'was not added to Dock'
                if not all_homes:  # only exit non-zero if we aren't processing all homes, because for allhomes, exit status for add would be irrelevant
                    sys.exit(1)

# NOTE on use of defaults
# We use defaults because it knows how to handle cfpreferences caching even when given a path rather than a domain
# This allows us to keep using path-based plist specifications rather than domains
# Preserving path based plists are important for people needing to run this on a non boot volume
# However if Apple stops using plists or moves the plist path, all of this will break
# So at that point we will have to change the API so users pass in a defaults domain or user rather than a plist path
def writePlist(pl, plist_path):
    """writes a plist object down to a file"""
    # get the unescaped path
    plist_path = path_as_string(plist_path)
    # get a tempfile path for writing our plist
    plist_import_path = tempfile.mktemp()
    # Write the plist to our temporary plist for importing because defaults can't import from a pipe (yet)
    plistlib.writePlist(pl, plist_import_path)
    # get original permissions
    plist_stat = os.stat(plist_path)
    # If we are running as root, ensure we run as the correct user to update cfprefsd
    if os.geteuid() == 0:
        # Running defaults as the user only works if the user exists
        if valid_uid(plist_stat.st_uid):
            subprocess.Popen(['sudo', '-u', '#%d' % plist_stat.st_uid, '-g', '#%d' % plist_stat.st_gid, 'defaults', 'import', plist_path, plist_import_path])
        else:
            subprocess.Popen(['defaults', 'import', plist_path, plist_import_path])
            os.chown(plist_path, plist_stat.st_uid, plist_stat.st_gid)
            os.chmod(plist_path, plist_stat.st_mode)
    else:
        subprocess.Popen(['defaults', 'import', plist_path, plist_import_path])


def valid_uid(uid):
    """returns bool of whether uid can be resolved to a user"""
    try:
        pwd.getpwuid(uid)
        return True
    except:
        return False

def getOsxVersion():
    """returns a tuple with the (major,minor,revision) numbers"""
    # OS X Yosemite return 10.10, so we will be happy with len(...) == 2, then add 0 for last number
    try:
        mac_ver = tuple(int(n) for n in platform.mac_ver()[0].split('.'))
        assert 2 <= len(mac_ver) <= 3
    except Exception as e:
        raise e
    if len(mac_ver) == 2:
      mac_ver = mac_ver + (0, )
    return mac_ver

def readPlist(plist_path):
    """returns a plist object read from a file path"""
    # get the unescaped path
    plist_path = path_as_string(plist_path)
    # get a tempfile path for exporting our defaults data
    export_fifo = tempfile.mktemp()
    # make a fifo for defaults export in a temp file
    os.mkfifo(export_fifo)
    # export to the fifo
    osx_version = getOsxVersion()
    if osx_version[1] >= 9:
        subprocess.Popen(['defaults', 'export', plist_path, export_fifo]).communicate()
        # convert the export to xml
        plist_string = subprocess.Popen(['plutil', '-convert', 'xml1', export_fifo, '-o', '-'], stdout=subprocess.PIPE).stdout.read()
    else:
        try:
            cmd = ['/usr/libexec/PlistBuddy','-x','-c', 'print',plist_path]
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            (plist_string,err) = proc.communicate()
        except Exception as e:
            raise e
    # parse the xml into a dictionary
    pl = plistlib.readPlistFromString(plist_string)
    return pl

def path_as_string(path):
    """returns an unescaped string of the path"""
    return subprocess.Popen('ls -d '+path, shell=True, stdout=subprocess.PIPE).stdout.read().rstrip('\n')

def moveItem(pl, move_label=None, position=None, before_item=None, after_item=None):
    """locates an existing dock item and moves it to a new position"""
    for section in ['persistent-apps', 'persistent-others']:
        item_to_move = None
        # loop over the items looking for the item label
        for item_offset in range(len(pl[section])):
            if pl[section][item_offset]['tile-data']['file-label'] == move_label:
                item_found = True
                verboseOutput('found', move_label) 
                # make a copy of the found dock entry
                item_to_move = pl[section][item_offset]
                found_offset = item_offset
                break
            else:
                verboseOutput('no match for', pl[section][item_offset]['tile-data']['file-label'])
        # if the item wasn't found, continue to next section loop iteration
        if item_to_move == None:
            continue
        # we are still inside the section for loop
        # remove the found item
        pl[section].remove(pl[section][item_offset])

        # figure out where to re-insert the original dock item back into the plist
        if position != None:
            if position in [ 'beginning', 'begin', 'first' ]:        
                pl[section].insert(0, item_to_move)
                return True
            elif position in [ 'end', 'last' ]:
                pl[section].append(item_to_move)
                return True
            elif position in [ 'middle', 'center' ]:
                midpoint = int(len(pl[section])/2)
                pl[section].insert(midpoint, item_to_move)
                return True
            else:
                # if the position integer starts with a + or - , then add or subtract from its current position respectively
                if position.startswith('-') or position.startswith('+'):
                    new_position = int(position) + found_offset
                    if new_position > len(pl[section]):
                        pl[section].append(item_to_move)
                    elif new_position < 0:
                        pl[section].insert(0, item_to_move)
                    else:
                        pl[section].insert(int(position) + found_offset, item_to_move)
                    return True

                try:
                    int(position)
                except:
                    print 'Invalid position', position
                    return False
                pl[section].insert(int(position)-1, item_to_move)
                return True
        elif after_item != None or before_item != None:
            # if after or before is set, find the offset of that item and do the insert relative to that offset
            for item_offset in range(len(pl[section])):
                try:
                    if after_item != None:
                        if pl[section][item_offset]['tile-data']['file-label'] == after_item:
                            pl[section].insert(item_offset+1, item_to_move)
                            return True
                    if before_item != None:
                        if pl[section][item_offset]['tile-data']['file-label'] == before_item:
                            pl[section].insert(item_offset, item_to_move)
                            return True
                except KeyError:
                    pass

    return False

def generate_guid():
    """returns guid string"""
    return subprocess.Popen(['/usr/bin/uuidgen'],stdout=subprocess.PIPE).communicate()[0].rstrip()

def addItem(pl, add_path, replace_label=None, position=None, before_item=None, after_item=None, section='persistent-apps', displayas=1, showas=1, arrangement=2, tile_type='file-tile',label_name=None):
    """adds an item to an existing dock plist object"""
    if displayas == None: displayas = 1
    if showas == None: showas = 0
    if arrangement == None: arrangement = 2

    #fix problems with unicode file names
    enc = (sys.stdin.encoding if sys.stdin.encoding else 'UTF-8')
    add_path = unicode(add_path, enc)

    # set a dock label if one isn't provided
    if label_name == None:
        if tile_type == 'url-tile':
            label_name = add_path
            section = 'persistent-others'
        else:
            base_name = re.sub('/$', '', add_path).split('/')[-1]
            label_name = re.sub('.app$', '', base_name)


    # only add if item label isn't already there

    if replace_label != label_name:
        for existing_dock_item in (pl[section]):
            for label_key in ['file-label','label']:
                if existing_dock_item['tile-data'].has_key(label_key):
                    if existing_dock_item['tile-data'][label_key] == label_name:
                        print "%s already exists in dock. Use --replacing '%s' to update an existing item" % (label_name, label_name)
                        return False



    if replace_label != None:
        for item_offset in range(len(pl[section])):
            tile_replace_candidate = pl[section][item_offset]['tile-data']
            if tile_replace_candidate[label_key_for_tile(tile_replace_candidate)] == replace_label:
                verboseOutput('found', replace_label)
                del pl[section][item_offset]
                position = item_offset + 1
                break

    new_guid = generate_guid()
    if tile_type == 'file-tile':
        new_item = {'GUID': new_guid, 'tile-data': {'file-data': {'_CFURLString': add_path, '_CFURLStringType': 0},'file-label': label_name, 'file-type': 32}, 'tile-type': tile_type}
    elif tile_type == 'directory-tile':
        if subprocess.Popen(['/usr/bin/sw_vers', '-productVersion'],
                stdout=subprocess.PIPE).stdout.read().rstrip().split('.')[1] == '4': # gets the decimal after 10 in sw_vers; 10.4 does not use 10.5 options for stacks
            new_item = {'GUID': new_guid, 'tile-data': {'directory': 1, 'file-data': {'_CFURLString': add_path, '_CFURLStringType': 0}, 'file-label': label_name, 'file-type': 2 }, 'tile-type': tile_type}
        else:
            new_item = {'GUID': new_guid, 'tile-data': {'arrangement': arrangement, 'directory': 1, 'displayas': displayas, 'file-data': {'_CFURLString': add_path, '_CFURLStringType': 0}, 'file-label': label_name, 'file-type': 2, 'showas': showas}, 'tile-type': tile_type}

    elif tile_type == 'url-tile':
        new_item = {'GUID': new_guid, 'tile-data': {'label': label_name, 'url': {'_CFURLString': add_path, '_CFURLStringType': 15}}, 'tile-type': tile_type}
    else:
        print 'unknown type:', tile_type
        sys.exit(1)

    verboseOutput('adding', new_item)

    if position != None:
        if position in [ 'beginning', 'begin', 'first' ]:
            pl[section].insert(0, new_item)
            return True
        elif position in [ 'end', 'last' ]:
            pl[section].append(new_item)
            return True
        elif position in [ 'middle', 'center' ]:
            midpoint = int(len(pl[section])/2)
            pl[section].insert(midpoint, new_item)
            return True
        else:
            try:
                int(position)
            except:
                print 'Invalid position', position
                return False
            if int(position) == 0:
                pl[section].insert(int(position), new_item)
            elif int(position) > 0:
                pl[section].insert(int(position)-1, new_item)
            else:
                pl[section].insert(int(position)+len(pl[section])+1, new_item)
            return True
    elif after_item != None or before_item !=None:
        for item_offset in range(len(pl[section])):
            try:
                if after_item != None:
                    if pl[section][item_offset]['tile-data']['file-label'] == after_item:
                        pl[section].insert(item_offset+1, new_item)
                        return True
                if before_item != None:
                    if pl[section][item_offset]['tile-data']['file-label'] == before_item:
                        pl[section].insert(item_offset, new_item)
                        return True
            except KeyError:
                pass
    pl[section].append(new_item)
    verboseOutput('item added at end')
    return True

def removeItem(pl, item_name):
    removal_succeeded = False
    if item_name == "all":
        verboseOutput('Removing all items')
        pl['persistent-apps'] = []
        pl['persistent-others'] = []
        return True
    for dock_item in pl['persistent-apps']:
        if dock_item['tile-data'].get('file-data').get('_CFURLString') == item_name:
            verboseOutput('found', item_name)
            pl['persistent-apps'].remove(dock_item)
            removal_succeeded = True
    for dock_item in pl['persistent-others']:
        if dock_item['tile-type'] == "url-tile":
            if dock_item['tile-data'].get('label') == item_name:
                verboseOutput('found', item_name)
                pl['persistent-others'].remove(dock_item)
                removal_succeeded = True
        else:
            if dock_item['tile-data'].get('file-label') == item_name:
                verboseOutput('found', item_name)
                pl['persistent-others'].remove(dock_item)
                removal_succeeded = True
    return removal_succeeded

def commitPlist(pl, plist_path, restart_dock):
    writePlist(pl, plist_path)
    if restart_dock:
        os.system('/usr/bin/killall -HUP Dock >/dev/null 2>&1')

#def commitPlistLegacy(pl, plist_path, restart_dock):
#    plist_string_path = path_as_string(plist_path)
#    pl = removeLongs(pl)
#    plist_stat = os.stat(plist_string_path)
#    writePlist(pl, plist_path)
#    convertPlist(plist_path, 'binary1')
#    os.chown(plist_string_path, plist_stat.st_uid, plist_stat.st_gid)
#    os.chmod(plist_string_path, plist_stat.st_mode)
#    if restart_dock:
#        os.system('/usr/bin/killall -HUP cfprefsd >/dev/null 2>&1')
#        os.system('/usr/bin/killall -HUP Dock >/dev/null 2>&1')
#

def label_key_for_tile(item):
    for label_key in ['file-label','label']:
        if item.has_key(label_key):
            return label_key


if __name__ == "__main__":
    main()
createdockutil
#####  End of creating dockutil by this script #####

# Set the permissions
/bin/chmod 700 "${WORKING_FOLDER}/dockutil"

## Functions
function LogMessage {
	echo $(date) "$*"
}

function ConsoleMessage {
	echo "$*" >&3
}

function FormattedConsoleMessage {
	FUNCDENT="$1"
	FUNCTEXT="$2"
	printf "$FUNCDENT" "$FUNCTEXT" >&3
}

function AllMessage {
	echo $(date) "$*"
	echo "$*" >&3
}

function LogDevice {
	LogMessage "In function 'LogDevice'"
	system_profiler SPSoftwareDataType -detailLevel mini
	system_profiler SPHardwareDataType -detailLevel mini
}

function ShowUsage {
	LogMessage "In function 'ShowUsage'"
	ConsoleMessage "Usage: $SCRIPT_NAME [--Force] [--Help] [--KeepLync] [--SaveLicense]"
	ConsoleMessage "Use --Force to bypass warnings and forcibly remove Office 2011 applications and data"
	ConsoleMessage ""
}

function GetDestructivePerm {
	LogMessage "In function 'GetDestructivePerm'"
	if [ $FORCE_PERM = false ]; then
		LogMessage "Script is not running with force - asking user for permission to continue"
		ConsoleMessage "${TEXT_RED}WARNING: This procedure will remove application and data files.${TEXT_NORMAL}"
		ConsoleMessage "${TEXT_RED}Be sure to have a backup before continuing.${TEXT_NORMAL}"
		ConsoleMessage "Do you wish to continue? (y/n)"
		read -p "" "GOAHEAD"
		if [ "$GOAHEAD" == "y" ] || [ "$GOAHEAD" == "Y" ]; then
			LogMessage "Destructive permissions granted by user"
			return
		else
			LogMessage "Destructive permissions DENIED by user"
			ConsoleMessage ""
			exit 0
		fi
	fi
}

function GetDestructiveDataPerm {
	LogMessage "In function 'GetDestructiveDataPerm'"
	if [ $FORCE_PERM = false ]; then
		LogMessage "Script is not running with force - asking user for permission to remove data files"
		ConsoleMessage "${TEXT_RED}This tool can either preserve or remove Outlook data files.${TEXT_NORMAL}"
		ConsoleMessage "Do you wish to preserve Outlook data? (y/n)"
		read -p "" "GOAHEAD"
		if [ "$GOAHEAD" == "y" ] || [ "$GOAHEAD" == "Y" ]; then
			LogMessage "User chose to preserve Outlook data"
			PRESERVE_DATA=true
		else
			LogMessage "User chose to remove Outlook data"
			PRESERVE_DATA=false
		fi
	fi
}

function GetDestructiveLicensePerm {
	LogMessage "In function 'GetDestructiveLicensePerm'"
	if [ $FORCE_PERM = false ]; then
		LogMessage "Script is not running with force - asking user for permission to remove license file"
		if [ $SAVE_LICENSE = false ]; then
			LogMessage "SAVE_LICENSE is false - asking user if they want to remove it"
			ConsoleMessage "${TEXT_RED}This tool can either preserve or remove your product activation license.${TEXT_NORMAL}"
			ConsoleMessage "Do you wish to preserve the license? (y/n)"
			read -p "" "GOAHEAD"
			if [ "$GOAHEAD" == "y" ] || [ "$GOAHEAD" == "Y" ]; then
				LogMessage "User chose to preserve the license"
				SAVE_LICENSE=true
			else
				LogMessage "User chose to remove the license"
				SAVE_LICENSE=false
			fi
		fi
	fi
}
function GetSudo {
	LogMessage "In function 'GetSudo'"
	if [ "$EUID" != "0" ]; then
		LogMessage "Script is not running as root - asking user for admin password"
		sudo -p "Enter administrator password: " echo
		if [ $? -eq 0 ] ; then
			LogMessage "Admin password entered successfully"
			ConsoleMessage ""
			return
		else
			LogMessage "Admin password is INCORRECT"
			exit 1
		fi
	fi
}

function CheckRunning {
	FUNCPROC="$1"
	LogMessage "In function 'CheckRunning' with argument $FUNCPROC"
	local RUNNING_RESULT=$(ps ax | grep -v grep | grep "$FUNCPROC")
	if [ "${#RUNNING_RESULT}" -gt 0 ]; then
		LogMessage "$FUNCPROC is currently running"
		APP_RUNNING=true
	fi
}

function CheckRunning2011 {
	LogMessage "In function 'CheckRunning2011'"
	CheckRunning "$PATH_WORD2011" "Word 2011"
	CheckRunning "$PATH_EXCEL2011" "Excel 2011"
	CheckRunning "$PATH_PPT2011" "PowerPoint 2011"
	CheckRunning "$PATH_OUTLOOK2011" "Outlook 2011"
	if [ $KEEP_LYNC = false ]; then 
		CheckRunning "$PATH_LYNC2011" "Lync 2011"
	fi
}

function Close2011 {
	LogMessage "In function 'Close2011'"
	if [ $FORCE_PERM = false ]; then
		LogMessage "Script is not running with force - asking user for permission to continue"
		GetForcePerms
	fi
	ForceQuit2011
}

function GetForcePerms {
	LogMessage "In function 'GetForcePerms'"
	ConsoleMessage "${TEXT_YELLOW}WARNING: Office applications are currently open and need to be closed.${TEXT_NORMAL}"
	ConsoleMessage "Do you want this program to forcibly close open applications? (y/n)"
	read -p "" "GOAHEAD"
	if [ "$GOAHEAD" == "y" ] || [ "$GOAHEAD" == "Y" ]; then
		LogMessage "User gave permission for the script to close running apps"
		FORCE_PERM=true
		ConsoleMessage ""
	else
		LogMessage "User DENIED permissions for the script to close running apps"
		ConsoleMessage ""
		exit 0
	fi
}

function ForceTerminate {
	FUNCPROC="$1"
	LogMessage "In function 'ForceTerminate' with argument $FUNCPROC"
	$(ps ax | grep -v grep | grep "$FUNCPROC" | cut -d' ' -f1 | xargs kill -9 2> /dev/null)
}

function ForceQuit2011 {
	LogMessage "In function 'ForceQuit2011'"
	FormattedConsoleMessage "%-55s" "Shutting down all Office 2011 applications"
	ForceTerminate "$PATH_WORD2011" "Word 2011"
	ForceTerminate "$PATH_EXCEL2011" "Excel 2011"
	ForceTerminate "$PATH_PPT2011" "PowerPoint 2011"
	ForceTerminate "$PATH_OUTLOOK2011" "Outlook 2011"
	if [ $KEEP_LYNC = false ]; then 
		ForceTerminate "$PATH_LYNC2011" "Lync 2011"
	fi
	ConsoleMessage "${TEXT_GREEN}Success${TEXT_NORMAL}"
}

function RemoveComponent {
	FUNCPATH="$1"
	FUNCTEXT="$2"
	LogMessage "In function 'RemoveComponent with arguments $FUNCPATH and $FUNCTEXT'"
	FormattedConsoleMessage "%-55s" "Removing $FUNCTEXT"
	if [ -d "$FUNCPATH" ] || [ -e "$FUNCPATH" ] ; then
		LogMessage "Removing path $FUNCPATH"
		$(sudo rm -r -f "$FUNCPATH")
	else
		LogMessage "$FUNCPATH was not detected"
		ConsoleMessage "${TEXT_YELLOW}Not detected${TEXT_NORMAL}"
		return
	fi
	if [ -d "$FUNCPATH" ] || [ -e "$FUNCPATH" ] ; then
		LogMessage "Path $FUNCPATH still exists after deletion"
		ConsoleMessage "${TEXT_RED}Failed${TEXT_NORMAL}"
	else
		LogMessage "Path $FUNCPATH was successfully removed"
		ConsoleMessage "${TEXT_GREEN}Success${TEXT_NORMAL}"
	fi
}

function RemoveUserComponent {
	FUNCPATH="$1"
	FUNCTEXT="$2"
	LogMessage "In function 'RemoveUserComponent with arguments $FUNCPATH and $FUNCTEXT'"
	for u in `ls /Users`; do
		FULLPATH="/Users/$u/$FUNCPATH"
		$(sudo rm -r -f $FULLPATH)
	done
}

function PreserveUserComponent {
	FUNCPATH="$1"
	FUNCTEXT="$2"
	LogMessage "In function 'remove_PreserveComponent with arguments $FUNCPATH and $FUNCTEXT'"
	FormattedConsoleMessage "%-55s" "Preserving $FUNCTEXT"
	for u in `ls /Users`; do
		FULLPATH="/Users/$u/$FUNCPATH"
		if [ -d "$FULLPATH" ] || [ -e "$FULLPATH" ] ; then
			LogMessage "Renaming path $FULLPATH"
			$(sudo mv -fv "$FULLPATH" "$FULLPATH-Preserved")
		fi
	done
	ConsoleMessage "${TEXT_GREEN}Success${TEXT_NORMAL}"
}

function Remove2011Receipts {
	LogMessage "In function 'Remove2011Receipts'"
	FormattedConsoleMessage "%-55s" "Removing Package Receipts"
	RECEIPTCOUNT=0
	RemoveReceipt "com.microsoft.office.all.*"
	RemoveReceipt "com.microsoft.office.en.*"
	RemoveReceipt "com.microsoft.merp.*"
	RemoveReceipt "com.microsoft.mau.*"
	if (( $RECEIPTCOUNT > 0 )) ; then
		ConsoleMessage "${TEXT_GREEN}Success${TEXT_NORMAL}"
	else
		ConsoleMessage "${TEXT_YELLOW}Not detected${TEXT_NORMAL}"
	fi
}

function RemoveReceipt {
	FUNCPATH="$1"
	LogMessage "In function 'RemoveReceipt' with argument $FUNCPATH"
	PKGARRAY=($(pkgutil --pkgs=$FUNCPATH))
	for p in "${PKGARRAY[@]}"
	do
		LogMessage "Forgetting package $p"
		sudo pkgutil --forget $p
		if [ $? -eq 0 ] ; then
			((RECEIPTCOUNT++))
		fi
	done
}

function Remove2011Preferences {
	LogMessage "In function 'Remove2011Preferences'"
	FormattedConsoleMessage "%-55s" "Removing Preferences"
	PREFCOUNT=0
	RemovePref "/Library/Preferences/com.microsoft.Word.plist"
	RemovePref "/Library/Preferences/com.microsoft.Excel.plist"
	RemovePref "/Library/Preferences/com.microsoft.Powerpoint.plist"
	RemovePref "/Library/Preferences/com.microsoft.Outlook.plist"
	RemovePref "/Library/Preferences/com.microsoft.outlook.databasedaemon.plist"
	RemovePref "/Library/Preferences/com.microsoft.DocumentConnection.plist"
	RemovePref "/Library/Preferences/com.microsoft.office.setupassistant.plist"
	RemoveUserPref "Library/Preferences/com.microsoft.Word.plist"
	RemoveUserPref "Library/Preferences/com.microsoft.Excel.plist"
	RemoveUserPref "Library/Preferences/com.microsoft.Powerpoint.plist"
	if [ $KEEP_LYNC = false ]; then 
		RemoveUserPref "Library/Preferences/com.microsoft.Lync.plist"
	fi
	RemoveUserPref "Library/Preferences/com.microsoft.Outlook.plist"
	RemoveUserPref "Library/Preferences/com.microsoft.outlook.databasedaemon.plist"
	RemoveUserPref "Library/Preferences/com.microsoft.outlook.office_reminders.plist"
	RemoveUserPref "Library/Preferences/com.microsoft.DocumentConnection.plist"
	RemoveUserPref "Library/Preferences/com.microsoft.office.setupassistant.plist"
	RemoveUserPref "Library/Preferences/com.microsoft.office.plist"
	RemoveUserPref "Library/Preferences/com.microsoft.error_reporting.plist"
	RemoveUserPref "Library/Preferences/ByHost/com.microsoft.Word.*.plist"
	RemoveUserPref "Library/Preferences/ByHost/com.microsoft.Excel.*.plist"
	RemoveUserPref "Library/Preferences/ByHost/com.microsoft.Powerpoint.*.plist"
	RemoveUserPref "Library/Preferences/ByHost/com.microsoft.Outlook.*.plist"
	RemoveUserPref "Library/Preferences/ByHost/com.microsoft.outlook.databasedaemon.*.plist"
	RemoveUserPref "Library/Preferences/ByHost/com.microsoft.DocumentConnection.*.plist"
	RemoveUserPref "Library/Preferences/ByHost/com.microsoft.office.setupassistant.*.plist"
	RemoveUserPref "Library/Preferences/ByHost/com.microsoft.registrationDB.*.plist"
	RemoveUserPref "Library/Preferences/ByHost/com.microsoft.e0Q*.*.plist"
	RemoveUserPref "Library/Preferences/ByHost/com.microsoft.Office365.*.plist"
	if [ $KEEP_LYNC = false ]; then 
		RemoveUserPref "Library/Preferences/ByHost/MicrosoftLyncRegistrationDB.*.plist"
	fi
	if (( $PREFCOUNT > 0 )); then
		ConsoleMessage "${TEXT_GREEN}Success${TEXT_NORMAL}"
	else
		ConsoleMessage "${TEXT_YELLOW}Not detected${TEXT_NORMAL}"
	fi
}

function RemovePref {
	FUNCPATH="$1"
	LogMessage "In function 'RemovePref' with argument $FUNCPATH"
	ls $FUNCPATH
	if [ $? -eq 0 ] ; then
		LogMessage "Found preference $FUNCPATH"
		$(sudo rm -f $FUNCPATH)
		if [ $? -eq 0 ] ; then
			LogMessage "Preference $FUNCPATH removed"
			((PREFCOUNT++))
		else
			LogMessage "Preference $FUNCPATH could NOT be removed"
		fi
	fi
}

function RemoveUserPref {
	FUNCPATH="$1"
	LogMessage "In function 'RemoveUserPref' with argument $FUNCPATH"
	for u in `ls /Users`; do
		FULLPATH="/Users/$u/$FUNCPATH"
		$(sudo rm -f $FULLPATH)
		((PREFCOUNT++))
	done
}

function CleanDock {
	LogMessage "In function 'CleanDock'"
	FormattedConsoleMessage "%-55s" "Cleaning icons in dock"
	if [ -e "$WORKING_FOLDER/dockutil" ]; then
		LogMessage "Found DockUtil tool"
		sudo "$WORKING_FOLDER"/dockutil --remove "file:///Applications/Microsoft%20Office%202011/Microsoft%20Document%20Connection.app/" --no-restart
		sudo "$WORKING_FOLDER"/dockutil --remove "file:///Applications/Microsoft%20Office%202011/Microsoft%20Word.app/" --no-restart
		sudo "$WORKING_FOLDER"/dockutil --remove "file:///Applications/Microsoft%20Office%202011/Microsoft%20Excel.app/" --no-restart
		sudo "$WORKING_FOLDER"/dockutil --remove "file:///Applications/Microsoft%20Office%202011/Microsoft%20PowerPoint.app/" --no-restart
		if [ $KEEP_LYNC = false ]; then 
			sudo "$WORKING_FOLDER"/dockutil --remove "file:///Applications/Microsoft%20Office%202011/Microsoft%20Lync.app/" --no-restart
		fi
		sudo "$WORKING_FOLDER"/dockutil --remove "file:///Applications/Microsoft%20Office%202011/Microsoft%20Outlook.app/"
		LogMessage "Completed dock clean-up"
		ConsoleMessage "${TEXT_GREEN}Success${TEXT_NORMAL}"
		rm -f "${WORKING_FOLDER}/dockutil"
	else
		ConsoleMessage "${TEXT_YELLOW}Not detected${TEXT_NORMAL}"
	fi
}

function RelaunchCFPrefs {
	LogMessage "In function 'RelaunchCFPrefs'"
	FormattedConsoleMessage "%-55s" "Restarting Preferences Daemon"
	sudo ps ax | grep -v grep | grep "cfprefsd" | cut -d' ' -f1 | xargs sudo kill -9
	if [ $? -eq 0 ] ; then
		LogMessage "Successfully terminated all preferences daemons"
		ConsoleMessage "${TEXT_GREEN}Success${TEXT_NORMAL}"
	else
		LogMessage "FAILED to terminate all preferences daemons"
		ConsoleMessage "${TEXT_RED}Failed${TEXT_NORMAL}"
	fi
}

function MainLoop {
	LogMessage "In function 'MainLoop'"
	# Show warning about destructive behavior of the script and ask for permission to continue
	GetDestructivePerm
	GetDestructiveDataPerm
	GetDestructiveLicensePerm
	# If appropriate, elevate permissions so the script can perform all actions
	GetSudo
	# Check to see if any of the 2011 apps are currently open
	CheckRunning2011
	if [ $APP_RUNNING = true ]; then
		LogMessage "One of more 2011 apps are running"
		Close2011
	fi
	# Remove Office 2011 apps
	RemoveComponent "$PATH_OFFICE2011" "Office 2011 Applications"
	if [ $KEEP_LYNC = false ]; then 
		RemoveComponent "$PATH_LYNC2011" "Lync"
	fi
	
	# Remove Office 2011 helpers
	RemoveComponent "/Library/LaunchDaemons/com.microsoft.office.licensing.helper.plist" "Launch Daemon: Licensing Helper"
	RemoveComponent "/Library/PrivilegedHelperTools/com.microsoft.office.licensing.helper" "Helper Tools: Licensing Helper"
	# Remove Office 2011 fonts
	RemoveComponent "/Library/Fonts/Microsoft" "Office Fonts"
	# Remove Office 2011 license
	if [ $SAVE_LICENSE = false ]; then
		LogMessage "SAVE_LICENSE is false - removing license file"
		RemoveComponent "/Library/Preferences/com.microsoft.office.licensing.plist" "Product License"
	fi
	# Remove Office 2011 application support
	RemoveComponent "/Library/Application Support/Microsoft/MERP2.0" "Error Reporting"
	RemoveUserComponent "Library/Application Support/Microsoft/Office" "Application Support"
	# Remove Office 2011 caches
	RemoveUserComponent "Library/Caches/com.microsoft.browserfont.cache" "Browser Font Cache"
	RemoveUserComponent "Library/Caches/com.microsoft.office.setupassistant" "Setup Assistant Cache"
	RemoveUserComponent "Library/Caches/Microsoft/Office" "Office Cache"
	RemoveUserComponent "Library/Caches/Outlook" "Outlook Identity Cache"
	RemoveUserComponent "Library/Caches/com.microsoft.Outlook" "Outlook Cache"
	# Remove Office 2011 preferences
	Remove2011Preferences
	# Remove or rename Outlook 2011 identities and databases
	if [ $PRESERVE_DATA = false ]; then
		RemoveUserComponent "Documents/Microsoft User Data/Office 2011 Identities" "Outlook Identities and Databases"
		RemoveUserComponent "Documents/Microsoft User Data/Saved Attachments" "Outlook Saved Attachments"
		RemoveUserComponent "Documents/Microsoft User Data/Outlook Sound Sets" "Outlook Sound Sets"
	else
		PreserveUserComponent "Documents/Microsoft User Data/Office 2011 Identities" "Outlook Identities and Databases"
		PreserveUserComponent "Documents/Microsoft User Data/Saved Attachments" "Outlook Saved Attachments"
		PreserveUserComponent "Documents/Microsoft User Data/Outlook Sound Sets" "Outlook Sound Sets"
	fi
	# Remove Office 2011 package receipts
	Remove2011Receipts
	# Clean up icons on the dock
	CleanDock
	# Restart cfprefs
	RelaunchCFPrefs
}

## Main
LogMessage "Starting $SCRIPT_NAME"
AllMessage "${TEXT_BLUE}=== $TOOL_NAME $TOOL_VERSION ===${TEXT_NORMAL}"
LogDevice

# Evaluate command-line arguments
if [[ $# = 0 ]]; then
	LogMessage "No command-line arguments passed, going into interactive mode"
	MainLoop
else
	LogMessage "Command-line arguments passed, attempting to parse"
	while [[ $# > 0 ]]
	do
	key="$1"
	LogMessage "Argument: $key"
	case "$key" in
    	--Help|-h|--help)
    	ShowUsage
    	exit 0
	shift # past argument
    	;;
    	--Force|-f|--force)
    	LogMessage "Force mode set to TRUE"
    	FORCE_PERM=true
    	shift # past argument
    	;;
    	--KeepLync|-k|--keeplync)
    	LogMessage "Keep Lync set to TRUE"
    	KEEP_LYNC=true
    	shift # past argument
    	;;
    	--SaveLicense|-s|--savelicense)
    	LogMessage "SaveLicense set to TRUE"
    	SAVE_LICENSE=true
    	shift # past argument
    	;;
    	*)
    	ShowUsage
    	echo "Ignoring unrecognized argument: $key"
    	;;
	esac
	shift # past argument or value
	done
	MainLoop
fi

ConsoleMessage ""
ConsoleMessage "All events and errors were logged to $LOG_FILE"
ConsoleMessage ""
LogMessage "Exiting script"
exit 0