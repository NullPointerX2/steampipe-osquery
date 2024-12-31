benchmark "get_runtime_information_about_os_components" {
  title         = "3 Get Runtime Information About OS Components"
  children = [
    control.check_permissions_on_etc_issue,
  ]
}