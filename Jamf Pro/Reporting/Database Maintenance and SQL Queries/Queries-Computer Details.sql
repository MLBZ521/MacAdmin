-- Queries on Computer Details

-- Total number of Managed Computers
SELECT count(*) AS "Total Managed Computers"
FROM computers_denormalized
WHERE is_managed = 1;


-- ##################################################
-- Software Details
SELECT
	computers.computer_id,
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	computers.computer_name AS "Computer Name",
	computers_denormalized.serial_number AS "Serial Number",
	computers.asset_tag AS "PCN",
	DATE(date_sub(FROM_unixtime(computers_denormalized.last_report_date_epoch/1000), INTERVAL 1 DAY)) AS "Last Inventory Update",
	computers_denormalized.operating_system_version AS "Operating System Version",
	computers_denormalized.operating_system_build AS "Operating System Build",
	CASE
		WHEN computers_denormalized.model_identifier REGEXP "^((MacPro|Macmini|MacBookPro)[1-2],[0-9]|iMac[1-6],[0-9]|MacBook[1-4],[0-9]|MacBookAir1,[0-9])$" THEN "Model Not Supported"
		WHEN computers_denormalized.model_identifier REGEXP "^(MacPro[1-4],[0-9]|iMac[1-9],[0-9]|Macmini[1-3],[0-9]|(MacBook|MacBookPro)[1-5],[0-9]|MacBookAir[1-2],[0-9])$" THEN "El Capitan"
		WHEN computers_denormalized.model_identifier REGEXP "^(MacPro[1-4],[0-9]|iMac([1-9]|1[0-2]),[0-9]|Macmini[1-5],[0-9]|MacBook[1-7],[0-9]|MacBookAir[1-4],[0-9]|MacBookPro[1-8],[0-9])$" THEN "High Sierra"
		WHEN computers_denormalized.model_identifier REGEXP "^(MacPro[1-5],[0-9]|iMac([1-9]|1[0-2]),[0-9]|Macmini[1-5],[0-9]|MacBook[1-7],[0-9]|MacBookAir[1-4],[0-9]|MacBookPro[1-8],[0-9])$" THEN "Mojave"
		WHEN computers_denormalized.model_identifier REGEXP "^(MacPro[1-5],[0-9]|iMac((([1-9]|1[0-3]),[0-9])|14,[0-3])|Macmini[1-6],[0-9]|MacBook[1-7],[0-9]|MacBookAir[1-5],[0-9]|MacBookPro([1-9]|10),[0-9])$" THEN "Catalina"
		WHEN computers_denormalized.model_identifier REGEXP "^(MacPro[1-5],[0-9]|iMac([1-9]|1[0-5]),[0-9]|(Macmini|MacBookAir)[1-6],[0-9]|MacBook[1-8],[0-9]|MacBookPro(([1-9]|10),[0-9]|11,[0-3]))$" THEN "Big Sur"
		WHEN computers_denormalized.model_identifier REGEXP "^(MacPro[1-6],[0-9]|iMac([1-9]|1[0-7]),[0-9]|(Macmini|MacBookAir)[1-7],[0-9]|MacBook[1-9],[0-9]|MacBookPro([1-9]|1[0-3]),[0-9])$" THEN "Monterey"
		WHEN computers_denormalized.model_identifier REGEXP "^(MacPro[1-6],[0-9]|iMac([1-9]|1[0-8]),[0-9]|(Macmini|MacBookAir)[1-7],[0-9]|MacBook[\d,]+|MacBookPro([1-9]|1[0-4]),[0-9])$" THEN "Ventura"
		ELSE "Sonoma"
	END AS "Latest Major OS Supported",
	CASE
		WHEN (
			computers_denormalized.model_identifier REGEXP "^(MacPro[1-4],[0-9]|iMac[1-9],[0-9]|Macmini[1-3],[0-9]|(MacBook|MacBookPro)[1-5],[0-9]|MacBookAir[1-2],[0-9])$"
			AND computers_denormalized.operating_system_version LIKE "10.11%"
			OR
				computers_denormalized.model_identifier REGEXP "^(MacPro[1-4],[0-9]|iMac([1-9]|1[0-2]),[0-9]|Macmini[1-5],[0-9]|MacBook[1-7],[0-9]|MacBookAir[1-4],[0-9]|MacBookPro[1-8],[0-9])$"
				AND computers_denormalized.operating_system_version LIKE "10.13%"
			OR
				computers_denormalized.model_identifier REGEXP "^(MacPro[1-5],[0-9]|iMac([1-9]|1[0-2]),[0-9]|Macmini[1-5],[0-9]|MacBook[1-7],[0-9]|MacBookAir[1-4],[0-9]|MacBookPro[1-8],[0-9])$"
				AND computers_denormalized.operating_system_version LIKE "10.14%"
			OR
				computers_denormalized.model_identifier REGEXP "^(MacPro[1-5],[0-9]|iMac((([1-9]|1[0-3]),[0-9])|14,[0-3])|Macmini[1-6],[0-9]|MacBook[1-7],[0-9]|MacBookAir[1-5],[0-9]|MacBookPro([1-9]|10),[0-9])$"
				AND computers_denormalized.operating_system_version LIKE "10.15%"
			OR
				computers_denormalized.model_identifier REGEXP "^(MacPro[1-5],[0-9]|iMac([1-9]|1[0-5]),[0-9]|(Macmini|MacBookAir)[1-6],[0-9]|MacBook[1-8],[0-9]|MacBookPro(([1-9]|10),[0-9]|11,[0-3]))$"
				AND computers_denormalized.operating_system_version LIKE "11.%"
			OR
				computers_denormalized.model_identifier REGEXP "^(MacPro[1-6],[0-9]|iMac([1-9]|1[0-7]),[0-9]|(Macmini|MacBookAir)[1-7],[0-9]|MacBook[1-9],[0-9]|MacBookPro([1-9]|1[0-3]),[0-9])$"
				AND computers_denormalized.operating_system_version LIKE "12.%"
			OR
				computers_denormalized.model_identifier REGEXP "^(MacPro[1-6],[0-9]|iMac([1-9]|1[0-8]),[0-9]|(Macmini|MacBookAir)[1-7],[0-9]|MacBook[\d,]+|MacBookPro([1-9]|1[0-4]),[0-9])$"
				AND computers_denormalized.operating_system_version LIKE "13.%"
			OR
				computers_denormalized.operating_system_version LIKE "14.%"
		) THEN "True"
		ELSE "False"
	END AS "Latest Major OS Installed",
	IF(
		(
			computers_denormalized.computer_id IN (
				SELECT computers_denormalized.computer_id
				FROM patch_software_titles, computers_denormalized
				WHERE
					patch_software_titles.latest_version LIKE CONCAT('%(', computers_denormalized.operating_system_build, ')' )
					and (
						computers_denormalized.operating_system_version LIKE "10.10%" and patch_software_titles.id = 47
						or
						computers_denormalized.operating_system_version LIKE "10.11%" and patch_software_titles.id = 44
						or
						computers_denormalized.operating_system_version LIKE "10.12%" and patch_software_titles.id = 33
						or
						computers_denormalized.operating_system_version LIKE "10.13%" and patch_software_titles.id = 32
						or
						computers_denormalized.operating_system_version LIKE "10.14%" and patch_software_titles.id = 31
						or
						computers_denormalized.operating_system_version LIKE "10.15%" and patch_software_titles.id = 30
						or
						computers_denormalized.operating_system_version LIKE "11.%" and patch_software_titles.id = 28
						or
						computers_denormalized.operating_system_version LIKE "12.%" and patch_software_titles.id = 48
						or
						computers_denormalized.operating_system_version LIKE "13.%" and patch_software_titles.id = 54
					)
			)
		), "True", "False") AS "Latest Patch Installed",
	ea.last_os_update_installed AS "Last OS Update Installed",
	computers_denormalized.active_directory_status AS "Active Directory Status",
	ea.unit AS "Unit",
	computers_denormalized.department_name AS "Department",
	ea.internal_department AS "Internal Department",
	computers_denormalized.realname AS "Assigned User",
	computers_denormalized.username AS "Username",
	computers_denormalized.position AS "Position",
	ea.device_type AS "Device Type",
	ea.location AS "Primary Location",
	computers_denormalized.building_name AS "Building",
	computers_denormalized.room AS "Room"
