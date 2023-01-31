-- Queries on Policy Configurations
-- These are formatted for readability, just fyi.

-- ##################################################
-- Basic Queries

-- Get Policies that Execute @ Ongoing
SELECT policy_id
FROM policies
WHERE
execution_frequency LIKE "Ongoing";


-- Policies with no Scope
SELECT DISTINCT policies.policy_id, policies.name
FROM policies
WHERE policies.policy_id NOT IN (
	SELECT policy_id FROM policy_deployment
);


-- Policies that are Disabled
SELECT DISTINCT policies.policy_id, policies.name
FROM policies
WHERE policies.enabled != "1";


-- Policies with no Category and not created by Jamf Remote
SELECT DISTINCT policies.policy_id, policies.name, policies.use_for_self_service
FROM policies
WHERE
	policies.category_id = "-1"
	AND policies.created_by = "jss";


-- Policies Scoped to All Users
SELECT DISTINCT policies.policy_id, policies.name
FROM policies
JOIN policy_deployment
	ON policy_deployment.policy_id = policies.policy_id
JOIN site_objects
	ON site_objects.object_id = policies.policy_id
JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE
	policy_deployment.target_type = "106";


-- For every Policy ID, get its Site Name
SELECT
	policies.policy_id,
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site"
FROM policies
LEFT JOIN site_objects
	ON policies.policy_id = site_objects.object_id
		AND site_objects.object_type = "3"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id;


-- ##################################################
-- Self Service Policies

-- Get Policies are report if they are set for Self Service and if have a Description and Icon and include it's Site
SELECT
	policies.policy_id AS "Policy ID",
	policies.name AS "Policy Name",
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	IF(policies.use_for_self_service = "1", "Yes", "No") AS "Self Service",
	IF(policies.self_service_description = "", "No", "Yes") AS "Has Description",
	IF(policies.self_service_icon_id = "-1", "No", "Yes") AS "Has Icon"
FROM policies
LEFT JOIN site_objects
	ON policies.policy_id = site_objects.object_id
		AND site_objects.object_type = "3"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id;


-- Get Self Service Policies that install a Package (Also get each Package ID and Name)
SELECT
	policies.policy_id AS "Policy ID",
	policies.name AS "Policy Name",
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	policy_packages.package_id AS "Package ID",
	packages.package_name AS "Package Name"
FROM policies
JOIN policy_packages
	ON policy_packages.policy_id = policies.policy_id
JOIN packages
	ON policy_packages.package_id = packages.package_id
LEFT JOIN site_objects
	ON policies.policy_id = site_objects.object_id
		AND site_objects.object_type = "3"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE
	policies.use_for_self_service = 1;


-- ##################################################
-- Policies ran over time period

-- Get Policies that ran within the last 24 hours, get and order by count
SELECT
	policies.policy_id AS "Policy ID",
	policies.name AS "Policy Name",
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	COUNT(*)
FROM policies
LEFT JOIN site_objects
	ON policies.policy_id = site_objects.object_id
		AND site_objects.object_type = "3"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
JOIN policy_history
	ON policy_history.policy_id = policies.policy_id
WHERE
	policy_history.completed_epoch>unix_timestamp(date_sub(NOW(), interval 1 day))*1000
GROUP BY policy_history.policy_id, sites.site_name
ORDER BY COUNT(*) DESC;


-- Get Policies that submitted Inventory within the last 24 hours, get and order by count
SELECT
	policies.policy_id AS "Policy ID",
	policies.name AS "Policy Name",
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	COUNT(*)
FROM policies
LEFT JOIN site_objects
	ON policies.policy_id = site_objects.object_id
		AND site_objects.object_type = "3"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
JOIN policy_history
	ON policy_history.policy_id = policies.policy_id
WHERE
	policy_history.completed_epoch>unix_timestamp(date_sub(NOW(), interval 1 day))*1000
	AND policies.update_inventory = 1
GROUP BY policy_history.policy_id, sites.site_name
ORDER BY COUNT(*) DESC;


-- Get Policies that have ran witin the last 24 hours, if they perform inventory, have errors, and their Site, and group/count the occurences
SELECT
	policies.policy_id AS "Policy ID",
	policies.name AS "Policy Name",
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	IF(policies.update_inventory = "1", "Yes", "No") AS "Update Inventory?",
	logs.error AS "Errors", COUNT(*)
FROM policies
LEFT JOIN site_objects
	ON policies.policy_id = site_objects.object_id
		AND site_objects.object_type = "3"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
JOIN policy_history
	ON policy_history.policy_id = policies.policy_id
JOIN logs
	ON logs.log_id = policy_history.log_id
WHERE
	policy_history.completed_epoch > unix_timestamp(date_sub(NOW(), INTERVAL 1 DAY))*1000
GROUP BY policies.policy_id, sites.site_name, logs.error
ORDER BY COUNT(*) DESC;


-- ##################################################
-- Mash up of other queries

-- Get various Policies details of interest, including if they perform inventory, have errors, and their Site, and group/count the occurences
SELECT
	COUNT(*),
	policies.policy_id AS "Policy ID",
	policies.name AS "Policy Name",
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	IF(policies.enabled = "1", "Yes", "No") AS "Enabled",
	IF(policies.update_inventory = "1", "Yes", "No") AS "Update Inventory?",
	logs.error AS "Errors",
	IF(policies.use_for_self_service = "1", "Yes", "No") AS "Self Service",
	IF(policies.self_service_description = "", "No", "Yes") AS "Has Description",
	IF(policies.self_service_icon_id = "-1", "No", "Yes") AS "Has Icon",
	IF(policies.category_id = "-1" AND policies.created_by = "jss", "No", "Yes") AS "Has Category",
	IF(policies.policy_id NOT IN ( SELECT policy_id FROM policy_deployment ), "False", "True") AS "Has Scope"
