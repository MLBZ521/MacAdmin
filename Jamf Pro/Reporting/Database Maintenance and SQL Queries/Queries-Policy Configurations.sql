-- Queries on Policy Configurations
-- These are formatted for readability, just fyi.

-- ##################################################
-- Basic Queries

-- Get Policies that Execute @ Ongoing
SELECT policy_id
FROM policies
WHERE execution_frequency = "Ongoing";


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


-- Policies with no configuration and not created by Jamf Remote
SELECT *
FROM policies
WHERE 
    created_by = "jss"
    AND run_swu != 1
    AND file_vault_2_reboot != 1 
    AND update_inventory != 1
    AND fix_permissions != 1
    AND fix_by_host_files != 1
    AND reset_computer_name != 1
    AND search_for_file = "" 
    AND locate_file = ""
    AND search_for_process = ""
    AND spotlight_search = ""
    AND run_command = ""
    AND install_all_cached != 1
    AND flush_system_caches != 1
    AND flush_user_caches != 1
    AND verify_startup_disk != 1
    AND heal != 1
    AND set_of_password != 1
    AND perform_workplace_join != 1
    AND compliance != 1
    AND disk_encryption_action != 1
    AND disk_encryption_id != 4
    AND managed_password_action != "rotate"
    AND policy_id NOT IN ( 
        ( SELECT policy_id FROM policy_packages
        UNION ALL SELECT policy_id FROM policy_accounts
        UNION ALL SELECT policy_id FROM policy_directory_bindings
        UNION ALL SELECT policy_id FROM policy_dock_items
        UNION ALL SELECT policy_id FROM policy_printers
        UNION ALL SELECT policy_id FROM policy_scripts )
    )
;


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

-- Get Policies and report if they are set for Self Service and if they have a Description and Icon and include it's Site
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

-- Get Policies that ran within the last 24 hours, get and order by count.
SELECT
	COUNT(*) AS "Total",
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	policies.policy_id AS "Policy ID",
	policies.name AS "Policy Name"
FROM policies
LEFT JOIN site_objects
	ON policies.policy_id = site_objects.object_id
		AND site_objects.object_type = "3"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
JOIN policy_history
	ON policy_history.policy_id = policies.policy_id
WHERE
	policy_history.completed_epoch>unix_timestamp(date_sub(NOW(), interval 1 DAY))*1000
GROUP BY
	policies.policy_id,
	sites.site_name
ORDER BY Total
DESC;


-- Get Policies that submitted Inventory within the last 24 hours and order by count.
SELECT
	COUNT(*) AS "Total",
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	policies.policy_id AS "Policy ID",
	policies.name AS "Policy Name"
FROM policies
LEFT JOIN site_objects
	ON policies.policy_id = site_objects.object_id
		AND site_objects.object_type = "3"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
JOIN policy_history
	ON policy_history.policy_id = policies.policy_id
WHERE
	policy_history.completed_epoch>unix_timestamp(date_sub(NOW(), interval 1 DAY))*1000
	AND policies.update_inventory = 1
GROUP BY
	policies.policy_id,
	sites.site_name
ORDER BY Total
DESC;


-- Get Policies that have ran within the last 24 hours, if they perform inventory, have errors, and their Site, and group/count the occurrences
SELECT
	COUNT(*) AS "Total",
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	policies.policy_id AS "Policy ID",
	policies.name AS "Policy Name",
	IF(policies.update_inventory = "1", "Yes", "No") AS "Update Inventory",
	SUM(IF(error = "1", 1, 0)) AS "Errors"
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
GROUP BY
	policies.policy_id,
	sites.site_name
ORDER BY Total
DESC;


-- ##################################################
-- Mash up of other queries

