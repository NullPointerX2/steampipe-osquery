benchmark "parse_file_content" {
  title         = "2 Parse File Content"
  children = [
    control.ensure_audit_logs_not_auto_deleted,
    control.ensure_shadowed_passwords_in_etc_passwd,
    control.password_failed_attempts_lockout,
  ]
}

control "ensure_audit_logs_not_auto_deleted" {
  title = "Ensure audit logs are not automatically deleted"
  description = "The max_log_file_action setting in the auditd configuration should be set to 'keep_logs' to ensure that audit logs are rotated but never automatically deleted."
  sql = <<EOT
    WITH auditd_conf AS (
        SELECT * 
        FROM augeas 
        WHERE path = '/etc/audit/auditd.conf' AND label = 'max_log_file_action'
    )
    SELECT 
        'augeas table' AS resource,
        CASE
            WHEN auditd_conf.value = 'keep_logs' THEN 'ok'
            WHEN auditd_conf.value IS NULL THEN 'alarm'
            ELSE 'alarm'
        END AS status,
        CASE
            WHEN auditd_conf.value = 'keep_logs' THEN 'Audit logs are set to not be automatically deleted (max_log_file_action = keep_logs).'
            WHEN auditd_conf.value IS NULL THEN 'Audit configuration for max_log_file_action is missing. Ensure that the file exists and contains the correct configuration.'
            ELSE 'Audit logs are not configured to keep_logs in max_log_file_action. Ensure it is set to keep_logs to avoid automatic deletion of audit logs.'
        END AS reason
    FROM auditd_conf
    UNION
    SELECT 
        'augeas table' AS resource,
        'alarm' AS status,
        'Audit configuration for max_log_file_action is missing. Ensure that the file exists and contains the correct configuration.' AS reason
    WHERE NOT EXISTS (
        SELECT 1 FROM augeas WHERE path = '/etc/audit/auditd.conf' AND label = 'max_log_file_action'
    );
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

control "password_failed_attempts_lockout" {
  title = "Ensure password failed attempts lockout is configured"
  description = "Locking out user IDs after n unsuccessful consecutive login attempts mitigates bruteforce password attacks against your systems."
  sql = <<EOT
    WITH faillock_config AS (
        SELECT content
        FROM file_content
        WHERE path = '/etc/security/faillock.conf'
    )
    SELECT
        'faillock configuration' AS resource,
        CASE
            WHEN content LIKE '%deny%' AND CAST(SUBSTRING(content FROM 'deny\s*=\s*(\d+)') AS INT) <= 5 THEN 'ok'
            WHEN content LIKE '%deny%' THEN 'alarm'
            ELSE 'alarm'
        END AS status,
        CASE
            WHEN content LIKE '%deny%' AND CAST(SUBSTRING(content FROM 'deny\s*=\s*(\d+)') AS INT) <= 5 THEN 'The deny option is set correctly (<= 5).'
            WHEN content LIKE '%deny%' THEN 'The deny option is set to a value greater than 5. Ensure it is set to 5 or less.'
            ELSE 'The deny option is missing. Ensure it is configured with a valid value.'
        END AS reason
    FROM faillock_config;
  EOT
}