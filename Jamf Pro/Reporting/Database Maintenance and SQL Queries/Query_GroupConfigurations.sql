# Queries on Group Configurations
# Most of these should be working, but some may still be a work in progress.
# These are formatted for readability, just fyi.

##################################################
## Computer Groups

# Unused Computer Groups
select distinct computer_groups.computer_group_id, computer_groups.computer_group_name
from computer_groups
where computer_groups.computer_group_id not in
( select target_id from policy_deployment where policy_deployment.target_id = computer_groups.computer_group_id and policy_deployment.target_type = "7" )
and computer_groups.computer_group_id not in 
( select target_id from os_x_configuration_profile_deployment where os_x_configuration_profile_deployment.target_id = computer_groups.computer_group_id and os_x_configuration_profile_deployment.target_type = "7" );


# Empty Computer Groups
select distinct computer_groups.computer_group_id, computer_groups.computer_group_name
from computer_groups
where computer_groups.computer_group_id not in
( select computer_group_id from computer_group_memberships );


# Computer Groups with no defined Criteria
select distinct computer_groups.computer_group_id, computer_groups.computer_group_name
from computer_groups
where computer_groups.is_smart_group = "1"
and computer_groups.computer_group_id not in
( select computer_group_id from smart_computer_group_criteria );


##################################################
## Computer Groups

# Unused Mobile Device Groups
select distinct mobile_device_groups.mobile_device_group_id, mobile_device_groups.mobile_device_group_name
from mobile_device_groups 
where mobile_device_groups.mobile_device_group_id not in
( select target_id from policy_deployment where policy_deployment.target_id = mobile_device_groups.mobile_device_group_id and policy_deployment.target_type = "7" )
and  mobile_device_groups.mobile_device_group_id not in 
( select target_id from mobile_device_configuration_profile_deployment where mobile_device_configuration_profile_deployment.target_id = mobile_device_groups.mobile_device_group_id and mobile_device_configuration_profile_deployment.target_type = "7" );


# Empty Mobile Device Groups
select distinct mobile_device_groups.mobile_device_group_id, mobile_device_groups.mobile_device_group_name
from mobile_device_groups 
where mobile_device_groups.mobile_device_group_id not in
( select mobile_device_group_id from mobile_device_group_memberships );


# Mobile Device Groups with no defined Criteria
select distinct mobile_device_groups.mobile_device_group_id, mobile_device_groups.mobile_device_group_name
from mobile_device_groups 
where mobile_device_groups.is_smart_group = "1"
and mobile_device_groups.mobile_device_group_id not in
( select mobile_device_group_id from smart_mobile_device_group_criteria );
