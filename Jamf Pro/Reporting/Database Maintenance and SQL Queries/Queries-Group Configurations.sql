-- Queries on Group Configurations
-- These are formatted for readability, just fyi.

-- ##################################################
-- Computer Groups

-- Unused Computer Groups
SELECT DISTINCT
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	computer_groups.computer_group_name AS "Name",
	computer_groups.computer_group_id AS "ID",
	IF(computer_groups.is_smart_group = "1", "Yes", "No") AS "Smart Group"
FROM computer_groups
LEFT JOIN site_objects
	ON computer_groups.computer_group_id = site_objects.object_id
		AND site_objects.object_type = "7"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE computer_groups.computer_group_id NOT IN (
	SELECT target_id FROM policy_deployment WHERE target_type = 7
		UNION ALL
	SELECT target_id FROM os_x_configuration_profile_deployment WHERE target_type = 7
		UNION ALL
	SELECT target_id FROM restricted_software_deployment WHERE target_type = 7
		UNION ALL
	SELECT target_id FROM mac_app_deployment WHERE target_type = 7
		UNION ALL
	SELECT target_id FROM patch_deployment WHERE target_type = 7
		UNION ALL
	SELECT target_id FROM ibook_deployment WHERE target_type = 7
		UNION ALL
	SELECT target_id FROM self_service_plugin_deployment WHERE target_type = 7
)
AND
computer_groups.computer_group_name NOT IN (
	SELECT criteria FROM smart_computer_group_criteria WHERE search_field = "Computer Group"
);


-- Empty Computer Groups
SELECT DISTINCT computer_groups.computer_group_id, computer_groups.computer_group_name
FROM computer_groups
WHERE computer_groups.computer_group_id NOT IN (
	SELECT computer_group_id
	FROM computer_group_memberships
	);


-- Computer Groups with no defined Criteria
SELECT DISTINCT computer_groups.computer_group_id, computer_groups.computer_group_name
FROM computer_groups
WHERE computer_groups.is_smart_group = "1"
AND computer_groups.computer_group_id NOT IN (
	SELECT computer_group_id
	FROM smart_computer_group_criteria
	);


-- ##################################################
-- Mobile Device Groups

-- Unused Mobile Device Groups
SELECT DISTINCT
	IF(sites.site_name IS NULL, "none", sites.site_name) AS "Site",
	mobile_device_groups.mobile_device_group_name AS "Name",
	mobile_device_groups.mobile_device_group_id AS "ID",
	IF(mobile_device_groups.is_smart_group = "1", "Yes", "No") AS "Smart Group"
FROM mobile_device_groups
LEFT JOIN site_objects
	ON mobile_device_groups.mobile_device_group_id = site_objects.object_id
		AND site_objects.object_type = "25"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE mobile_device_groups.mobile_device_group_id NOT IN (
	SELECT target_id FROM mobile_device_configuration_profile_deployment WHERE target_type = 25
		UNION ALL
	SELECT target_id FROM mobile_device_app_deployment WHERE target_type = 25
		UNION ALL
	SELECT target_id FROM ibook_deployment WHERE target_type = 25
		UNION ALL
	SELECT mobile_device_group_id FROM classroom_mobile_device_group
)
AND
mobile_device_groups.mobile_device_group_name NOT IN (
	SELECT criteria FROM smart_mobile_device_group_criteria WHERE search_field = "Mobile Device Group"
);


-- Empty Mobile Device Groups
SELECT DISTINCT mobile_device_groups.mobile_device_group_id, mobile_device_groups.mobile_device_group_name
FROM mobile_device_groups
WHERE mobile_device_groups.mobile_device_group_id NOT IN (
	SELECT mobile_device_group_id
	FROM mobile_device_group_memberships
	);


-- Mobile Device Groups with no defined Criteria
SELECT DISTINCT mobile_device_groups.mobile_device_group_id, mobile_device_groups.mobile_device_group_name
FROM mobile_device_groups
WHERE mobile_device_groups.is_smart_group = "1"
AND mobile_device_groups.mobile_device_group_id NOT IN (
	SELECT mobile_device_group_id
	FROM smart_mobile_device_group_criteria
	);