-- Get various Policies details of interest, including if they perform inventory, have errors, and their Site, and group/count the occurrences.
-- This is an all time count of how often Policies are ran including the number of errors reported.
SELECT
    policies.policy_id AS "Policy ID",
    policies.name AS "Policy Name",
    IF(sites.site_name IS NULL, "none", sites.site_name) AS Site,
	COUNT(policy_history.policy_id) AS "Total",
	SUM(IF(error = "1", 1, 0)) AS "Errors",
    IF(policies.enabled = "1", "Yes", "No") AS "Enabled",
	IF(policies.policy_id IN ( SELECT policies.policy_id FROM policies WHERE 
		created_by = "jss"
		AND run_swu != 1
		AND file_vault_2_reboot != 1 
		AND update_inventory != 1
		AND fix_permissions != 1
		AND fix_by_host_files != 1
		AND reset_computer_name != 1
		AND search_for_file = "" 
		AND locate_file = ""
		AND search_for_process = ""
		AND spotlight_search = ""
		AND run_command = ""
		AND install_all_cached != 1
		AND flush_system_caches != 1
		AND flush_user_caches != 1
		AND verify_startup_disk != 1
		AND heal != 1
		AND set_of_password != 1
		AND perform_workplace_join != 1
		AND compliance != 1
		AND disk_encryption_action != 1
		AND disk_encryption_id != 4
		AND managed_password_action != "rotate"
		AND policy_id NOT IN ( 
			( SELECT policy_id FROM policy_packages
			UNION ALL SELECT policy_id FROM policy_accounts
			UNION ALL SELECT policy_id FROM policy_directory_bindings
			UNION ALL SELECT policy_id FROM policy_dock_items
			UNION ALL SELECT policy_id FROM policy_printers
			UNION ALL SELECT policy_id FROM policy_scripts )
		)
	), "True", "False") AS "No configuration",
	IF(MAX(policy_history.completed_epoch) IS NULL, "Never", DATE_FORMAT(from_unixtime(MAX(policy_history.completed_epoch)/1000), '%Y-%m-%d %H:%i:%s')) AS "Last Ran",
    IF(policies.update_inventory = "1", "Yes", "No") AS "Update Inventory",
    IF(policies.category_id = "-1", "No", "Yes") AS "Has Category",
    IF(policies.execution_frequency IN ( "Ongoing", "Once every day", "Once every week", "Once every month" ), "True", "False") AS "Recurring Frequency",
    IF(policies.trigger_event_checkin = "1", "True", "False") AS "Check-in Event",
    IF(policies.trigger_event_login = "1", "True", "False") AS "Login Event",
    IF(policies.trigger_event_startup = "1", "True", "False") AS "Startup Event",
    IF(policies.trigger_event_enrollment_complete = "1", "True", "False") AS "Enrollment Event",
    IF(policies.trigger_event_network_state_change = "1", "True", "False") AS "Network Event",
    IF(policies.use_for_self_service = "1", "Yes", "No") AS "Self Service",
    policies.self_service_display_name AS "Self Service Policy Name",
    IF(policies.self_service_description = "", "No", "Yes") AS "Has Description",
    IF(policies.self_service_icon_id = "-1", "No", "Yes") AS "Has Icon",
    IF(policies.policy_id IN ( SELECT policy_deployment.policy_id FROM policy_deployment ), "True", "False") AS "Has Scope",
    IF(policies.policy_id IN ( SELECT policy_deployment.policy_id FROM policy_deployment WHERE policy_deployment.target_type = "101" ), "True", "False") AS "Scoped to  All Computers",
    IF(policies.policy_id IN ( SELECT policy_deployment.policy_id FROM policy_deployment WHERE policy_deployment.target_type = "106" ), "True", "False") AS "Scoped to  All Users",
    IF(policies.policy_id IN ( SELECT policy_id FROM policy_packages), "True", "False") AS "Installs Package(s)",
    IF(policies.run_swu = "1", "True", "False") AS "Perform Software Update"
FROM policies
LEFT JOIN site_objects
    ON policies.policy_id = site_objects.object_id AND site_objects.object_type = "3"
LEFT JOIN sites
    ON sites.site_id = site_objects.site_id
LEFT JOIN policy_history
    ON policy_history.policy_id = policies.policy_id
LEFT JOIN logs
    ON logs.log_id = policy_history.log_id
WHERE
    policies.created_by = "jss"
GROUP BY
    policies.policy_id,
    sites.site_name
ORDER BY Total
DESC;


-- ##################################################
-- Policies that are configured for Ongoing with any "reoccurring" trigger and installs a Package

-- Get Policies that are configured for Ongoing with any "reoccurring" trigger and installs a Package (Also get each Package ID and Name)
SELECT DISTINCT
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	policies.policy_id AS "Policy ID",
	policies.name AS "Policy Name",
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
		OR policies.trigger_event_network_state_change = "1"
		OR policies.trigger_event_checkin = "1"
	);


-- Get Policies that are configured for Ongoing with any "reoccurring" trigger and installs a Package which has a Scope that is not a Smart Group (Also get each Package ID and Name)
-- Need to add if scoped to Computer IDs directly
-- This query needs verification
SELECT DISTINCT
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	policies.policy_id AS "Policy ID",
	policies.name AS "Policy Name",
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
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	policies.policy_id AS "Policy ID",
	policies.name AS "Policy Name",
	packages.package_id AS "Package ID" ,
	packages.package_name AS "Package Name"
FROM policies
JOIN policy_packages ON policy_packages.policy_id = policies.policy_id
JOIN packages ON policy_packages.package_id = packages.package_id
JOIN policy_deployment ON policy_deployment.policy_id = policies.policy_id
JOIN site_objects ON site_objects.object_id = policies.policy_id
JOIN sites ON sites.site_id = site_objects.site_id
WHERE 
	policies.trigger_event_enrollment_complete = "1"
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
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	policies.policy_id AS "Policy ID",
	policies.name AS "Policy Name",
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
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	policies.policy_id AS "Policy ID",
	policies.name AS "Policy Name",
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
