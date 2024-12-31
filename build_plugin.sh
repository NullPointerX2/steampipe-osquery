#!/bin/sh

go build -gcflags=all="-N -l" -o "/home/ubuntu/.steampipe/plugins/local/osquery/osquery.plugin"
