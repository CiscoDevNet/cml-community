#!/usr/bin/env python3
import argparse
import sys

import jinja2
import yaml


def main() -> int:
    """
    reads a CML breakout labs.yaml file and returns a list of dict ready to be
    translated into multiple JSON or YAML tmuxp session files.

    By default, each telnet session will have its own window but if the `-p` or
    `--panes` flag is set, then each telnet session will be in a pane in one
    (and only one) window.

    VNC sessions are ignored.
    """
    parser = argparse.ArgumentParser(
        description="reads a CML breakout labs.yaml generates iterm python scripts"
    )
    parser.add_argument(
        "-d",
        "--brk-dir",
        type=str,
        default=".",
        help="path to dir containing the breakout labs YAML files (default: current directory)",
    )
    parser.add_argument(
        "-f",
        "--yaml-file",
        type=str,
        default="labs.yaml",
        help="name of the 'labs' YAML file, (default: labs.yaml)",
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
        "--jinja2-template",
        type=str,
        default="./iterm_script.j2",
        help="full path to the iterm_script.j2 Jinja2 template (default: ./iterm_script.j2)",
    )

    args = parser.parse_args()

    # load labs yaml file
    brk_dir = args.brk_dir
    yaml_file = args.yaml_file
    jinja2_template = args.jinja2_template
    with open(f"{brk_dir}/{yaml_file}") as f:
        labs = yaml.safe_load(f)

    listen_addr = args.listen_addr
    sleep = args.sleep
    iterm_scripts = {}

    for uuid, lab in labs.items():
        iterm_scripts[uuid] = brk2tabs(
            lab=lab,
            brk_dir=brk_dir,
            listen_addr=listen_addr,
        )

    with open(jinja2_template) as f:
        iterm_template = jinja2.Template(f.read())
    for uuid, it_script in iterm_scripts.items():
        with open(f"{uuid}.py", "w") as f:
            f.write(iterm_template.render(brk_lab=it_script, sleep=sleep))


def brk2tabs(lab: dict, brk_dir: str, listen_addr: str) -> dict:
    """
    Extract CML lab relevant info (port, lab title...)
    return a dict with iterm tab data

    """
    lab_title = lab["lab_title"]
    conf = {
        "session_name": lab_title,
        "tabs": [
            {
                "tab_title": "breakout",
                "shell_command": f"cd {brk_dir} && /usr/local/bin/breakout run '{lab_title}'",
            }
        ],
    }

    for _, node in lab["nodes"].items():
        node_label = node["label"]

        conf["tabs"].extend(
            [
                {
                    "tab_title": f"{node_label}/{n['name'][-1]}",
                    "shell_command": f"/usr/local/bin/telnet {listen_addr} {n['listen_port']}",
                }
                for n in node["devices"]
                if n["enabled"] and n["name"] != "vnc"
            ]
        )

    return conf


if __name__ == "__main__":
    sys.exit(main())
