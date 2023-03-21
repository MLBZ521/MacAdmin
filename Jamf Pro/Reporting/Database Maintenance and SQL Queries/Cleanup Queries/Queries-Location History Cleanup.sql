-- #############################
-- # Clean up Location History #
-- #############################

-- NOTE: These really aren't required any more since Jamf added these tables to the automtaic
-- Flush Policy -- which I disagree with.
--      (But you can disable that and then these may still be useful to you.)

-- These are notes on performing maintenance on the locations and location_history tables within the Jamf Pro database.
-- The actions in option one were incorporated within my jamf_db_maint.sh script.

-- ####################################################################################################
-- Option one, this is what I wanted for my environment:
--   * Remove only "empty" Location History records (as determined by the below logic)
--   * _AND_ only if the record was empty (not assigned any value, besides Building/Department)
--   * _Unless_ it was the latest record

-- Backup Database
-- Stop Tomcat on all JPS servers

-- Create a backup of the table affected tables
CREATE TABLE location_history_backup LIKE location_history;
INSERT location_history_backup SELECT * FROM location_history;

CREATE TABLE locations_backup LIKE locations;
INSERT locations_backup SELECT * FROM locations;

-- Create a table with the empty location records
CREATE TABLE empty_location_records (
	SELECT locations.location_id FROM locations WHERE (
		locations.username = ""
		AND locations.realname = ""
		AND locations.room = ""
		AND locations.phone = ""
		AND locations.email = ""
		AND locations.position = ""
		AND locations.location_id NOT IN (
			SELECT location_id FROM locations
				INNER JOIN computers_denormalized ON computers_denormalized.last_location_id = locations.location_id
			)
	)
);

-- Delete empty location records
DELETE locations_backup FROM locations_backup
WHERE location_id IN ( SELECT location_id FROM empty_location_records );

DELETE location_history_backup FROM location_history_backup
WHERE location_id IN ( SELECT location_id FROM empty_location_records );

-- Start Tomcat on master JPS that is admin facing and verify everything looks good with the modifications performed.

DROP TABLE location_history_backup;
DROP TABLE locations_backup;
DROP TABLE empty_location_records;

-- Start remaining Tomcat nodes

-- ####################################################################################################
-- Option two, this is the commands Jamf Support provided to erase everything, but the latest record per device.
-- I did not take this method as I wanted to keep legitmate history.

-- Backup Database
-- Stop all Tomcats

-- To clear out Location_History information, excluding the most recent data

CREATE TABLE location_history_new LIKE location_history;

INSERT INTO location_history_new (
	SELECT * FROM location_history
		WHERE computer_id = 0
);

INSERT INTO location_history_new (
	SELECT * FROM location_history
		WHERE location_id IN (
			SELECT last_location_id FROM computers_denormalized
		)
);

RENAME TABLE location_history TO location_history_old;

RENAME TABLE location_history_new TO location_history;

DROP TABLE location_history_old;

-- To clear Locations information, excluding most recent data

CREATE TABLE locations_new LIKE locations;

INSERT INTO locations_new (
	SELECT * FROM locations
		WHERE location_id IN (
			SELECT last_location_id FROM computers_denormalized
		)
);

INSERT INTO locations_new (
	SELECT * FROM locations
		WHERE location_id IN (
			SELECT last_location_id FROM mobile_devices_denormalized
		)
);

RENAME TABLE locations TO locations_old;

RENAME TABLE locations_new TO locations;

DROP TABLE locations_old;

-- Start Tomcat on master JPS that is admin facing and verify everything looks good with the modifications performed.
-- Start remaining Tomcat nodes