FROM computers
LEFT JOIN computers_denormalized
	ON computers_denormalized.computer_id = computers.computer_id
LEFT JOIN (
		SELECT computer_id, MAX(report_id) AS report_id, MAX(date_entered_epoch) AS date_entered_epoch
		FROM reports
		GROUP BY reports.computer_id
	) AS r
	ON r.computer_id = computers.computer_id
LEFT JOIN (
		SELECT
			report_id,
			MAX(CASE WHEN extension_attribute_id = 62 THEN value_on_client END) AS "unit",
			MAX(CASE WHEN extension_attribute_id = 63 THEN value_on_client END) AS "device_type",
			MAX(CASE WHEN extension_attribute_id = 64 THEN value_on_client END) AS "internal_department",
			MAX(CASE WHEN extension_attribute_id = 65 THEN value_on_client END) AS "primary_location",
			MAX(CASE WHEN extension_attribute_id = 71 THEN value_on_client END) AS "last_os_update_installed"
		FROM extension_attribute_values
		WHERE extension_attribute_id IN (62, 63, 64, 65, 71)
		GROUP BY report_id
	) AS ea
	ON ea.report_id = r.report_id
LEFT JOIN site_objects
	ON computers.computer_id = site_objects.object_id
		AND site_objects.object_type = "1"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE computers_denormalized.is_managed = 1
