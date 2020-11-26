-- Queries on Policy Configurations
-- Most of these should be working, but some may still be a work in progress.
-- These are formatted for readability, just fyi.

-- ##################################################
-- Basic Queries

-- Get Policies that Execute @ Ongoing
select policy_id 
from policies 
where 
execution_frequency like "Ongoing";


-- Policies with no Scope
select distinct policies.policy_id, policies.name
from policies 
where policies.policy_id not in ( 
	select policy_id from policy_deployment 
	);


-- Policies that are Disabled
select distinct policies.policy_id, policies.name
from policies 
where policies.enabled != "1";


-- Policies with no Category and not created by Jamf Remote
select distinct policies.policy_id, policies.name, policies.use_for_self_service
from policies 
where
	policies.category_id = "-1" 
	and policies.created_by = "jss";


-- Policies Scoped to All Users
select distinct policies.policy_id, policies.name
from policies
join policy_deployment 
	on policy_deployment.policy_id = policies.policy_id
join site_objects 
	on site_objects.object_id = policies.policy_id
join sites 
	on sites.site_id = site_objects.site_id
where 
	policy_deployment.target_type = "106";


-- For every Policy ID, get its Site Name
select policies.policy_id, if(sites.site_name is null, "none", sites.site_name) as Site
from policies
left join site_objects 
	on policies.policy_id = site_objects.object_id 
		and site_objects.object_type = "3"
left join sites 
	on sites.site_id = site_objects.site_id;


-- ##################################################
-- Self Service Policies

-- Get Policies are report if they are set for Self Service and if have a Description and Icon and include it's Site
select policies.policy_id as "Policy ID", policies.name as "Policy Name", if(sites.site_name is null, "none", sites.site_name) as Site, if(policies.use_for_self_service = "1", "Yes", "No") as "Self Service", if(policies.self_service_description = "", "No", "Yes") as "Has Description", if(policies.self_service_icon_id = "-1", "No", "Yes") as "Has Icon",
from policies
left join site_objects 
	on policies.policy_id = site_objects.object_id 
		and site_objects.object_type = "3"
left join sites 
	on sites.site_id = site_objects.site_id;


-- Get Self Service Policies that install a Package (Also get each Package ID and Name)
select policies.policy_id as "Policy ID", policies.name as "Policy Name", if(sites.site_name is null, "none", sites.site_name) as Site, policy_packages.package_id as "Package ID" , packages.package_name as "Package Name"
from policies
join policy_packages 
	on policy_packages.policy_id = policies.policy_id
join packages 
	on policy_packages.package_id = packages.package_id
left join site_objects 
	on policies.policy_id = site_objects.object_id 
		and site_objects.object_type = "3"
left join sites 
	on sites.site_id = site_objects.site_id
where 
	policies.use_for_self_service = 1;


-- ##################################################
-- Policies ran over time period

-- Get Policies that ran within the last 24 hours, get and order by count
select policies.policy_id as "Policy ID", policies.name as "Policy Name", if(sites.site_name is null, "none", sites.site_name) as Site, count(*)
from policies
left join site_objects 
	on policies.policy_id = site_objects.object_id 
		and site_objects.object_type = "3"
left join sites 
	on sites.site_id = site_objects.site_id
join policy_history 
	on policy_history.policy_id = policies.policy_id
where
    policy_history.completed_epoch>unix_timestamp(date_sub(now(), interval 1 day))*1000 
group by policy_history.policy_id, sites.site_name 
order by Count(*) desc;


-- Get Policies that submitted Inventory within the last 24 hours, get and order by count
select policies.policy_id as "Policy ID", policies.name as "Policy Name", if(sites.site_name is null, "none", sites.site_name) as Site, count(*)
from policies
left join site_objects 
	on policies.policy_id = site_objects.object_id 
		and site_objects.object_type = "3"
left join sites 
	on sites.site_id = site_objects.site_id
join policy_history 
	on policy_history.policy_id = policies.policy_id
