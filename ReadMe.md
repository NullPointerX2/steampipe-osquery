# Steampipe Osquery Plugin

## Setup for Linux Ubuntu

### Install Base Tooling

1. Install Steampipe

Install Steampipe on the host you want to use to audit the other systems.

https://steampipe.io/downloads

2. Install Powerpipe

Install Powerpipe on the host you want to use to audit the other systems.

Since March 2024 Powerpipe is the recommended way to run former Steampipe mods.

https://powerpipe.io/downloads

3. Install osquery

Install osquery on all systems you want to audit. Note: When installing osquery using the apt-repository, we recommend to use the version prior to 22.04, as this version runs more stable.

https://osquery.io/downloads

4. Install go

You can download and install go using established paket managers or follow the documentation.

https://golangdocs.com/install-go-linux

### Setup Plugins

#### osquery Plugin

This is pre-requisite for the Steampipe plugin to work. 
Run this on the system(s) you want to audit.

**1. Clone Repository**

```
git clone https://github.com/NullPointerX2/osquery-steampipe.git
```

**2. Build Steampipe Extension**

```
go build -o $HOME/.osquery/steampipe_extension server/extension.go
```

**3. Build File Read Extension**

```
go build -o $HOME/.osquery/file_read_extension file_read_extension/file_read_extension.go
```

#### Steampipe Plugin

Run this on your "audit host", i.e., the system you want to use to audit the other systems.

**1. Clone Repository**

```
git clone https://github.com/NullPointerX2/steampipe-osquery.git
```

**2. Build Plugin To .steampipe**

At this point, it is important to ensure that the $HOME variable is correctly initialized. This can be checked using the command `echo $HOME`.

```
go build -gcflags=all="-N -l" -o "$HOME/.steampipe/plugins/local/osquery/osquery.plugin"
```

**3. Copy Config Folder To .steampipe**

```
cp -r config $HOME/.steampipe/
```

Information on the config parameters:

- `osquery_server` (default: `osqueryi`): this parameter is the command that starts osquery which also results in the creation of an osquery socket (by default $HOME/.osquery/shell.em) that the extensions use. 
- `osquery_json` (default: `$HOME/.osquery/steampipe_extension --socket $HOME/.osquery/shell.em`): this parameter is the command that starts the osquery extension that the Steampipe plugin interacts with to run queries. 
- `osquery_file_read` (default: `$HOME/.osquery/file_read_extension --socket $HOME/.osquery/shell.em`): this parameter is the command that starts the extension that is used to read arbitrary files on the system. 

##### Use with SSH

Step 4 and 5 are not needed for a local test setup, only for setups using SSH.

**4. SSH Setup**

1. Adjust Config To Use ControlMaster

