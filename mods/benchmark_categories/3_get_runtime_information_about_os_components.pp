benchmark "get_runtime_information_about_os_components" {
  title         = "3 Get Runtime Information About OS Components"
  children = [
    control.ensure_systemd_timesyncd_is_enabled_and_running,
  ]
}

control "ensure_systemd_timesyncd_is_enabled_and_running" {
  title = "Ensure systemd-timesyncd is enabled and running"
  description = "systemd-timesyncd is a daemon that synchronizes the system clock. This control ensures it is enabled and running."
  sql = <<EOT
    WITH timesyncd_status AS (
        SELECT * 
        FROM systemd_units 
        WHERE id = 'systemd-timesyncd.service'
    )
    SELECT 
        'systemd_units table' AS resource,
        CASE
            WHEN timesyncd_status.active_state = 'active' AND timesyncd_status.sub_state = 'running' AND timesyncd_status.unit_file_state = 'enabled' THEN 'ok'
            ELSE 'alarm'
        END AS status,
        CASE
            WHEN timesyncd_status.active_state = 'active' AND timesyncd_status.sub_state = 'running' AND timesyncd_status.unit_file_state = 'enabled' THEN 'systemd-timesyncd is enabled and running as expected.'
            ELSE 'systemd-timesyncd is either not running, not enabled, or both. Ensure that systemd-timesyncd is enabled and running to synchronize the system clock.'
        END AS reason
    FROM timesyncd_status
    UNION
    SELECT 
        'systemd_units table' AS resource,
        'alarm' AS status,
        'systemd-timesyncd is not present in systemd units. Ensure that systemd-timesyncd is installed and configured to run.' AS reason
    WHERE NOT EXISTS (
        SELECT 1 FROM systemd_units WHERE id = 'systemd-timesyncd.service'
    );
  EOT
}
