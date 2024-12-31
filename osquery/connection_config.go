package osquery

import (
	"github.com/turbot/steampipe-plugin-sdk/v5/plugin"
	"github.com/turbot/steampipe-plugin-sdk/v5/plugin/schema"
)

type osqueryConfig struct {
	Server   *string `cty:"osquery_server"`
	Json     *string `cty:"osquery_json"`
	FileRead *string `cty:"osquery_file_read"`
}

var ConfigSchema = map[string]*schema.Attribute{
	"osquery_server": {
		Type: schema.TypeString,
	},
	"osquery_json": {
		Type: schema.TypeString,
	},
	"osquery_file_read": {
		Type: schema.TypeString,
	},
}

func ConfigInstance() interface{} {
	return &osqueryConfig{}
}

// GetConfig :: retrieve and cast connection config from query data
func GetConfig(connection *plugin.Connection) osqueryConfig {
	if connection == nil || connection.Config == nil {
		return osqueryConfig{}
	}
	config, _ := connection.Config.(osqueryConfig)
	return config
}