;


-- ##################################################
-- Hardware Details
SELECT
	computers.computer_id,
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	computers.computer_name AS "Computer Name",
	computers_denormalized.serial_number AS "Serial Number",
	computers.asset_tag AS "PCN",
	computers_denormalized.model AS "Model",
	computers_denormalized.model_identifier AS "Model Identifier",
	IF(
		computers_denormalized.warranty_date_epoch = 0, "Unknown",
		DATE(date_sub(FROM_unixtime(computers_denormalized.warranty_date_epoch/1000), INTERVAL 1 DAY))
	) AS "Warranty Expiration",
	IF(computers.is_apple_silicon = 1, "ARM", "Intel") AS "Architecture Type",
	computers_denormalized.boot_drive_percent_full AS "Boot Drive Percentage Full",
	DATE(date_sub(FROM_unixtime(computers_denormalized.last_report_date_epoch/1000), INTERVAL 1 DAY)) AS "Last Inventory Update"
FROM computers
LEFT JOIN computers_denormalized
	ON computers_denormalized.computer_id = computers.computer_id
LEFT JOIN site_objects
	ON computers.computer_id = site_objects.object_id
		AND site_objects.object_type = "1"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE computers_denormalized.is_managed = 1
;


-- Count of each model family
SELECT
	SUM(IF(model LIKE "%MacBook%Pro%", 1, 0)) AS "MacBook Pro",
	SUM(IF(model LIKE "MacBook%Air%", 1, 0)) AS "MacBook Air",
	SUM(IF(model LIKE "iMac%", 1, 0)) AS "iMac",
	SUM(IF(model LIKE "Mac%mini%", 1, 0)) AS "Mac Mini",
	SUM(IF(model LIKE "MacPro%", 1, 0)) AS "Mac Pro",
	SUM(IF(model LIKE "Mac Studio%", 1, 0)) AS "Mac Studio",
	SUM(IF(model LIKE "MacBook (%", 1, 0)) AS "MacBook",
	SUM(IF(model LIKE "%Xserve%", 1, 0)) AS "Xserve",
	SUM(IF(
		model LIKE "Mac1%" OR
		model LIKE "VirtualMac%" OR
		model = ""
		, 1, 0)) AS "Unknown"
FROM computers_denormalized
WHERE computers_denormalized.is_managed = 1;


-- Count of individual models
SELECT
	COUNT(*) AS "Total",
	model AS "Model"
FROM computers_denormalized
WHERE is_managed = 1
GROUP BY model
ORDER BY "Total"
DESC;


