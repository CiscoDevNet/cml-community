\
# CML2 Consoles in Wave Terminal (Linux)

A lightweight launcher that integrates **Cisco Modeling Labs 2 (CML2)** with **Wave Terminal**, automatically creating one terminal block for each device console.

This project uses the **CML2 breakout** utility as a local console proxy together with Wave Terminal's `wsh run` command.

> **Repository:** `cml-breakout-wave-terminal`

Repository Base: https://github.com/hendapaim/cml-breakout-wave-terminal
---

# Features

- 🚀 Automatic Wave Terminal console creation
- 🔄 Refreshes CML topology every launch
- 🔌 Automatically starts the Breakout proxy when required
- 🖥️ One terminal block per enabled serial console
- 📦 Portable launcher (directory can be moved or renamed)
- 🔒 Local-only console listener by default (`[::1]`)
- ⚡ Supports `telnet`, `nc`, or `ncat`

---

# Requirements

- Linux
- Cisco Modeling Labs 2
- Python 3
- Wave Terminal
- CML2 `breakout` binary
- One of:
  - `telnet`
  - `netcat-openbsd (nc)`
  - `ncat`

---

# Project Structure

```text
.
├── breakout
├── config.yaml
├── labs.yaml
├── main.py
├── wave-cml2
└── README.md
```

---

# Initial Setup

Export your CML credentials:

```bash
export BREAKOUT_USERNAME=admin
export BREAKOUT_PASSWORD='your-cml2-password'
```

Initialize the project:

```bash
./breakout -config config.yaml -labs labs.yaml init INIT

python3 main.py INIT
```

This command:

- Connects to CML2
- Detects the selected lab
- Retrieves console port assignments
- Writes the information into `labs.yaml`

Review `labs.yaml` and ensure the desired lab and devices are enabled.

---

# Launch Consoles

Run:

```bash
python3 main.py INIT --run
```

or execute the generated launcher directly:

```bash
./wave-cml2
```

Every launch automatically:

1. Refreshes the lab from CML2
2. Updates console port assignments
3. Rebuilds the launcher
4. Starts the Breakout proxy if necessary
5. Waits until the local proxy is ready
6. Opens one Wave Terminal block for every enabled serial console

No manual port management is required.

---

# Using a Different Console Host

The launcher searches for the following files relative to its own location:

- `breakout`
- `config.yaml`
- `labs.yaml`

Because of this, the directory can be moved without modifying paths.

To temporarily use another console proxy:

```bash
CONSOLE_HOST=127.0.0.1 ./wave-cml2
```

---

# Security

By default the Breakout listener binds only to:

```text
[::1]
```

This keeps console ports accessible only from the local machine.

---

# Supported Console Clients

The launcher automatically uses the first available client:

1. `telnet`
2. `nc`
3. `ncat`

Install `netcat-openbsd` if none are already installed.

---

# Legacy Note

`config.ini` is retained only for backward compatibility.

The recommended workflow uses:

- `config.yaml`
- `labs.yaml`
- `wave-cml2`

---

# Workflow

```text
CML2
   │
   ▼
breakout
   │
   ▼
Local Console Proxy
   │
   ▼
wave-cml2
   │
   ▼
Wave Terminal
   │
   ├── Router 1
   ├── Router 2
   ├── Switch 1
   └── ...
```

---


# Author
Henda Paim - https://www.linkedin.com/in/hendapaim0

# License

Use and modify freely according to the license included in this repository.