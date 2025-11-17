package osquery

import (
	"context"

	"github.com/turbot/steampipe-plugin-sdk/v5/plugin"
	"github.com/turbot/steampipe-plugin-sdk/v5/plugin/transform"
)

func Plugin(ctx context.Context) *plugin.Plugin {
	p := &plugin.Plugin{
		Name: "steampipe-plugin-osquery",
		ConnectionConfigSchema: &plugin.ConnectionConfigSchema{
			NewInstance: ConfigInstance,
			Schema:      ConfigSchema,
		},
		DefaultTransform: transform.FromGo().NullIfZero(),
		SchemaMode:       plugin.SchemaModeDynamic,
		TableMapFunc:     PluginTables,
	}
	return p
}

func PluginTables(ctx context.Context, d *plugin.TableMapData) (map[string]*plugin.Table, error) {
	tables := map[string]*plugin.Table{}

	conn, err := connect(ctx, d.Connection, d.ConnectionCache)
	if err != nil {
		return nil, err
	}

	// retrieve all osquery table names
	osqueryTableNames := conn.RetrieveOsqueryTableNames(ctx)

	// create a table for each osquery table
	for _, tablename := range osqueryTableNames {
		tables[tablename], err = tableOsquery(ctx, d.Connection, d.ConnectionCache, tablename)
	}
	if err != nil {
		return nil, err
	}

	// Add the file_lines table statically
    //tables["file_lines"] = staticFileLinesTable(ctx)

	return tables, nil
}
