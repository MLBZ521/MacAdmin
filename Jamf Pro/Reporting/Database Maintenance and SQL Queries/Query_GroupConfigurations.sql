-- Queries on Group Configurations
-- These are formatted for readability, just fyi.

-- *** ALL of these queries need to be revisited for updates and correctness

-- ##################################################
-- Computer Groups

-- Unused Computer Groups
SELECT DISTINCT computer_groups.computer_group_id, computer_groups.computer_group_name
FROM computer_groups
WHERE computer_groups.computer_group_id NOT IN ( 
    SELECT target_id
    FROM policy_deployment
    WHERE policy_deployment.target_id = computer_groups.computer_group_id 
    AND policy_deployment.target_type = "7" 
    )
AND computer_groups.computer_group_id NOT IN ( 
    SELECT target_id
    FROM os_x_configuration_profile_deployment
    WHERE os_x_configuration_profile_deployment.target_id = computer_groups.computer_group_id 
    AND os_x_configuration_profile_deployment.target_type = "7" 
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
SELECT DISTINCT mobile_device_groups.mobile_device_group_id, mobile_device_groups.mobile_device_group_name
FROM mobile_device_groups
WHERE mobile_device_groups.mobile_device_group_id NOT IN ( 
    SELECT target_id
    FROM policy_deployment
    WHERE policy_deployment.target_id = mobile_device_groups.mobile_device_group_id 
    AND policy_deployment.target_type = "7" 
    )
AND mobile_device_groups.mobile_device_group_id NOT IN ( 
    SELECT target_id
    FROM mobile_device_configuration_profile_deployment
    WHERE mobile_device_configuration_profile_deployment.target_id = mobile_device_groups.mobile_device_group_id 
    AND mobile_device_configuration_profile_deployment.target_type = "7" 
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