where 
	policy_history.completed_epoch>unix_timestamp(date_sub(now(), interval 1 day))*1000 
	and policies.update_inventory = 1
group by policy_history.policy_id, sites.site_name 
order by Count(*) desc;


-- Get Policies that have ran witin the last 24 hours, if they perform inventory, have errors, and their Site, and group/count the occurences
select policies.policy_id as "Policy ID", policies.name as "Policy Name", if(sites.site_name is null, "none", sites.site_name) as Site, if(policies.update_inventory = "1", "Yes", "No") as "Update Inventory?", logs.error as "Errors", count(*)
from policies
left join site_objects 
	on policies.policy_id = site_objects.object_id 
		and site_objects.object_type = "3"
left join sites 
	on sites.site_id = site_objects.site_id
join policy_history 
	on policy_history.policy_id = policies.policy_id
join logs 
	on logs.log_id = policy_history.log_id
where 
	policy_history.completed_epoch > unix_timestamp(date_sub(now(), INTERVAL 1 DAY))*1000
group by policies.policy_id, sites.site_name, logs.error 
order by count(*) desc;


-- ##################################################
-- Mash up of other queries

-- Get various Policies details of interest, including if they perform inventory, have errors, and their Site, and group/count the occurences
select count(*), policies.policy_id as "Policy ID", policies.name as "Policy Name", if(sites.site_name is null, "none", sites.site_name) as Site, if(policies.enabled = "1", "Yes", "No") as "Enabled", if(policies.update_inventory = "1", "Yes", "No") as "Update Inventory?", logs.error as "Errors", if(policies.use_for_self_service = "1", "Yes", "No") as "Self Service", if(policies.self_service_description = "", "No", "Yes") as "Has Description", if(policies.self_service_icon_id = "-1", "No", "Yes") as "Has Icon", if(policies.category_id = "-1" and policies.created_by = "jss", "No", "Yes") as "Has Category", if( policies.policy_id not in ( select policy_id from policy_deployment ), "False", "True") as "Has Scope"
from policies
left join site_objects 
	on policies.policy_id = site_objects.object_id 
		and site_objects.object_type = "3"
left join sites 
	on sites.site_id = site_objects.site_id
join policy_history 
	on policy_history.policy_id = policies.policy_id
join logs 
	on logs.log_id = policy_history.log_id
group by policies.policy_id, sites.site_name, logs.error 
order by count(*) desc


-- ##################################################
-- Policies that are configured for Ongoing with any "reoccuring" trigger and installs a Package

-- Get Policies that are configured for Ongoing with any "reoccuring" trigger and installs a Package (Also get each Package ID and Name)
select distinct policies.policy_id as "Policy ID", policies.name as "Policy Name", if(sites.site_name is null, "none", sites.site_name) as Site, packages.package_id as "Package ID" , packages.package_name as "Package Name"
from policies
join policy_packages 
	on policy_packages.policy_id = policies.policy_id
join packages 
	on policy_packages.package_id = packages.package_id
join policy_deployment 
	on policy_deployment.policy_id = policies.policy_id
left join site_objects 
	on policies.policy_id = site_objects.object_id 
		and site_objects.object_type = "3"
left join sites 
	on sites.site_id = site_objects.site_id
where 
	policies.execution_frequency = "Ongoing"
	and (
		policies.trigger_event_startup = "1"
		or policies.trigger_event_login = "1"
		or policies.trigger_event_logout = "1"
		or policies.trigger_event_network_state_change = "1"
		or policies.trigger_event_checkin = "1"
	);


-- Get Policies that are configured for Ongoing with any "reoccuring" trigger and installs a Package which has a Scope that is not a Smart Group (Also get each Package ID and Name)
-- Need to add if scoped to Computer IDs directly
-- This query needs verification
select distinct policies.policy_id as "Policy ID", policies.name as "Policy Name", if(sites.site_name is null, "none", sites.site_name) as Site, packages.package_id as "Package ID" , packages.package_name as "Package Name", computer_groups.computer_group_id as "Group ID", computer_groups.computer_group_name as "Group Name"
from policies
join policy_packages 
	on policy_packages.policy_id = policies.policy_id
