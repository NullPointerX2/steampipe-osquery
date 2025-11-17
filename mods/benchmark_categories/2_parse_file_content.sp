benchmark "parse_file_content" {
  title         = "2 Parse File Content"
  children = [
    control.ensure_audit_logs_not_auto_deleted,
    control.ensure_shadowed_passwords_in_etc_passwd,
  ]
}

control "ensure_audit_logs_not_auto_deleted" {
  title = "Ensure audit logs are not automatically deleted"
  description = "The max_log_file_action setting in the auditd configuration should be set to 'keep_logs' to ensure that audit logs are rotated but never automatically deleted."
  sql = <<EOT
    with auditd_conf as (
      select * from augeas where path = '/etc/audit/auditd.conf' and label = 'max_log_file_action'
    )
    select
      'augeas table' as resource,
      case
        when value = 'keep_logs' then 'ok'
        else 'alarm'
      end as status,
      case
        when value = 'keep_logs' then 'Audit logs are set to not be automatically deleted (max_log_file_action = keep_logs).'
        else 'Audit logs are not configured to keep_logs in max_log_file_action. Ensure it is set to keep_logs to avoid automatic deletion of audit logs.'
      end as reason
    from
      auditd_conf
  EOT
}

control "ensure_shadowed_passwords_in_etc_passwd" {
  title = "Ensure accounts in /etc/passwd use shadowed passwords"
  description = "Local accounts should use shadowed passwords, indicated by an 'x' in the second field of /etc/passwd. This ensures passwords are stored securely in the /etc/shadow file."
  sql = <<EOT
    with passwd_accounts as (
      select * from augeas where path = '/etc/passwd' and label = 'password'
    )
    select
      'augeas table' as resource,
      case
        when count(*) > 0 and sum(case when value != 'x' then 1 else 0 end) = 0 then 'ok'
        else 'alarm'
      end as status,
      case
        when count(*) > 0 and sum(case when value != 'x' then 1 else 0 end) = 0 then 'All accounts in /etc/passwd use shadowed passwords.'
        else 'Some accounts in /etc/passwd do not use shadowed passwords. Ensure all accounts have an "x" in the password field.'
      end as reason
    from
      passwd_accounts
  EOT
}
