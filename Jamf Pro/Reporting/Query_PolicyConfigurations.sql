# Queries on Policy Configurations
# Most of these should be working, but some may still be a work in progress.
# These are formatted for readability, just fyi.

##################################################
## Basic Queries

# Get Policies that Execute @ Ongoing
select policy_id from policies where execution_frequency like "Ongoing";


# Policies with no Scope
select distinct policies.policy_id, policies.name
from policies 
where policies.policy_id not in ( select policy_id from policy_deployment );


# Policies that are Disabled
select distinct policies.policy_id, policies.name
from policies 
where policies.enabled != "1";


# Policies with no Category and not created by Jamf Remote
select distinct policies.policy_id, policies.name, policies.use_for_self_service
from policies 
where
policies.category_id = "-1" and policies.created_by = "jss";


# Policies Scoped to All Users
select distinct policies.policy_id, policies.name
from policies
join policy_deployment on policy_deployment.policy_id = policies.policy_id
join site_objects on site_objects.object_id = policies.policy_id
join sites on sites.site_id = site_objects.site_id
where policy_deployment.target_type = "106";


# For every Policy ID, get its Site Name (this does not get Policies that are scoped to "None" Site)
select policies.policy_id, sites.site_name
from policies
join site_objects on site_objects.object_id = policies.policy_id
join sites on sites.site_id = site_objects.site_id
where site_objects.object_type = "3";


##################################################
## Self Service Policies

# Get Policies that are set for Self Service
select policy_id from policies where use_for_self_service = 1;


# Self Service Policies with no Description
select policies.policy_id, policies.name, sites.site_name
from policies 
join site_objects on site_objects.object_id = policies.policy_id
join sites on sites.site_id = site_objects.site_id
where policies.use_for_self_service = 1 
and
    policies.self_service_description = ""
and
    policies.policy_id = site_objects.object_id
and
    site_objects.object_type = "3";


# Self Service Policies with no Icon
select policies.policy_id, policies.name, sites.site_name
from policies 
join site_objects on site_objects.object_id = policies.policy_id
join sites on sites.site_id = site_objects.site_id
where policies.use_for_self_service = 1 
and
    policies.self_service_description = ""
and
    policies.policy_id = site_objects.object_id
and
    site_objects.object_type = "3";


# Get every Policy ID and Name that is Self Service and installs a Package (Also get each Package ID and Name)
select distinct policies.policy_id, policies.name, policy_packages.package_id, packages.package_name
from policies 
join policy_packages on policy_packages.policy_id = policies.policy_id
join packages on policy_packages.package_id = packages.package_id
where policies.use_for_self_service = 1;


# Site Self Service Policies that install packages
select distinct policy_packages.policy_id, policies.name, policy_packages.package_id, packages.package_name, sites.site_name
from policies 
join policy_packages on policy_packages.policy_id = policies.policy_id
join packages on policy_packages.package_id = packages.package_id
join site_objects on site_objects.object_id = policies.policy_id
join sites on sites.site_id = site_objects.site_id
where policies.use_for_self_service = 1
and policies.policy_id = site_objects.object_id
and site_objects.object_type = "3";


# "None" Site Self Service Policies that install packages
select distinct policy_packages.policy_id, policies.name, policy_packages.package_id, packages.package_name
from policies 
join policy_packages on policy_packages.policy_id = policies.policy_id
join packages on policy_packages.package_id = packages.package_id
join site_objects on site_objects.object_id = policies.policy_id
where policies.use_for_self_service = 1
and policies.policy_id not in ( select site_objects.object_id from site_objects where site_objects.object_type = "3");


##################################################
## Inventory Policies

# Get Policies that submitted Inventory within the last 24 hours, get and order by count.
select policy_history.policy_id, policies.name, count(*)
from policy_history
join policies on policies.policy_id = policy_history.policy_id
where
    policy_history.completed_epoch>unix_timestamp(date_sub(now(), interval 1 day))*1000 
and 
    policy_history.policy_id IN
        (select policies.policy_id from policies where update_inventory = 1)
group by policy_history.policy_id order by Count(*) asc;


###  NOT WORKING ###
select policy_history.policy_id, policies.name, sites.site_name, count(*)
from policy_history
join policies on policies.policy_id = policy_history.policy_id
join site_objects on site_objects.object_id = policies.policy_id
join sites on sites.site_id = site_objects.site_id
where
    policy_history.completed_epoch>unix_timestamp(date_sub(now(), interval 1 day))*1000 
and 
    policy_history.policy_id IN
        (select policies.policy_id from policies where update_inventory = 1)
and
    (policies.policy_id = site_objects.object_id
        and site_objects.object_type = "3")
group by policy_history.policy_id order by Count(*) asc;


##################################################
## Site Policies @ Ongoing that install packages

select distinct policy_packages.policy_id, policies.name, policy_packages.package_id, packages.package_name, sites.site_name, policy_deployment.target_id
from policies 
join policy_packages on policy_packages.policy_id = policies.policy_id
join packages on policy_packages.package_id = packages.package_id
join policy_deployment on policy_deployment.policy_id = policies.policy_id
join site_objects on site_objects.object_id = policies.policy_id
join sites on sites.site_id = site_objects.site_id
where policies.execution_frequency = "Ongoing"
and (
	policies.trigger_event_startup = "1"
	or policies.trigger_event_login = "1"
	or policies.trigger_event_logout = "1"
	or policies.trigger_event_network_state_change = "1"
	or policies.trigger_event_checkin = "1"
)
and (
	policies.policy_id = policy_deployment.policy_id
	and policy_deployment.target_type = "7"
)
and (
	policies.policy_id = site_objects.object_id
	and site_objects.object_type = "3"
);