-- ##################################################
-- Management Health
SELECT
	computers.computer_id,
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	computers.computer_name AS "Computer Name",
	computers_denormalized.serial_number AS "Serial Number",
	computers.asset_tag AS "PCN",
	IF(computers_denormalized.serial_number IS NULL, "True", "False") AS "Missing Serial Number",
	IF(computers_denormalized.serial_number IN (
				SELECT serial_number
				FROM computers_denormalized
				WHERE computers_denormalized.is_managed = 1 -- When looking for duplicates, only checked against managed if the records
				GROUP BY serial_number
				HAVING COUNT(serial_number) > 1
			), "True", "False"
	) AS "Duplicate Serial Numbers",
	IF(
		computers_denormalized.last_contact_time_epoch = 0, "Never",
		DATE(date_sub(FROM_unixtime(computers_denormalized.last_contact_time_epoch/1000), INTERVAL 1 DAY))
	) AS "Last Check-in",
	DATE(date_sub(FROM_unixtime(computers_denormalized.last_report_date_epoch/1000), INTERVAL 1 DAY)) AS "Last Inventory Update",
	DATE(date_sub(FROM_unixtime(computers_denormalized.last_enrolled_date_epoch/1000), INTERVAL 1 DAY)) AS "Last Enrollment",
	DATE(date_sub(FROM_unixtime(computers.initial_entry_date_epoch/1000), INTERVAL 1 DAY)) AS "Initial Enrollment",
	CASE
		WHEN computers_denormalized.is_supervised = 1 THEN "True"
		WHEN (
			computers_denormalized.operating_system_version LIKE "10.9%" OR
			computers_denormalized.operating_system_version LIKE "10.10%" OR
			computers_denormalized.operating_system_version LIKE "10.11%" OR
			computers_denormalized.operating_system_version LIKE "10.12%" OR
			computers_denormalized.operating_system_version LIKE "10.13%" OR
			computers_denormalized.operating_system_version LIKE "10.14%"
		) THEN "Not Supported"
		ELSE "False"
	END AS "Supervised",
	CASE
		WHEN computers_denormalized.enrolled_via_automated_device_enrollment = 1 THEN "True"
		WHEN (
			computers_denormalized.operating_system_version LIKE "10.9%" OR
			computers_denormalized.operating_system_version LIKE "10.10%" OR
			computers_denormalized.operating_system_version LIKE "10.11%" OR
			computers_denormalized.operating_system_version LIKE "10.12%" OR
			computers_denormalized.operating_system_version LIKE "10.13.0%" OR
			computers_denormalized.operating_system_version LIKE "10.13.1%"
		) THEN "Not Supported"
		ELSE "False"
	END AS "ADE Enrolled",
	CASE
		WHEN computers_denormalized.user_approved_mdm = 1 THEN "True"
		WHEN (
			computers_denormalized.operating_system_version LIKE "10.9%" OR
			computers_denormalized.operating_system_version LIKE "10.10%" OR
			computers_denormalized.operating_system_version LIKE "10.11%" OR
			computers_denormalized.operating_system_version LIKE "10.12%" OR
			computers_denormalized.operating_system_version LIKE "10.13.0%" OR
			computers_denormalized.operating_system_version LIKE "10.13.1%"
		) THEN "Not Supported"
		ELSE "False"
	END AS "User Approved MDM",
	CASE
		WHEN computer_security_info.bootstrap_token IS NOT NULL THEN "True"
		WHEN (
			computers_denormalized.operating_system_version LIKE "10.9%" OR
			computers_denormalized.operating_system_version LIKE "10.10%" OR
			computers_denormalized.operating_system_version LIKE "10.11%" OR
			computers_denormalized.operating_system_version LIKE "10.12%" OR
			computers_denormalized.operating_system_version LIKE "10.13%" OR
			computers_denormalized.operating_system_version LIKE "10.14%" OR
			computers_denormalized.operating_system_version LIKE "10.15%"
		) THEN "Not Supported"
		ELSE "False"
	END AS "Bootstrap Token Escrowed",
	CASE
		WHEN computers_denormalized.declarative_device_management_enabled = 1 THEN "True"
		WHEN (
			computers_denormalized.operating_system_version LIKE "10.9%" OR
			computers_denormalized.operating_system_version LIKE "10.10%" OR
			computers_denormalized.operating_system_version LIKE "10.11%" OR
			computers_denormalized.operating_system_version LIKE "10.12%" OR
			computers_denormalized.operating_system_version LIKE "10.13%" OR
			computers_denormalized.operating_system_version LIKE "10.14%" OR
			computers_denormalized.operating_system_version LIKE "10.15%" OR
			computers_denormalized.operating_system_version LIKE "11.%" OR
			computers_denormalized.operating_system_version LIKE "12.%"
		) THEN "Not Supported"
		ELSE "False"
	END AS "Declarative Device Management",
	IF(computers.user_removed_mdm_profile = 1, "True", "False") AS "Missing MDM Profile"
