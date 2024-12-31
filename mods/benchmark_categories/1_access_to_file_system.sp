benchmark "access_to_fs" {
  title         = "1 Access to File System"
  children = [
    control.check_permissions_on_etc_issue,
    control.ensure_tmp_separate_partition,
    control.ensure_nodev_on_tmp_partition,
    control.audit_config_files_owned_by_root,
  ]
}

control "check_permissions_on_etc_issue" {
  title = "Ensure permissions on /etc/issue are configured"
  description = "The contents of the /etc/issue file are displayed to users prior to login for local terminals. This control checks if the ownership of the file is correctly set to root and if the access permissions are set to 644."
  sql = <<EOT
    with etc_issue_data as (
      select * from file where path = '/etc/issue'
    )
    select
      'file table' as resource,
      case
        when uid = 0 and gid = 0 and mode = '0644' then 'ok'
        else 'alarm'
      end as status,
      case
        when uid = 0 and gid = 0 and mode = '0644' then 'Permissions on /etc/issue are correctly configured.'
        else 'Permissions on /etc/issue are not correctly configured. Ensure Uid and Gid are both 0/root and Access is 644.'
      end as reason
    from
      etc_issue_data
  EOT
}

control "ensure_tmp_separate_partition" {
  title = "Ensure /tmp is a separate partition"
  description = "The /tmp directory is a world-writable directory used for temporary storage by all users and some applications. Making /tmp its own file system allows for additional mount options enhancing security."
  sql = <<EOT
    with tmp_partition as (
      select * from mounts where path = '/tmp'
    )
    select
      'mounts table' as resource,
      case
        when count(*) > 0 then 'ok'
        else 'alarm'
      end as status,
      case
        when count(*) > 0 then '/tmp is mounted on a separate partition.'
        else '/tmp is not mounted on a separate partition. It is recommended to mount /tmp on its own partition for security reasons.'
      end as reason
    from
      tmp_partition
  EOT
}

control "ensure_nodev_on_tmp_partition" {
  title = "Ensure nodev option set on /tmp partition"
  description = "The nodev mount option specifies that the filesystem cannot contain special devices. Since the /tmp filesystem is not intended to support devices, this option ensures that users cannot create a block or character special devices in /tmp."
  sql = <<EOT
    with tmp_mount as (
      select * from mounts where path = '/tmp'
    )
    select
      'mounts table' as resource,
      case
        when flags like '%nodev%' then 'ok'
        else 'alarm'
      end as status,
      case
        when flags like '%nodev%' then 'nodev option is set on /tmp partition.'
        else 'nodev option is not set on /tmp partition. Ensure that /tmp is mounted with nodev.'
      end as reason
    from
      tmp_mount
  EOT
}

control "audit_config_files_owned_by_root" {
  title = "Ensure audit configuration files are owned by root"
  description = "Audit configuration files control auditd and what events are audited. Access to these files should be restricted to the root user to prevent unauthorized changes."
  sql = <<EOT
    with audit_config_files as (
      select * from file 
      where 
        path like '/etc/audit/%' and 
        (filename like '%.conf' or filename like '%.rules') and
        type = 'regular'
    )
    select
      'file table' as resource,
      case
        when count(*) = 0 or max(uid) = 0 then 'ok'
        else 'alarm'
      end as status,
      case
        when count(*) = 0 then 'No audit configuration files found.'
        when max(uid) = 0 then 'All audit configuration files are owned by root.'
        else 'Some audit configuration files are not owned by root. Ensure all audit configuration files in /etc/audit/ are owned by root.'
      end as reason
    from
      audit_config_files
  EOT
}
