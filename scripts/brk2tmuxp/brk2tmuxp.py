#!/usr/bin/env python3
import argparse
import json
import sys

import yaml


def main():
    """
    reads a CML breakout labs.yaml file and returns a list of dict ready to be
    translated into multiple JSON or YAML tmuxp session files.

    By default, each telnet session will have its own window but if the `-p` or
    `--panes` flag is set, then each telnet session will be in a pane in one
    (and only one) window.

    VNC sessions are ignored.
    """
    parser = argparse.ArgumentParser(
        description="reads a CML breakout labs.yaml and generates a tmuxp session files"
    )
    parser.add_argument(
        "-d",
        "--brk-dir",
        type=str,
        default=".",
        help="path to dir containing the breakout labs YAML files (default:: current directory)",
    )
    parser.add_argument(
        "-f",
        "--yaml-file",
        type=str,
        default="labs.yaml",
        help="name of the 'labs' YAML file, (default to labs.yaml)",
    )
    parser.add_argument(
        "-p",
        "--panes",
        help="if set, all telnet sessions will be in one window (default: each telnet session has its own window)",
        action="store_true",
    )
    parser.add_argument(
        "-l",
        "--listen_addr",
        default="::1",
        help="specify the listen address (default: ::1)",
    )
    parser.add_argument(
        "-s",
        "--sleep",
        type=float,
        default="3",
        help="sleep time (in seconds) before initiating telnet session (default: 3)",
    )
    parser.add_argument(
        "-j",
        "--format-json",
        action="store_true",
        help="output JSON tmuxp session files (default: YAML)",
    )
    args = parser.parse_args()

    # load labs yaml file
    brk_dir = args.brk_dir
    yaml_file = args.yaml_file

    with open(f"{brk_dir}/{yaml_file}") as f:
        labs = yaml.safe_load(f)

    panes = args.panes
    listen_addr = args.listen_addr
    sleep = args.sleep
    format_json = args.format_json
    tmux_sessions = {}

    for uuid, lab in labs.items():
        if panes:
            tmux_sessions[uuid] = panes_configs(
                lab=lab, brk_dir=brk_dir, listen_addr=listen_addr, sleep=sleep
            )

        else:
            tmux_sessions[uuid] = windows_configs(
                lab=lab, brk_dir=brk_dir, listen_addr=listen_addr, sleep=sleep
            )

    for uuid, tmux_session in tmux_sessions.items():
        if format_json:
            with open(f"{uuid}.json", "w") as f:
                json.dump(tmux_session, f, indent=2)
        else:
            with open(f"{uuid}.yaml", "w") as f:
                yaml.dump(tmux_session, f)


def panes_configs(lab: dict, brk_dir: str, listen_addr: str, sleep: float) -> dict:
    """
    returns a dict representing a tmuxp session file for one CML lab

    This is the 'panes' variant, the tmuxp session will consist of:
     - one session named based on the lab title containing:
       - the first window will cd into the CML dir and launch `breakout run`
         for that lab
       - subsequent windows, will telnet to one lab node
    """
    lab_title = lab["lab_title"]
    conf = {
        "session_name": lab_title,
        "windows": [
            {
                "window_name": "breakout",
                "panes": [
                    {
                        "shell_command": [
                            f"cd {brk_dir}",
                            f"breakout run '{lab_title}'",
                        ]
                    }
                ],
            },
            {"window_name": "nodes", "layout": "tiled"},
        ],
    }
    panes: list = []
    for _, node in lab["nodes"].items():
        node_label = node["label"]

        panes.extend(
            {
                "shell_command":
                # dirty way to set tmux pane title
                # see https://github.com/tmux-python/tmuxp/issues/384
                [
                    f"printf '\\033]2;%s\\033\\\\' '{node_label}/{n['name'][-1]}'",
                    f"time sleep {sleep}",
                    f"telnet {listen_addr} {n['listen_port']}",
                ]
            }
            for n in node["devices"]
            if n["enabled"] and n["name"] != "vnc"
        )

    conf["windows"][1]["panes"] = panes
    return conf


def windows_configs(lab: dict, brk_dir: str, listen_addr: str, sleep: int) -> dict:
    """
    returns a dict representing a tmuxp session file for one CML lab

    This is the 'windows' variant, the tmuxp session will consist of:
     - one session named based on the lab title containing:
       - the first window will launch `breakout run` for that lab
       - next windows, will telnet to one lab node
    """
    lab_title = lab["lab_title"]
    conf = {
        "session_name": lab_title,
        "windows": [
            {
                "window_name": "breakout",
                "panes": [
                    {
                        "shell_command": [
                            f"cd {brk_dir}",
                            f"breakout run '{lab_title}'",
                        ]
                    }
                ],
            },
        ],
    }

    for _, node in lab["nodes"].items():
        node_label = node["label"]

        conf["windows"].extend(
            {
                "window_name": f"{node_label}/{n['name'][-1]}",
                "panes": [
                    {
                        "shell_command": [
                            f"time sleep {sleep}",
                            f"telnet {listen_addr} {n['listen_port']}",
                        ]
                    }
                ],
            }
            for n in node["devices"]
            if n["enabled"] and n["name"] != "vnc"
        )

    return conf


if __name__ == "__main__":
    sys.exit(main())
