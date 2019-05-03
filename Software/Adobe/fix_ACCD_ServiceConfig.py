#!/usr/bin/python

###################################################################################################
# Script Name:  fix_ACCD_ServiceConfig.py
# By:  Zack Thompson / Created:  5/2/2019
# Version:  1.0.0 / Updated:  5/2/2019 / By:  ZT
#
# Description:  This script writes the desired values to the Adobe ServiceConfig.xml file to 
#               resolve common issues with the ACCD.
#
###################################################################################################

import os
import sys
import xml.etree.ElementTree as ET


def createXMLTree_Parent(root, child):
    xml = ET.SubElement(root, child)
    return xml

def createXMLTree_Child(root, child, text):
    xml = ET.SubElement(root,child).text=text
    return xml

def main():

    # Define variables
    adobe_config_path = '/Library/Application Support/Adobe/OOBE/Configs/'
    adobe_config = adobe_config_path + 'ServiceConfig.xml'
    change_made=0

    if os.path.exists(adobe_config):
        print('Config file exists, checking configuration...')

        # Attempt to parse the xml file.
        try:
            contents = ET.parse(adobe_config)
            root = contents.getroot()
        except Exception:
            sys.exit('ERROR:  Unable to parse the ServiceConfig.xml file!')

        # Get the element so we can check if it exists.
        value_AppsPanel = root.find(".panel/[name='AppsPanel']/visible")

        if value_AppsPanel is not None:
            if value_AppsPanel.text == "false":
                print('AppsPanel is hidden, correcting...')
                value_AppsPanel.text = "true"
                change_made=1
        elif root.find(".panel/[name='AppsPanel']") is None:
            print('AppsPanel is not configured, setting proper values...')
            panel = createXMLTree_Parent(root, "panel")
            createXMLTree_Child(panel,"name","AppsPanel")
            createXMLTree_Child(panel,"visible","true")
            change_made=1

        print('AppsPanel visible:  {}'.format(root.find(".panel/[name='AppsPanel']/visible").text))

        # Get the element so we can check if it exists.
        SelfServeInstalls = root.find(".feature/[name='SelfServeInstalls']/enabled")

        if SelfServeInstalls is not None:
            if SelfServeInstalls.text == "false":
                print('SelfServeInstalls is disabled, correcting...')
                SelfServeInstalls.text = "true"
                change_made=1
        elif root.find(".feature/[name='SelfServeInstalls']") is None:
            print('SelfServeInstalls is not configured, setting proper values...')
            feature = createXMLTree_Parent(root, "feature")
            createXMLTree_Child(feature,"name","SelfServeInstalls")
            createXMLTree_Child(feature,"enabled","true")
            change_made=1

        print('SelfServeInstalls enabled:  {}'.format(root.find(".feature/[name='SelfServeInstalls']/enabled").text))

        if change_made == 1:
            try:
                print('Saving configuration...')
                contents.write(adobe_config)
            except Exception:
                sys.exit('ERROR:  Failed to update configuration!')
            print('Result:  Updates made.')
        else:
            print('Result:  No changes made.')

    else:
        print('Config file does not exist.')
        if not os.path.exists(adobe_config_path):
            try:
                print('Creating directory structure...')
                os.makedirs(adobe_config_path, 0755)
            except Exception:
                sys.exit('ERROR:  Failed to create directory structure!')

        try:
            print('Creating configuration file...')
            adobe_config = open(adobe_config, 'a+')
        except Exception:
                sys.exit('ERROR:  Failed to create configuration file!')

        # Create the root element and then build the xml structure.
        root = ET.Element('config')
        panel = createXMLTree_Parent(root, "panel")
        createXMLTree_Child(panel,"name","AppsPanel")
        createXMLTree_Child(panel,"visible","true")
        feature = createXMLTree_Parent(root, "feature")
        createXMLTree_Child(feature,"name","SelfServeInstalls")
        createXMLTree_Child(feature,"enabled","true")
        tree = ET.ElementTree(root)

        try:
            print('Saving configuration to disk...')
            tree.write(adobe_config)
            adobe_config.close()
        except Exception:
            sys.exit('ERROR:  Failed to write configuration file!')

        print('Result:  Updates made.')

if __name__ == "__main__":
    main()