FROM computers
LEFT JOIN computers_denormalized
	ON computers_denormalized.computer_id = computers.computer_id
LEFT JOIN computer_security_info
	ON computer_security_info.computer_id = computers.computer_id
LEFT JOIN site_objects
	ON computers.computer_id = site_objects.object_id
		AND site_objects.object_type = "1"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE computers_denormalized.is_managed = 1
;


-- ##################################################
-- Security
SELECT
	computers.computer_id,
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	computers.computer_name AS "Computer Name",
	computers_denormalized.serial_number AS "Serial Number",
	computers.asset_tag AS "PCN",
	IF(computers.auto_login_user != "", "Enabled", "Disabled") AS "Auto Login",
	IF(computers.gatekeeper_status IN (2, 3), "Enabled", "Disabled") AS "Gatekeeper",
	CASE
		WHEN computers.is_recovery_lock_enabled = 1 THEN "Enabled"
		WHEN (
			computers_denormalized.operating_system_version LIKE "10.9%" OR
			computers_denormalized.operating_system_version LIKE "10.10%" OR
			computers_denormalized.operating_system_version LIKE "10.11%" OR
			computers_denormalized.operating_system_version LIKE "10.12%" OR
			computers_denormalized.operating_system_version LIKE "10.13%" OR
			computers_denormalized.operating_system_version LIKE "10.14%" OR
			computers_denormalized.operating_system_version LIKE "10.15%" OR
			computers_denormalized.operating_system_version LIKE "11.0%" OR
			computers_denormalized.operating_system_version LIKE "11.1%" OR
			computers_denormalized.operating_system_version LIKE "11.2%" OR
			computers_denormalized.operating_system_version LIKE "11.3%" OR
			computers_denormalized.operating_system_version LIKE "11.4%"
		) THEN "Not Supported"
		ELSE "Disabled"
	END AS "Recovery Lock",
	CASE
		WHEN computers.sip_status = 3 THEN "Enabled"
		WHEN (
			computers_denormalized.operating_system_version LIKE "10.9%" OR
			computers_denormalized.operating_system_version LIKE "10.10%"
		) THEN "Not Supported"
		ELSE "Disabled"
	END AS "System Integrity Protection",
	IF(computers.firewall_enabled != "", "Enabled", "Disabled") AS "Firewall",
	CASE
		WHEN computers_denormalized.secure_boot_level = "full" THEN "Enabled"
		WHEN (
			computers_denormalized.operating_system_version LIKE "10.9%" OR
			computers_denormalized.operating_system_version LIKE "10.10%" OR
			computers_denormalized.operating_system_version LIKE "10.11%" OR
			computers_denormalized.operating_system_version LIKE "10.12%" OR
			computers_denormalized.operating_system_version LIKE "10.13%" OR
			computers_denormalized.operating_system_version LIKE "10.14%"
		) THEN "Not Supported"
		ELSE "Disabled"
	END AS "Secure Boot Level",
	CASE
		WHEN (
			computers_denormalized.file_vault_2_status IN ("All Partitions Encrypted", "Boot Partitions Encrypted")
			AND computers_denormalized.file_vault_1_status_percent = 100
		) THEN "Encrypted"
		WHEN (
			computers_denormalized.file_vault_2_status IN ("All Partitions Encrypted", "Boot Partitions Encrypted")
			AND computers_denormalized.file_vault_1_status_percent != 100
		) THEN "Encrypting"
		ELSE "Not Encrypted"
	END AS "Encryption Status",
	CASE
		WHEN (
			computers_denormalized.file_vault_2_status IN ("All Partitions Encrypted", "Boot Partitions Encrypted")
			AND computers_denormalized.file_vault_2_recovery_key_valid = "1"
		) THEN "Valid"
		WHEN (
			computers_denormalized.file_vault_2_status IN ("All Partitions Encrypted", "Boot Partitions Encrypted")
			AND computers_denormalized.file_vault_2_recovery_key_valid != "1"
		) THEN "Invalid"
		ELSE "Not Encrypted"
	END AS "Decryption Key",
	ea.falcon_version AS "Falcon Version",
	ea.falcon_status AS "Falcon Status"
