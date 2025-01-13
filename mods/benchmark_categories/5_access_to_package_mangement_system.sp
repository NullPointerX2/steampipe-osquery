benchmark "access_to_package_mangement_system" {
  title         = "5 Access to Package Management System"
  children = [
    control.ensure_apparmor_is_installed,
  ]
}

control "ensure_apparmor_is_installed" {
  title = "Ensure AppArmor is installed"
  description = "AppArmor provides Mandatory Access Controls. This control ensures that AppArmor is installed on the system."
  sql = <<EOT
    WITH apparmor_package AS (
        SELECT * 
        FROM deb_packages 
        WHERE name = 'apparmor'
    )
    SELECT 
        'deb_packages table' AS resource,
        CASE
            WHEN apparmor_package.status = 'install ok installed' THEN 'ok'
            WHEN apparmor_package.status IS NULL THEN 'alarm'
            ELSE 'alarm'
        END AS status,
        CASE
            WHEN apparmor_package.status = 'install ok installed' THEN 'AppArmor is installed on the system.'
            WHEN apparmor_package.status IS NULL THEN 'AppArmor package is not installed. Ensure that AppArmor is installed to provide Mandatory Access Controls.'
            ELSE 'AppArmor is installed but not in the expected state. Verify its installation status.'
        END AS reason
    FROM apparmor_package
    UNION
    SELECT 
        'deb_packages table' AS resource,
        'alarm' AS status,
        'AppArmor package is not installed. Ensure that AppArmor is installed to provide Mandatory Access Controls.' AS reason
    WHERE NOT EXISTS (
        SELECT 1 FROM deb_packages WHERE name = 'apparmor'
    );
  EOT
}
