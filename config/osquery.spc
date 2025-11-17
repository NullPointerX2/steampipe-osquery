connection "osquery" {
  plugin = "local/osquery"

  # suppress ssh banners: ssh -o LogLevel=error localhost osqueryi
  # needed to create the osqueryi extension socket
  osquery_server = "" # if empty, defaults to "osqueryi"
  osquery_json = "" # if empty, defaults to "$HOME/.osquery/steampipe_extension --socket $HOME/.osquery/shell.em"
  osquery_file_read = "" # if empty, defaults to "$HOME/.osquery/file_read_extension --socket $HOME/.osquery/shell.em"

}

options "database" {
  # this is needed because the additionally implemented table file_content does not support caching
  cache = false
}