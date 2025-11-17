benchmark "get_runtime_information_about_the_operating_system_from_kernel" {
  title         = "4 Get Runtime Information about the Operating System from Kernel"
  children = [
    control.ensure_cramfs_kernel_module_is_not_available,
  ]
}

control "ensure_cramfs_kernel_module_is_not_available" {
  title = "Ensure cramfs kernel module is not available"
  description = "The cramfs filesystem is a compressed read-only filesystem. This control ensures that the cramfs kernel module is not loaded, reducing the attack surface."
  sql = <<EOT
    WITH loaded_modules AS (
        SELECT * 
        FROM kernel_modules 
        WHERE name = 'cramfs'
    )
    SELECT 
        'kernel_modules table' AS resource,
        CASE
            WHEN loaded_modules.status = 'Live' THEN 'alarm'
            ELSE 'ok'
        END AS status,
        CASE
            WHEN loaded_modules.status = 'Live' THEN 'The cramfs kernel module is loaded. Ensure it is removed if not required to reduce the attack surface.'
            ELSE 'The cramfs kernel module is not loaded. No action needed.'
        END AS reason
    FROM loaded_modules
    UNION
    SELECT 
        'kernel_modules table' AS resource,
        'ok' AS status,
        'The cramfs kernel module is not present in the system.' AS reason
    WHERE NOT EXISTS (
        SELECT 1 FROM kernel_modules WHERE name = 'cramfs'
    );
  EOT
}