join packages 
	on policy_packages.package_id = packages.package_id
join policy_deployment 
	on policy_deployment.policy_id = policies.policy_id
left join site_objects 
	on policies.policy_id = site_objects.object_id 
		and site_objects.object_type = "3"
left join sites 
	on sites.site_id = site_objects.site_id
left join computer_groups 
	on computer_groups.computer_group_id = policy_deployment.target_id
left join smart_computer_group_criteria 
	on smart_computer_group_criteria.computer_group_id = computer_groups.computer_group_id
where 
	policies.execution_frequency = "Ongoing"
	and (
		policies.trigger_event_startup = "1"
		or policies.trigger_event_login = "1"
		or policies.trigger_event_logout = "1"
		or policies.trigger_event_network_state_change = "1"
		or policies.trigger_event_checkin = "1"
	)
	and (
		policy_deployment.target_type = "101"
		or policy_deployment.target_type = "7"
		and policy_deployment.target_id in ( 
			select computer_group_id 
			from computer_groups 
			where computer_groups.is_smart_group != 1 
		)
	);


-- ##################################################
-- Enrollment Policies that install Packages

-- Enrollment Policies installing Packages that are Scoped to All Computers
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


-- Get Policies that are configured for Enrollment and installs a Package which has a Scope Smart Group that is Not ADE Enrolled Machines
select distinct policies.policy_id as "Policy ID", policies.name as "Policy Name", if(sites.site_name is null, "none", sites.site_name) as Site, computer_groups.computer_group_id as "Group ID", computer_groups.computer_group_name as "Group Name"
from policies
join policy_deployment 
	on policy_deployment.policy_id = policies.policy_id
left join site_objects 
	on policies.policy_id = site_objects.object_id 
		and site_objects.object_type = "3"
left join sites 
	on sites.site_id = site_objects.site_id
join computer_groups 
	on computer_groups.computer_group_id = policy_deployment.target_id
join smart_computer_group_criteria 
	on smart_computer_group_criteria.computer_group_id = computer_groups.computer_group_id
where 
	policies.trigger_event_enrollment_complete = "1"
	AND (
		policy_deployment.target_type = "7"
		AND policy_deployment.target_id IN (  
				SELECT computer_group_id 
				FROM computer_groups 
				WHERE computer_groups.is_smart_group = 1 
			)
		AND policy_deployment.target_id IN
			(
				SELECT computer_group_id 
				FROM smart_computer_group_criteria 
				WHERE search_field != "Enrollment Method: PreStage enrollment"
			)
	);


-- Get Policies that are configured for Enrollment and installs a Package which has a Scope Smart Group that is ADE Enrolled Machines
select distinct policies.policy_id as "Policy ID", policies.name as "Policy Name", if(sites.site_name is null, "none", sites.site_name) as Site, computer_groups.computer_group_id as "Group ID", computer_groups.computer_group_name as "Group Name"
from policies
join policy_deployment 
	on policy_deployment.policy_id = policies.policy_id
left join site_objects 
	on policies.policy_id = site_objects.object_id 
		and site_objects.object_type = "3"
left join sites 
	on sites.site_id = site_objects.site_id
join computer_groups 
	on computer_groups.computer_group_id = policy_deployment.target_id
join smart_computer_group_criteria 
	on smart_computer_group_criteria.computer_group_id = computer_groups.computer_group_id
where 
	policies.trigger_event_enrollment_complete = "1"
	AND (
		policy_deployment.target_type = "7"
		AND policy_deployment.target_id IN (  
				SELECT computer_group_id 
				FROM computer_groups 
				WHERE computer_groups.is_smart_group = 1 
			)
		AND policy_deployment.target_id IN
			(
				SELECT computer_group_id 
				FROM smart_computer_group_criteria 
				WHERE search_field = "Enrollment Method: PreStage enrollment"
			)
	);