As no SSH authentication can be done interactively within Steampipe, the plugins needs to reuse an already existing SSH connection to connect to the target. For this, ControlMaster (https://man.openbsd.org/ssh_config.5#ControlMaster) can be used. Before using the plugin, a connection to the target system needs to be established manually once. `ControlPersist` can be adjusted as needed (3600 = 1 hour).

`$HOME/.ssh/config`

```
Host $hostname
  User $user
```

2. Create ControlPath Folder

```
mkdir -p ~/.ssh/cm_socket
```

**5. Adjust Config File**

**Important:** Make sure to replace $HOME with the actual home path in the config file as the $HOME env var might not be available in the $hostname0 that is used to execute this command.

`$HOME/.steampipe/config/osquery.spc`

```
connection "osquery" {
  plugin = "local/osquery"

  # suppress ssh banners: ssh -o LogLevel=error hostname osqueryi
  # needed to create the osqueryi extension socket
  osquery_server = "ssh -o LogLevel=error $hostname01 osqueryi --nodisable-extensions" # if empty, defaults to "osqueryi"
  osquery_json = "ssh -o LogLevel=error $hostname01 /home/ubuntu/.osquery/steampipe_extension --socket /home/ubuntu/.osquery/shell.em" # if empty, defaults to "$HOME/.osquery/steampipe_extension --socket $HOME/.osquery/shell.em"
  osquery_file_read = "ssh -o LogLevel=error $hostname01 /home/ubuntu/.osquery/file_read_extension --socket /home/ubuntu/.osquery/shell.em" # if empty, defaults to "$HOME/.osquery/file_read_extension --socket $HOME/.osquery/shell.em"

}

options "database" {
  # this is needed because the additionally implemented table file_content does not support caching
  cache = false
}
```

**Multiple Connections**

**Important:** Make sure to replace $HOME with the actual home path in the config file as the $HOME env var might not be available in the PTY that is used to execute this command.

`$HOME/.steampipe/config/osquery.spc`

```
connection "osquery01" {
  plugin = "local/osquery"

  # suppress ssh banners: ssh -o LogLevel=error hostname osqueryi
  # needed to create the osqueryi extension socket
  osquery_server = "ssh -o LogLevel=error $hostname01 osqueryi --nodisable-extensions" # if empty, defaults to "osqueryi"
  osquery_json = "ssh -o LogLevel=error $hostname01 /home/ubuntu/.osquery/steampipe_extension --socket /home/ubuntu/.osquery/shell.em" # if empty, defaults to "$HOME/.osquery/steampipe_extension --socket $HOME/.osquery/shell.em"
  osquery_file_read = "ssh -o LogLevel=error $hostname01 /home/ubuntu/.osquery/file_read_extension --socket /home/ubuntu/.osquery/shell.em" # if empty, defaults to "$HOME/.osquery/file_read_extension --socket $HOME/.osquery/shell.em"

}

connection "osquery02" {
  plugin = "local/osquery"

  # suppress ssh banners: ssh -o LogLevel=error hostname osqueryi
  # needed to create the osqueryi extension socket
  osquery_server = "ssh -o LogLevel=error $hostname02 osqueryi --nodisable-extensions" # if empty, defaults to "osqueryi"
  osquery_json = "ssh -o LogLevel=error $hostname02 /home/ubuntu/.osquery/steampipe_extension --socket /home/ubuntu/.osquery/shell.em" # if empty, defaults to "$HOME/.osquery/steampipe_extension --socket $HOME/.osquery/shell.em"
  osquery_file_read = "ssh -o LogLevel=error $hostname02 /home/ubuntu/.osquery/file_read_extension --socket /home/ubuntu/.osquery/shell.em" # if empty, defaults to "$HOME/.osquery/file_read_extension --socket $HOME/.osquery/shell.em"

}

options "database" {
  # this is needed because the additionally implemented table file_content does not support caching
  cache = false
}
```

## Usage

### Basic Usage

#### Manual Queries

Run Steampipe

```
steampipe query
```

Run Query (`osquery01` being the name of the connection specified in the config file)

```
> select * from osquery01.time;
```

#### Install and run mods

**Install mods**

```
cd mods/benchmark_categories
powerpipe mod init
cd ..
powerpipe mod init
powerpipe mod install benchmark_categories
```

In both directories, new files named "mod.sh" should have been created.

**Check If Mod Is Installed**

```
powerpipe mod list
```

**List Benchmarks**

```
powerpipe benchmark list
```

Example:

```
$ powerpipe benchmark list
MOD      NAME
local    local.benchmark.access_to_fs
local    local.benchmark.access_to_package_mangement_system
local    local.benchmark.get_runtime_information_about_os_components
local    local.benchmark.get_runtime_information_about_the_operating_system_from_kernel
local    local.benchmark.parse_file_content
```

**Start service**

Open a second terminal window and run ```steampipe service start```

**Run Benchmark**

In the first terminal window, you either enter 
```
powerpipe server
```

and use the front end deployed under the localhost adress presented, or do not enter this command and use the CLI instead using the following: 

```
powerpipe benchmark run $benchmark_name
```

Example:

```
$ powerpipe benchmark run local.benchmark.access_to_fs

1 Access to File System ............................................................................................................................................................. 3 / 5 [==========]
| 
+ Ensure permissions on /etc/issue are configured ................................................................................................................................... 0 / 1 [==        ]
| | 
| OK   : Permissions on /etc/issue are correctly configured. 
| 
+ Ensure /tmp is a separate partition ..................................................................................................
[..]
```

**List Single Controls**

```
powerpipe control list
```

**Run Single Control**

```
powerpipe control run $control_name
```

## Further Useful Information

**Change Steampipe Log Level**

```
export STEAMPIPE_LOG_LEVEL=DEBUG
```

**Steampipe Log File Path**

```
$HOME/.steampipe/logs
```
