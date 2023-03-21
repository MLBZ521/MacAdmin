-- Queries on APNS/MDM Commands

-- ##################################################
-- Clean up records in the mobile_device_management_commands table

-- Get total count
SELECT COUNT(*) FROM mobile_device_management_commands;

-- Rename the original table
RENAME TABLE mobile_device_management_commands TO mobile_device_management_commands_original;

-- Create new table like the old table
CREATE TABLE mobile_device_management_commands LIKE mobile_device_management_commands_original;

-- Insert desired the records from the original table
INSERT INTO mobile_device_management_commands
SELECT * FROM mobile_device_management_commands_original
WHERE command NOT IN (
	"RemoveProfile", "ProfileList", "InstalledApplicationList", "CertificateList",
	"DeviceInformation", "SecurityInfo", "UpdateInventory", "ContentCachingInformation",
	"RemoveApplication", "UserList"
);

-- Jamf Pro Product Issue:  (Couldn't find the PI at the moment)
-- When a machine is re-enrolled, it gets a new push token and all of the remote commands
--      associated with the old push token are supposed to be cleared out.
-- However, the this doesn't happen which is what the PI is for and the below command will clear out.
-- ***PLEASE NOTE*** Workarounds that remove objects from the mobile_device_management_commands
--      table will leave orphan records in the mdm_command_source and mdm_command_group tables.
--      If you are running this workaround, the workaround for PI-009639 must be run promptly after.

-- Get orphaned remote commands
SELECT COUNT(*)
FROM mobile_device_management_commands
WHERE
	apns_result_status="" AND
	device_object_id=12 AND
	device_id NOT IN (
		SELECT computer_user_pushtoken_id
		FROM computer_user_pushtokens
	);

-- Clean up additional records
DELETE FROM mobile_device_management_commands
WHERE
	apns_result_status="" AND
	device_object_id=12 AND
	device_id NOT IN (
		SELECT computer_user_pushtoken_id
		FROM computer_user_pushtokens
	);


-- ##################################################
-- Jamf Pro Product Issue:  PI-009639
-- Clean up records in the computer_user_pushtokens table

-- Rename the original mdm_command_source table
RENAME TABLE mdm_command_source TO mdm_command_source_original;

-- Rename the original mdm_command_group table
RENAME TABLE mdm_command_group TO mdm_command_group_original;

-- Creating new mdm_command_source table
CREATE TABLE mdm_command_source LIKE mdm_command_source_original;

-- Creating new mdm_command_group table
CREATE TABLE mdm_command_group LIKE mdm_command_group_original;

-- Inserting desired records into new table
INSERT INTO mdm_command_source (
	SELECT * FROM mdm_command_source_original
	WHERE mdm_command_id IN (
		SELECT mobile_device_management_command_id FROM mobile_device_management_commands
	)
);

-- Inserting desired records into new table
INSERT INTO mdm_command_group (
	SELECT * FROM mdm_command_group_original
	WHERE id IN (
		SELECT id FROM mdm_command_source
	)
);


-- ##################################################
-- Clean up records in the computer_user_pushtokens table

-- Get total count
SELECT COUNT(*) FROM computer_user_pushtokens;

-- Get number of records to delete
SELECT COUNT(*) FROM computer_user_pushtokens
WHERE user_short_name LIKE "uid_%";

-- Rename the original table
RENAME TABLE computer_user_pushtokens TO computer_user_pushtokens_original;

-- Create new table like the old table
CREATE TABLE computer_user_pushtokens LIKE computer_user_pushtokens_original;

-- Insert the records from the original table
INSERT INTO computer_user_pushtokens
SELECT * FROM computer_user_pushtokens_original
WHERE user_short_name NOT LIKE "uid_%";
