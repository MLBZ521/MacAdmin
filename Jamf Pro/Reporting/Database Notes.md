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
    * 1 = computers
    * 3 = policy
    * 21 = mobile devices
  * object_id = computer_id/mobile_device_id/policy_id from their respected **table**
  * site_id = sites.site_id


Table:  sites
  * site_id
  * site_name


Table:  policy_deployment
  * policy_id
  * target_type
    * 1 =
    * 7 = Computer Group?
    * 42 =
    * 51 = 
    * 52 = LDAP Group
    * 53 = 
    * 101 = All Computers
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