# Policies set at Ongoing for all Events (except Enrollment) installing Software that are Scoped that is not a Smart Group
select distinct policy_packages.policy_id, policies.name, policy_packages.package_id, packages.package_name, sites.site_name, computer_groups.computer_group_id, computer_groups.computer_group_name
from policies 
join policy_packages on policy_packages.policy_id = policies.policy_id
join packages on policy_packages.package_id = packages.package_id
join policy_deployment on policy_deployment.policy_id = policies.policy_id
join computer_groups on computer_groups.computer_group_id = policy_deployment.target_id
join smart_computer_group_criteria on smart_computer_group_criteria.computer_group_id = computer_groups.computer_group_id
join site_objects on site_objects.object_id = policies.policy_id
join sites on sites.site_id = site_objects.site_id
where policies.execution_frequency = "Ongoing"
and (
	policies.trigger_event_startup = "1"
	or policies.trigger_event_login = "1"
	or policies.trigger_event_logout = "1"
	or policies.trigger_event_network_state_change = "1"
	or policies.trigger_event_checkin = "1"
)
and (
	policies.policy_id = policy_deployment.policy_id
	and policy_deployment.target_type = "7"
	and policy_deployment.target_id in ( select computer_group_id from computer_groups where computer_groups.is_smart_group != 1 )
)
and (
	policies.policy_id = site_objects.object_id
	and site_objects.object_type = "3"
);


# Policies set at Ongoing for all Events (except Enrollment) installing Software that are Scoped to All Computers
select distinct policy_packages.policy_id, policies.name, policy_packages.package_id, packages.package_name, sites.site_name
from policies 
join policy_packages on policy_packages.policy_id = policies.policy_id
join packages on policy_packages.package_id = packages.package_id
join policy_deployment on policy_deployment.policy_id = policies.policy_id
join site_objects on site_objects.object_id = policies.policy_id
join sites on sites.site_id = site_objects.site_id
where policies.execution_frequency = "Ongoing"
and (
	policies.trigger_event_startup = "1"
	or policies.trigger_event_login = "1"
	or policies.trigger_event_logout = "1"
	or policies.trigger_event_network_state_change = "1"
	or policies.trigger_event_checkin = "1"
)and (
	policies.policy_id = policy_deployment.policy_id
	and policy_deployment.target_type = "101"
)
and (
	policies.policy_id = site_objects.object_id
	and site_objects.object_type = "3"
);


##################################################
## Enrollment Policies that install Software that are scoped to DEP machines

# Enrollment Policies installing Software that are Scoped to All Computers
select distinct policy_packages.policy_id, policies.name, policy_packages.package_id, packages.package_name, sites.site_name
from policies 
join policy_packages on policy_packages.policy_id = policies.policy_id
join packages on policy_packages.package_id = packages.package_id
join policy_deployment on policy_deployment.policy_id = policies.policy_id
join site_objects on site_objects.object_id = policies.policy_id
join sites on sites.site_id = site_objects.site_id
where policies.trigger_event_enrollment_complete = "1"
and (
	policies.policy_id = policy_deployment.policy_id
	and policy_deployment.target_type = "101"
)
and (
	policies.policy_id = site_objects.object_id
	and site_objects.object_type = "3"
);


# Enrollment Policies installing Software that are Scoped to a Smart Group (Not DEP Enrolled Machines)
select distinct policy_packages.policy_id, policies.name, policy_packages.package_id, packages.package_name, sites.site_name, computer_groups.computer_group_id, computer_groups.computer_group_name
from policies 
join policy_packages on policy_packages.policy_id = policies.policy_id
join packages on policy_packages.package_id = packages.package_id
join policy_deployment on policy_deployment.policy_id = policies.policy_id
join computer_groups on computer_groups.computer_group_id = policy_deployment.target_id
join smart_computer_group_criteria on smart_computer_group_criteria.computer_group_id = computer_groups.computer_group_id
join site_objects on site_objects.object_id = policies.policy_id
join sites on sites.site_id = site_objects.site_id
where policies.trigger_event_enrollment_complete = "1"
and (
	policies.policy_id = policy_deployment.policy_id
	and policy_deployment.target_type = "7"
	and policy_deployment.target_id in (select computer_group_id from computer_groups where computer_groups.is_smart_group = 1 )
)
and (
	policy_deployment.target_id in ( select computer_group_id from smart_computer_group_criteria where search_field != "Enrollment Method: PreStage enrollment")
)
and (
	policies.policy_id = site_objects.object_id
	and site_objects.object_type = "3"
);


# Enrollment Policies installing Software that are Scoped to DEP Enrolled Machines
select distinct policy_packages.policy_id, policies.name, policy_packages.package_id, packages.package_name, sites.site_name, computer_groups.computer_group_id, computer_groups.computer_group_name
from policies 
join policy_packages on policy_packages.policy_id = policies.policy_id
join packages on policy_packages.package_id = packages.package_id
join policy_deployment on policy_deployment.policy_id = policies.policy_id
join computer_groups on computer_groups.computer_group_id = policy_deployment.target_id
join smart_computer_group_criteria on smart_computer_group_criteria.computer_group_id = computer_groups.computer_group_id
join site_objects on site_objects.object_id = policies.policy_id
join sites on sites.site_id = site_objects.site_id
where policies.trigger_event_enrollment_complete = "1"
and (
	policies.policy_id = policy_deployment.policy_id
	and policy_deployment.target_type = "7"
	and policy_deployment.target_id in (select computer_group_id from computer_groups where computer_groups.is_smart_group = 1 )
)
and (
	policy_deployment.target_id in ( select computer_group_id from smart_computer_group_criteria where search_field = "Enrollment Method: PreStage enrollment")
)
and (
	policies.policy_id = site_objects.object_id
	and site_objects.object_type = "3"
);
