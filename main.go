package main

import (
    "github.com/turbot/steampipe-plugin-sdk/v5/plugin"
    "steampipe-plugin-osquery/osquery"
)

func main() {
    plugin.Serve(&plugin.ServeOpts{PluginFunc: osquery.Plugin})
}
