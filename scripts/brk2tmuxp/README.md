## CML breakout to tmuxp

The script reads the CML breakout `labs.yaml` and generates [tmuxp](https://github.com/tmux-python/tmuxp) sessions.
Both YAML and JSON format are supported (default to YAML).

The sessions can then be loaded with `tmuxp load [labs]` and will perform the following:

The `windows` variant (the default) will:

1. create a tmux session named after the lab title
2. the first window created will run `breakout run` for that particular lab
3. for each node, open a node-named new window and telnet to the node

the `panes` variant will:

1. create a tmux session named after the lab title
2. the first window created will run `breakout run` for that particular lab
3. the second window will open a pane per node

<p align="right">(<a href="#top">back to top</a>)</p>

## Getting Started

### Prerequisites

Use your favorite package manager to install `tmux` and `tmuxp`, for example:

- tmux

```sh
brew install tmux
```

```sh
apt install tmux
```

- tmuxp

```sh
brew install tmuxp
```

```sh
apt install tmuxp
```

### Installation

Clone the repository, cd in the directory and install the requirements:

- pipenv

```sh
pipenv install
```

- pip

```sh
python3 -m venv /path/to/directory
pip install -r requirements
```

Note: the only dependency is `pyyaml`.

## Usage

The following options are available:

```sh
❯ python brk2tmuxp.py -h
usage: brk2tmuxp.py [-h] [-d BRK_DIR] [-f YAML_FILE] [-p] [-l LISTEN_ADDR] [-s SLEEP] [-j]

reads a CML breakout labs.yaml and generates a tmuxp session files

optional arguments:
  -h, --help            show this help message and exit
  -d BRK_DIR, --brk-dir BRK_DIR
                        path to dir containing the breakout labs YAML files (default:: current directory)
  -f YAML_FILE, --yaml-file YAML_FILE
                        name of the 'labs' YAML file, (default to labs.yaml)
  -p, --panes           if set, all telnet sessions will be in one window (default: each telnet session has its own window)
  -l LISTEN_ADDR, --listen_addr LISTEN_ADDR
                        specify the listen address (default: ::1)
  -s SLEEP, --sleep SLEEP
                        sleep time (in seconds) before initiating telnet session (default: 3)
  -j, --format-json     output JSON tmuxp session files (default: YAML)
```

### Use `breakout init` to fetch the labs and nodes from the controller:

```sh
~/CML via 🐍 v3.9.12 (brk2tmuxp)
❯ breakout init
get simplified node definitions from controller...
get active console keys from controller...
get active VNC keys from controller...
get all the labs from controller...
get all the nodes for the labs from controller...
get nodes for lab L2L IKEv2 from controller...
get nodes for lab cisco_isis_sr_101_v1 from controller...
config written.

~/CML via 🐍 v3.9.12 (brk2tmuxp)
❯ ls -l
.rwxrwxrwx  746 sgherdao 11 Mar 21:04 config.yaml
.rwxrwxrwx 1.3k sgherdao  3 May 21:50 labs.yaml
```

### Generate the "windows" variant and load it with `tmuxp`:

```sh
~/CML via 🐍 v3.9.12 (brk2tmuxp)
❯ python brk2tmuxp.py

~/CML via 🐍 v3.9.12 (brk2tmuxp)
❯ ls -l
.rw-r--r--  513 sgherdao  3 May 21:55 1eaf2c3b-9207-4524-9e7c-3eeaada67886.yaml
.rwxrwxrwx  746 sgherdao 11 Mar 21:04 config.yaml
.rw-r--r--  883 sgherdao  3 May 22:04 d231681f-a88c-4004-884a-4c9639ad8b07.yaml
.rwxrwxrwx 4.3k sgherdao  3 May 22:01 labs.yaml

~/CML via 🐍 v3.9.12 (brk2tmuxp) took 3s
❯ tmuxp load d231681f-a88c-4004-884a-4c9639ad8b07.yaml
[Loading] CML/d231681f-a88c-4004-884a-4c9639ad8b07.yaml
Already inside TMUX, switch to session? yes/no
Or (a)ppend windows in the current active session?
[y/n/a]: y
```

![windows-01](https://github.com/sgherdao/cml-community/blob/master/scripts/brk2tmuxp/windows-01.jpg?raw=true)

### Generate the "panes" variant and load it with `tmuxp`:

```sh
~/CML via 🐍 v3.9.12 (brk2tmuxp)
❯ python PythonTemp/brk2tmuxp/brk2tmuxp.py -p

~/CML via 🐍 v3.9.12 (brk2tmuxp)
❯ tmuxp load 1eaf2c3b-9207-4524-9e7c-3eeaada67886.yaml
[Loading] CML/1eaf2c3b-9207-4524-9e7c-3eeaada67886.yaml
Already inside TMUX, switch to session? yes/no
Or (a)ppend windows in the current active session?
[y/n/a]: y
❯
```

![panes-01](https://github.com/sgherdao/cml-community/blob/master/scripts/brk2tmuxp/panes-01.jpg?raw=true)

<p align="right">(<a href="#top">back to top</a>)</p>
