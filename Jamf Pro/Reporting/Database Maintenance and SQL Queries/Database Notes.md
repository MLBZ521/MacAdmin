Jamf Database Notes
======

These are notes I've recorded for SQL queries that I've written as not everything is available from the API, or simply, a database query is much faster.  Basically, what values mean and what tables other values reference.

Basic format is as follows:

Table:  <name_of_table>
  * column(s)
    * possible values

**Warning:**  these are _notes_ on the Jamf Database.  I'm not responsible for any actions you take based on these notes.  Test everything before running in production.  As Jamf often states, the database is ever evolving and changing.

## Common Values ##

0 = disabled

1 = enabled


## Tables ##

Table:  policies
  * policy_id
  * execution_frequency
    * "Ongoing"
  * trigger_event_startup
  * trigger_event_login
  * trigger_event_logout
  * trigger_event_network_state_change
  * trigger_event_checkin
  * trigger_event_enrollment_complete
  * use_for_self_service
  * self_service_description


Table:  policy_packages
  * policy_id
  * package_id


Table:  site_objects
  * object_type
    * 1 = Computer
    * 2 = Licensed Software
    * 3 = Policy
    * 4 = Computer Configuration Profiles
    * 5 = Restricted Software
    * 7 = Computer Groups
    * 9 = ?
    * 12 = ?
    * 21 = Mobile Device
    * 22 = Mobile Device Configuration Profile
    * 23 = Mobile Device Apps
    * 25 = Mobile Device Groups
    * 27 = Mobile Device Enrollment Profiles
    * 28 = Mobile Device Classes
    * 53 = User
    * 54 = User Group
    * 57 = Advanced Volume Purchasing Content Searches
    * 70 = Advanced Computer Searches
    * 71 = Advanced Mobile Device Searches
    * 84 = Computers Enrollment Invitations
    * 110 = Mobile Devices Enrollment Invitations
    * 252 = VPP Tokens
    * 253 = ?
    * 256 = Users VPP Assignments?
    * 270 = ?
    * 310 = ADE Tokens
    * 312 = Mobile Device PreStage Enrollment Profiles
    * 313 = Computer PreStage Enrollment Profiles
    * 315 = Enrollment customizations
    * 350 = Computer Mac Apps
    * 382 = ?
    * 602 = Patch Management Patch Policies
    * 604 = Patch Management Software Titles
  * object_id = computer_id/mobile_device_id/policy_id from their respected **table**
  * site_id = sites.site_id


Table:  sites
  * site_id
  * site_name


Table:  policy_deployment
  * policy_id
  * target_type
    * 1 = Computer
    * 7 = Computer Group
    * 21 = Mobile Device
    * 25 = Mobile Device Group
    * 41 = Building
    * 42 = Department
    * 51 = LDAP/Local User
    * 52 = LDAP Group
    * 53 = User
    * 101 = All Computers
    * 102 = All Mobile Devices
    * 106 = All Users
  * target_id


Table:  computer_groups
  * computer_group_id
  * computer_group_name
  * is_smart_group
    * 1 = Yes


Table:  smart_computer_group_criteria
  * computer_group_id
  * search_field
    * "Enrollment Method: PreStage enrollment"


Table:  location_history
  * Description:  Holds each submitted record ID of location history, for the specific device, device type, and when it was submitted
  * location_id = individual record of location data


Table:  locations
  * Description:  Holds the data for the submitted data