FROM computers
LEFT JOIN computers_denormalized
	ON computers_denormalized.computer_id = computers.computer_id
LEFT JOIN (
		SELECT computer_id, MAX(report_id) AS report_id, MAX(date_entered_epoch) AS date_entered_epoch
		FROM reports
		GROUP BY reports.computer_id
	) AS r
	ON r.computer_id = computers.computer_id
LEFT JOIN (
		SELECT
			report_id,
			MAX(CASE WHEN extension_attribute_id = 58 THEN value_on_client END) AS "falcon_status",
			MAX(CASE WHEN extension_attribute_id = 57 THEN value_on_client END) AS "falcon_version"
		FROM extension_attribute_values
		WHERE extension_attribute_id IN (57, 58)
		GROUP BY report_id
	) AS ea
	ON ea.report_id = r.report_id
LEFT JOIN site_objects
	ON computers.computer_id = site_objects.object_id
		AND site_objects.object_type = "1"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE computers_denormalized.is_managed = 1
;


-- ##################################################
-- Computers that have enrolled <recently> and are not managed
SELECT
	computers.computer_id,
	IF(sites.site_name IS NULL, "None", sites.site_name) AS "Site",
	computers.computer_name AS "Computer Name",
	computers_denormalized.serial_number AS "Serial Number",
	computers.asset_tag AS "PCN",
	DATE(date_sub(FROM_unixtime(computers_denormalized.last_enrolled_date_epoch/1000), INTERVAL 1 DAY)) AS "Last Enrollment",
	DATE(date_sub(FROM_unixtime(computers.initial_entry_date_epoch/1000), INTERVAL 1 DAY)) AS "Initial Enrollment"
FROM computers
LEFT JOIN computers_denormalized
	ON computers_denormalized.computer_id = computers.computer_id
LEFT JOIN site_objects
	ON computers.computer_id = site_objects.object_id
		AND site_objects.object_type = "1"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE
	is_managed = 0 AND
	UNIX_TIMESTAMP(NOW() - INTERVAL 365 DAY)*1000 < last_enrolled_date_epoch
;


-- ##################################################
-- Computers that are not in a Site
SELECT
	computers.computer_id,
	computers.computer_name AS "Computer Name",
	computers_denormalized.serial_number AS "Serial Number",
	computers.asset_tag AS "PCN",
	DATE(date_sub(FROM_unixtime(computers.initial_entry_date_epoch/1000), INTERVAL 1 DAY)) AS "Initial Enrollment",
	DATE(date_sub(FROM_unixtime(computers_denormalized.last_enrolled_date_epoch/1000), INTERVAL 1 DAY)) AS "Last Enrollment",
	DATE(date_sub(FROM_unixtime(computers_denormalized.last_report_date_epoch/1000), INTERVAL 1 DAY)) AS "Last Inventory Update",
	IF(
		computers_denormalized.warranty_date_epoch = 0, "Never",
		DATE(date_sub(FROM_unixtime(computers_denormalized.last_contact_time_epoch/1000), INTERVAL 1 DAY))
	) AS "Last Check-in"
FROM computers
LEFT JOIN computers_denormalized
	ON computers_denormalized.computer_id = computers.computer_id
LEFT JOIN site_objects
	ON computers.computer_id = site_objects.object_id
		AND site_objects.object_type = "1"
LEFT JOIN sites
	ON sites.site_id = site_objects.site_id
WHERE
	is_managed = 1 AND
	sites.site_name IS NULL
;
