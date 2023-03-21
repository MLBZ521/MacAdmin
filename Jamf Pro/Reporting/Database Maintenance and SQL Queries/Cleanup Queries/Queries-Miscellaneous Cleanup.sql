--  Miscellaneous Cleanup Queries

-- ##################################################
-- Clean up orphaned records in the log_actions table

-- Get total count
SELECT COUNT(*) FROM log_actions;

-- Get number of orphaned records
SELECT COUNT(*) FROM log_actions
WHERE log_id NOT IN ( SELECT log_id FROM logs );

-- Rename the original table
RENAME TABLE log_actions TO log_actions_original;

-- Create new table like the old table
CREATE TABLE log_actions LIKE log_actions_original;

-- Select the non-orphaned records from the original table
INSERT INTO log_actions
SELECT * FROM log_actions_original
WHERE log_id IN ( SELECT log_id FROM logs );

-- Verify no orphaned records
SELECT COUNT(*) FROM log_actions
WHERE log_id NOT IN ( SELECT log_id FROM logs );


-- ##################################################
-- Clean up orphaned records in the mobile_device_extension_attribute_values table

-- Get total count
SELECT COUNT(*) FROM mobile_device_extension_attribute_values;

-- Get number of orphaned records
SELECT COUNT(*) FROM mobile_device_extension_attribute_values
WHERE report_id NOT IN (
	SELECT report_id FROM reports WHERE mobile_device_id > 0 );

-- Rename the original table
RENAME TABLE mobile_device_extension_attribute_values TO mobile_device_extension_attribute_values_original;

-- Create new table like the old table
CREATE TABLE mobile_device_extension_attribute_values LIKE mobile_device_extension_attribute_values_original;

-- Select the non-orphaned records from the original table
INSERT INTO mobile_device_extension_attribute_values
SELECT * FROM mobile_device_extension_attribute_values_original
WHERE report_id IN (
	SELECT report_id FROM reports WHERE mobile_device_id > 0 );

-- Verify no orphaned records
SELECT COUNT(*) FROM mobile_device_extension_attribute_values
WHERE report_id NOT IN (
	SELECT report_id FROM reports WHERE mobile_device_id > 0 );

-- Get new total count
SELECT COUNT(*) FROM mobile_device_extension_attribute_values;
