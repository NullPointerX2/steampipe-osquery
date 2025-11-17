control "check_users_table_not_empty" {
  title = "Ensure 'users' table is not empty"
  sql = <<EOT
    with user_data as (
      select * from users
    )
    select
      'users table' as resource,
      case
        when count(*) > 0 then 'ok'
        else 'alarm'
      end as status,
      case
        when count(*) > 0 then 'The users table has data.'
        else 'The users table is empty.'
      end as reason
    from
      user_data
  EOT
}

control "check_time_table_not_empty" {
  title = "Ensure 'time' table is not empty"
  sql = <<EOT
    with time_data as (
      select * from time
    )
    select
      'time table' as resource,
      case
        when count(*) > 0 then 'ok'
        else 'alarm'
      end as status,
      case
        when count(*) > 0 then 'The time table has data.'
        else 'The time table is empty.'
      end as reason
    from
      time_data
  EOT
}

benchmark "first_bench" {
  title = "First Benchmark"
  children = [
    control.check_users_table_not_empty,
    control.check_time_table_not_empty,
  ]
}