FROM policies
LEFT JOIN site_objects
	ON policies.policy_id = site_objects.object_id
		AND site_objects.object_type = "3"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
JOIN policy_history
	ON policy_history.policy_id = policies.policy_id
JOIN logs
	ON logs.log_id = policy_history.log_id
GROUP BY policies.policy_id, sites.site_name, logs.error
ORDER BY COUNT(*) DESC


-- ##################################################
-- Policies that are configured for Ongoing with any "reoccuring" trigger and installs a Package

-- Get Policies that are configured for Ongoing with any "reoccuring" trigger and installs a Package (Also get each Package ID and Name)
SELECT DISTINCT
	policies.policy_id AS "Policy ID",
	policies.name AS "Policy Name",
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	packages.package_id AS "Package ID" ,
	packages.package_name AS "Package Name"
FROM policies
JOIN policy_packages
	ON policy_packages.policy_id = policies.policy_id
JOIN packages
	ON policy_packages.package_id = packages.package_id
JOIN policy_deployment
	ON policy_deployment.policy_id = policies.policy_id
LEFT JOIN site_objects
	ON policies.policy_id = site_objects.object_id
		AND site_objects.object_type = "3"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE
	policies.execution_frequency = "Ongoing"
	AND (
		policies.trigger_event_startup = "1"
		OR policies.trigger_event_login = "1"
		OR policies.trigger_event_logout = "1"
		OR policies.trigger_event_network_state_change = "1"
		OR policies.trigger_event_checkin = "1"
	);


-- Get Policies that are configured for Ongoing with any "reoccuring" trigger and installs a Package which has a Scope that is not a Smart Group (Also get each Package ID and Name)
-- Need to add if scoped to Computer IDs directly
-- This query needs verification
SELECT DISTINCT
	policies.policy_id AS "Policy ID",
	policies.name AS "Policy Name",
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	packages.package_id AS "Package ID" ,
	packages.package_name AS "Package Name",
	computer_groups.computer_group_id AS "Group ID",
	computer_groups.computer_group_name AS "Group Name"
FROM policies
JOIN policy_packages
	ON policy_packages.policy_id = policies.policy_id
JOIN packages
	ON policy_packages.package_id = packages.package_id
JOIN policy_deployment
	ON policy_deployment.policy_id = policies.policy_id
LEFT JOIN site_objects
	ON policies.policy_id = site_objects.object_id
		AND site_objects.object_type = "3"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
LEFT JOIN computer_groups
	ON computer_groups.computer_group_id = policy_deployment.target_id
LEFT JOIN smart_computer_group_criteria
	ON smart_computer_group_criteria.computer_group_id = computer_groups.computer_group_id
WHERE
	policies.execution_frequency = "Ongoing"
	AND (
		policies.trigger_event_startup = "1"
		OR policies.trigger_event_login = "1"
		OR policies.trigger_event_logout = "1"
		OR policies.trigger_event_network_state_change = "1"
		OR policies.trigger_event_checkin = "1"
	)
	AND (
		policy_deployment.target_type = "101"
		OR policy_deployment.target_type = "7"
		AND policy_deployment.target_id IN (
			SELECT computer_group_id
			FROM computer_groups
			WHERE computer_groups.is_smart_group != 1
		)
	);


-- ##################################################
-- Enrollment Policies that install Packages

-- Enrollment Policies installing Packages that are Scoped to All Computers
SELECT DISTINCT
	policies.policy_id AS "Policy ID",
	policies.name AS "Policy Name",
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	packages.package_id AS "Package ID" ,
	packages.package_name AS "Package Name",
FROM policies
JOIN policy_packages ON policy_packages.policy_id = policies.policy_id
JOIN packages ON policy_packages.package_id = packages.package_id
JOIN policy_deployment ON policy_deployment.policy_id = policies.policy_id
JOIN site_objects ON site_objects.object_id = policies.policy_id
JOIN sites ON sites.site_id = site_objects.site_id
WHERE policies.trigger_event_enrollment_complete = "1"
AND (
	policies.policy_id = policy_deployment.policy_id
	AND policy_deployment.target_type = "101"
)
AND (
	policies.policy_id = site_objects.object_id
	AND site_objects.object_type = "3"
);


-- Get Policies that are configured for Enrollment and installs a Package which has a Scope Smart Group that is Not ADE Enrolled Machines
SELECT DISTINCT
	policies.policy_id AS "Policy ID",
	policies.name AS "Policy Name",
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	computer_groups.computer_group_id AS "Group ID",
	computer_groups.computer_group_name AS "Group Name"
FROM policies
JOIN policy_deployment
	ON policy_deployment.policy_id = policies.policy_id
LEFT JOIN site_objects
	ON policies.policy_id = site_objects.object_id
		AND site_objects.object_type = "3"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
JOIN computer_groups
	ON computer_groups.computer_group_id = policy_deployment.target_id
JOIN smart_computer_group_criteria
	ON smart_computer_group_criteria.computer_group_id = computer_groups.computer_group_id
WHERE
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
SELECT DISTINCT
	policies.policy_id AS "Policy ID",
	policies.name AS "Policy Name",
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	computer_groups.computer_group_id AS "Group ID",
	computer_groups.computer_group_name AS "Group Name"
FROM policies
JOIN policy_deployment
	ON policy_deployment.policy_id = policies.policy_id
LEFT JOIN site_objects
	ON policies.policy_id = site_objects.object_id
		AND site_objects.object_type = "3"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
JOIN computer_groups
	ON computer_groups.computer_group_id = policy_deployment.target_id
JOIN smart_computer_group_criteria
	ON smart_computer_group_criteria.computer_group_id = computer_groups.computer_group_id
WHERE
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
