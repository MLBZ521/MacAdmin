-- Queries on Group Configurations
-- These are formatted for readability, just fyi.

-- ##################################################
-- Computer Groups

-- Unused Computer Groups
SELECT DISTINCT
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	computer_groups.computer_group_name AS "Name",
	computer_groups.computer_group_id AS "ID",
	IF(computer_groups.is_smart_group = "1", "Yes", "No") AS "Smart Group"
FROM computer_groups
LEFT JOIN site_objects
	ON computer_groups.computer_group_id = site_objects.object_id
		AND site_objects.object_type = "7"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE
	computer_groups.computer_group_id NOT IN (
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
	AND computer_groups.computer_group_name NOT IN (
		SELECT criteria FROM smart_computer_group_criteria WHERE search_field = "Computer Group"
	)
;


-- Empty Computer Groups
SELECT DISTINCT
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	computer_groups.computer_group_name AS "Name",
	computer_groups.computer_group_id AS "ID",
	IF(computer_groups.is_smart_group = "1", "Yes", "No") AS "Smart Group"
FROM computer_groups
LEFT JOIN site_objects
	ON computer_groups.computer_group_id = site_objects.object_id
		AND site_objects.object_type = "7"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE 
	computer_groups.computer_group_id NOT IN (
		SELECT computer_group_id
		FROM computer_group_memberships
	)
;


-- Computer Smart Groups with no defined Criteria
SELECT DISTINCT
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	computer_groups.computer_group_name AS "Name",
	computer_groups.computer_group_id AS "ID",
	IF(computer_groups.is_smart_group = "1", "Yes", "No") AS "Smart Group"
FROM computer_groups
LEFT JOIN site_objects
	ON computer_groups.computer_group_id = site_objects.object_id
		AND site_objects.object_type = "7"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE
	computer_groups.is_smart_group = "1"
	AND computer_groups.computer_group_id NOT IN (
		SELECT computer_group_id
		FROM smart_computer_group_criteria
	)
;


-- Full descriptive overview of Computer Groups
SELECT DISTINCT
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	computer_groups.computer_group_id AS "ID",
	computer_groups.computer_group_name AS "Name",
	IF(computer_groups.is_smart_group = "1", "Yes", "No") AS "Smart Group",
	IF(
		computer_groups.computer_group_id NOT IN (
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
		),
	"False", "True") AS "Used",
	IF(computer_groups.computer_group_id NOT IN (
		SELECT computer_group_id
		FROM computer_group_memberships
		),
	"True", "False") AS "Zero Members",
	CASE
		WHEN computer_groups.is_smart_group = "0" THEN "Static"
		WHEN (
			computer_groups.is_smart_group = "1"
			AND computer_groups.computer_group_id NOT IN (
				SELECT computer_group_id
				FROM smart_computer_group_criteria
			)
		) THEN "True"
		Else "False"
	END AS "Criteria Not Defined",
	CASE
		WHEN computer_groups.is_smart_group = "0" THEN "Static"
		WHEN (
			computer_groups.computer_group_id IN (
				SELECT computer_group_id
				FROM smart_computer_group_criteria
				GROUP BY computer_group_id
				HAVING COUNT(computer_group_id) > 9
			)
		) THEN "True"
		Else "False"
	END AS "10+ Criteria",
	CASE
		WHEN computer_groups.is_smart_group = "0" THEN "Static"
		WHEN (
			computer_groups.computer_group_id IN (
				SELECT computer_group_id
				FROM smart_computer_group_criteria
				WHERE search_field = "Computer Group"
				GROUP BY computer_group_id
				HAVING COUNT(computer_group_id) > 3
			)
		) THEN "True"
		Else "False"
	END AS "4+ Nested Groups"
FROM computer_groups
LEFT JOIN site_objects
	ON computer_groups.computer_group_id = site_objects.object_id
		AND site_objects.object_type = "7"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
LEFT JOIN smart_computer_group_criteria
	ON smart_computer_group_criteria.computer_group_id = computer_groups.computer_group_id
;


-- ##################################################
-- Mobile Device Groups

-- Unused Mobile Device Groups
SELECT DISTINCT
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	mobile_device_groups.mobile_device_group_name AS "Name",
	mobile_device_groups.mobile_device_group_id AS "ID",
	IF(mobile_device_groups.is_smart_group = "1", "Yes", "No") AS "Smart Group"
FROM mobile_device_groups
LEFT JOIN site_objects
	ON mobile_device_groups.mobile_device_group_id = site_objects.object_id
		AND site_objects.object_type = "25"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE
	mobile_device_groups.mobile_device_group_id NOT IN (
		SELECT target_id FROM mobile_device_configuration_profile_deployment WHERE target_type = 25
			UNION ALL
		SELECT target_id FROM mobile_device_app_deployment WHERE target_type = 25
			UNION ALL
		SELECT target_id FROM ibook_deployment WHERE target_type = 25
			UNION ALL
		SELECT mobile_device_group_id FROM classroom_mobile_device_group
	)
	AND mobile_device_groups.mobile_device_group_name NOT IN (
		SELECT criteria FROM smart_mobile_device_group_criteria WHERE search_field = "Mobile Device Group"
	)
;


-- Empty Mobile Device Groups
SELECT DISTINCT
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	mobile_device_groups.mobile_device_group_name AS "Name",
	mobile_device_groups.mobile_device_group_id AS "ID",
	IF(mobile_device_groups.is_smart_group = "1", "Yes", "No") AS "Smart Group"
FROM mobile_device_groups
LEFT JOIN site_objects
	ON mobile_device_groups.mobile_device_group_id = site_objects.object_id
		AND site_objects.object_type = "25"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE 
	mobile_device_groups.mobile_device_group_id NOT IN (
		SELECT mobile_device_group_id
		FROM mobile_device_group_memberships
	)
;


-- Mobile Device Smart Groups with no defined Criteria
SELECT DISTINCT
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	mobile_device_groups.mobile_device_group_name AS "Name",
	mobile_device_groups.mobile_device_group_id AS "ID",
	IF(mobile_device_groups.is_smart_group = "1", "Yes", "No") AS "Smart Group"
FROM mobile_device_groups
LEFT JOIN site_objects
	ON mobile_device_groups.mobile_device_group_id = site_objects.object_id
		AND site_objects.object_type = "25"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE 
	mobile_device_groups.is_smart_group = "1"
	AND mobile_device_groups.mobile_device_group_id NOT IN (
		SELECT mobile_device_group_id
		FROM smart_mobile_device_group_criteria
	)
;


-- Full descriptive overview of Mobile Device Groups
SELECT DISTINCT
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	mobile_device_groups.mobile_device_group_id AS "ID",
	mobile_device_groups.mobile_device_group_name AS "Name",
	IF(mobile_device_groups.is_smart_group = "1", "Yes", "No") AS "Smart Group",
	IF(
		mobile_device_groups.mobile_device_group_id NOT IN (
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
		),
	"False", "True") AS "Used",
	IF(mobile_device_groups.mobile_device_group_id NOT IN (
		SELECT mobile_device_group_id
		FROM mobile_device_group_memberships
		),
	"True", "False") AS "Zero Members",
	CASE
		WHEN mobile_device_groups.is_smart_group = "0" THEN "Static"
		WHEN (
			mobile_device_groups.is_smart_group = "1"
			AND mobile_device_groups.mobile_device_group_id NOT IN (
				SELECT mobile_device_group_id
				FROM smart_mobile_device_group_criteria
			)
		) THEN "True"
		Else "False"
	END AS "Criteria Not Defined",
	CASE
		WHEN mobile_device_groups.is_smart_group = "0" THEN "Static"
		WHEN (
			mobile_device_groups.mobile_device_group_id IN (
				SELECT mobile_device_group_id
				FROM smart_mobile_device_group_criteria
				GROUP BY mobile_device_group_id
				HAVING COUNT(mobile_device_group_id) > 9
			)
		) THEN "True"
		Else "False"
	END AS "10+ Criteria",
	CASE
		WHEN mobile_device_groups.is_smart_group = "0" THEN "Static"
		WHEN (
			mobile_device_groups.mobile_device_group_id IN (
				SELECT mobile_device_group_id
				FROM smart_mobile_device_group_criteria
				WHERE search_field = "Mobile Device Group"
				GROUP BY mobile_device_group_id
				HAVING COUNT(mobile_device_group_id) > 3
			)
		) THEN "True"
		Else "False"
	END AS "4+ Nested Groups"
FROM mobile_device_groups
LEFT JOIN site_objects
	ON mobile_device_groups.mobile_device_group_id = site_objects.object_id
		AND site_objects.object_type = "25"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
LEFT JOIN smart_mobile_device_group_criteria
	ON mobile_device_groups.mobile_device_group_id = smart_mobile_device_group_criteria.mobile_device_group_id
;
