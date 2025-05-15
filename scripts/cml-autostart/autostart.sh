#!/bin/bash

ensure_dir() {
    local install_dir="$1"
    if ! test -d "$install_dir"; then
        echo "Error: $install_dir isn't there"
        exit 1
    fi
}

install_default() {
    local install_dir="/etc/default"
    ensure_dir $install_dir
    cat >"$install_dir/$(basename cml-autostart)" <<EOF
USERNAME="admin"
PASSWORD="password-that-needs-to-be-changed"
TITLE_REGEX="\(autostart\)"
EOF
    chown root:root "$install_dir/$(basename cml-autostart)"
    chmod 0600 "$install_dir/$(basename cml-autostart)"
}

install_script() {
    local install_dir="/usr/local/bin"
    ensure_dir $install_dir
    cat >"$install_dir/$(basename cml-autostart.sh)" <<EOF
#!/bin/bash

# set variables
source /etc/default/cml-autostart
HOST="ip6-localhost"

# set -x

API="https://\${HOST}/api/v0"

# wait until the system is ready
until [ "true" = "\$(curl -skX GET \$API/system_information | jq -r .ready)" ]; do
  echo "Waiting for controller to be ready..."
  sleep 5
done

# get authentication token
TOKEN=\$(curl -skX POST "\${API}/authenticate" \\
        -H "Content-Type: application/json" \\
        -d '{"username":"'\${USERNAME}'","password":"'\${PASSWORD}'"}' |
        jq -r .)
  
# get all labs
LABS=\$(curl -skX GET "\${API}/labs?show_all=true" \\
            -H "Authorization: Bearer \${TOKEN}")
  
while read lab; do
  labinfo=\$(curl -skX GET "\${API}/labs/\${lab}" \\
            -H "Authorization: Bearer \${TOKEN}")
  description=\$(echo \$labinfo | jq -r '.lab_description')
  title=\$(echo \$labinfo | jq -r '.lab_title')
  if [[ "\${description}" =~ \${TITLE_REGEX} ]]; then
    curl -skX PUT "\${API}/labs/\${lab}/start" \\
    -H "Authorization: Bearer \${TOKEN}"
    echo "Lab '\${title}' (ID: \${lab}) start initiated"
  fi
done <<<\$(echo \$LABS | jq -r '. | join("\n")')
exit
EOF
    chown root:root "$install_dir/$(basename cml-autostart.sh)"
    chmod a+x "$install_dir/$(basename cml-autostart.sh)"
}

install_service_unit() {
    local install_dir="/etc/systemd/system"
    ensure_dir $install_dir
    cat >"$install_dir/$(basename cml-autostart.service)" <<EOF
[Unit]
Description=Start CML Lab
After=network.target
After=virl2.target
  
[Service]
Type=oneshot
ExecStart=/usr/local/bin/cml-autostart.sh
User=virl2
  
[Install]
WantedBy=multi-user.target
EOF
    chown root:root "$install_dir/$(basename cml-autostart.service)"
    systemctl daemon-reload
    systemctl enable cml-autostart.service
}

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
fi

echo -n "installing defaults"
install_default
echo -e "\t✅"
echo -n "installing script"
install_script
echo -e "\t✅"
echo -n "installing service unit"
install_service_unit
echo -e "\t✅"

cat <<EOF
******************************************************************************
* ⚠️ IMPORTANT! ⚠️                                                           *
* you need to ensure that you change the username and password for a user of *
* the system that can start the labs in /etc/default/cml-autostart           *
*                                                                            *
* Add the string "(autostart)" to the description of each lab that you wish  *
* to start automatically.                                                    *
******************************************************************************
EOF
