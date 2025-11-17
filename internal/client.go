package osquery

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"github.com/creack/pty"
	"github.com/turbot/steampipe-plugin-sdk/v5/grpc"
	"github.com/turbot/steampipe-plugin-sdk/v5/grpc/proto"
	"github.com/turbot/steampipe-plugin-sdk/v5/plugin"
	"io"
	"os"
	"os/exec"
	"strings"
	"time"
)

const maxBufferSize = 512 * 1024 // 512KB

type Query struct {
	SQL string `json:"query"`
}

type Result struct {
	Data json.RawMessage `json:"data"`
}

type ClientConfig struct {
	OsqueryCommand string
	JsonCommand    string
	Extensions     []string
}

type Client struct {
	config      *ClientConfig
	osquery     *os.File
	osqueryJson *os.File
	extensionMx []*os.File
	ctx         context.Context
}

func startCommand(ctx context.Context, command, description string) (*os.File, error) {
	args := strings.Split(command, " ")
	plugin.Logger(ctx).Debug(fmt.Sprintf("starting %s", description), "cmd", args[0], "args", args[1:])

	cmd := exec.Command(args[0], args[1:]...)
	return pty.Start(cmd)
}

func NewClient(cfg *ClientConfig, ctx context.Context) (*Client, error) {
	var err error

	c := &Client{
		config: cfg,
		ctx:    ctx,
	}

	plugin.Logger(ctx).Debug("config: osquery command - ", cfg.OsqueryCommand)

	c.osquery, err = startCommand(ctx, cfg.OsqueryCommand, "osquery")
	if err != nil {
		plugin.Logger(ctx).Error("failed to run osquery command:", err)
		return nil, err
	}

	plugin.Logger(ctx).Debug("waiting for osquery to start")
	time.Sleep(time.Millisecond * 1000)

	plugin.Logger(ctx).Info("starting osquery steampipe extension")
	plugin.Logger(ctx).Debug("config: osquery steampipe extension command - ", cfg.JsonCommand)
	c.osqueryJson, err = startCommand(ctx, cfg.JsonCommand, "steampipe")
	if err != nil {
		plugin.Logger(ctx).Error("failed to run osquery steampipe extension command:", err)
		return nil, err
	}

	for _, extension := range cfg.Extensions {
		plugin.Logger(ctx).Info("starting extension")
		plugin.Logger(ctx).Debug("config: additional extension command - ", extension)
		mx, err := startCommand(ctx, extension, "extension")
		if err != nil {
			plugin.Logger(ctx).Error("failed to run additional osquery extension:", err)
			return nil, err
		}
		c.extensionMx = append(c.extensionMx, mx)
	}

	time.Sleep(time.Millisecond * 1000)

	return c, nil
}

func (c *Client) SendQuery(ctx context.Context, sql string) (*Result, error) {
	query := &Query{SQL: sql}
	plugin.Logger(ctx).Debug("Sending new message to osquery", "query", sql)
	encoder := json.NewEncoder(c.osqueryJson)
	if err := encoder.Encode(query); err != nil {
		return nil, err
	}

	_, err := c.osqueryJson.Write([]byte("\n"))
	if err != nil {
		return nil, err
	}

	var response string
	scanner := bufio.NewScanner(c.osqueryJson)

	buf := make([]byte, 0, maxBufferSize)
	scanner.Buffer(buf, maxBufferSize)

	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "{\"data\"") {
			response = line
			plugin.Logger(ctx).Info("Received:", line)
			break
		}
	}

	if err := scanner.Err(); err != nil {
		// log the error but don't immediately return if you have a valid response
		fmt.Println("Scanner error:", err)
	}

	if response != "" {
		return parseOsqueryResult(strings.NewReader(response)), nil
	}

	return nil, fmt.Errorf("no valid response received")
}

func (c *Client) RetrieveJSONDataForTable(ctx context.Context, d *plugin.QueryData) string {
	tablename := d.Table.Name
	qualString := ""

	if len(d.QueryContext.UnsafeQuals) > 0 {
		qualString = qualMapToString(d.QueryContext.UnsafeQuals)
	}

	if len(d.Quals) > 0 {
		qualString = equalQualsTransform(d.EqualsQuals.String())
	}

	query := fmt.Sprintf("SELECT * FROM %s", tablename)
	if qualString != "" {
		query = fmt.Sprintf("SELECT * FROM %s WHERE %s", tablename, qualString)
	}
	result, err := c.SendQuery(ctx, query)

	if err != nil {
		fmt.Println("Error:", err)
		return ""
	} else {
		return string(result.Data)
	}
}

func (c *Client) RetrieveOsqueryTableNames(ctx context.Context) []string {
	result, err := c.SendQuery(ctx, "SELECT name FROM osquery_registry WHERE registry='table'")
	if err != nil {
		fmt.Println("Error:", err)
		return nil
	}

	var tables []map[string]string
	err = json.Unmarshal(result.Data, &tables)
	if err != nil {
		fmt.Println("Error unmarshalling:", err)
		return nil
	}

	var tableNames []string
	for _, table := range tables {
		tableNames = append(tableNames, table["name"])
	}

	return tableNames
}

func (c *Client) RetrieveTableDefinition(ctx context.Context, tablename string) ([]map[string]interface{}, error) {
	jsonData := ""

	query := fmt.Sprintf("PRAGMA table_info(%s);", tablename)
	result, err := c.SendQuery(ctx, query)

	if err != nil {
		jsonData = "{\"data\":[{\"name\":\"error\"}]"
	} else {
		jsonData = string(result.Data)
	}

	var tableDef []map[string]interface{}
	err = json.Unmarshal([]byte(jsonData), &tableDef)
	if err != nil {
		plugin.Logger(ctx).Error("Error unmarshalling:", "err", err)
		return nil, err
	}

	return tableDef, nil
}

func (c *Client) Stop() {
	if c.osquery != nil {
		c.osquery.Close()
	}
	if c.osqueryJson != nil {
		c.osqueryJson.Close()
	}
	for _, mx := range c.extensionMx {
		if mx != nil {
			mx.Close()
		}
	}
}

func parseOsqueryResult(r io.Reader) *Result {
	decoder := json.NewDecoder(r)
	result := &Result{}
	if err := decoder.Decode(result); err != nil {
		fmt.Println("Error decoding osquery result:", err)
		return nil
	}

	return result
}

func qualMapToString(qualMap map[string]*proto.Quals) string {
	if len(qualMap) == 0 {
		return ""
	}

	var sb strings.Builder

	firstKey := true
	for _, quals := range qualMap {
		if !firstKey {
			sb.WriteString(" and ")
		} else {
			firstKey = false
		}

		var qb strings.Builder
		for i, q := range quals.GetQuals() {
			str := qualToString(q)
			qb.WriteString(str)
			// if it's not the last qual, append "and"
			if i < len(quals.GetQuals())-1 {
				qb.WriteString(" and ")
			}
		}
		sb.WriteString(qb.String())
	}

	return sb.String()
}

func qualToString(q *proto.Qual) string {
	fieldName := q.FieldName
	operator := q.GetStringValue()
	value := grpc.GetQualValue(q.Value)

	return "\"" + fieldName + "\" " + operator + " \"" + fmt.Sprintf("%v", value) + "\""
}

// transform 'ab = cd' to '"ab" = "cd"'
func equalQualsTransform(input string) string {
	parts := strings.Split(input, "=")
	if len(parts) != 2 {
		return ""
	}

	key := strings.TrimSpace(parts[0])
	value := strings.TrimSpace(parts[1])

	return fmt.Sprintf(`"%s" = "%s"`, key, value)
}
