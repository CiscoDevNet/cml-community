#!/usr/bin/env python3
#
# Copyright (c) 2025  Joe Clarke <jclarke@cisco.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

import os
import sys
import time
import threading
import requests
import logging
from prometheus_client import start_http_server, Gauge
from requests.packages.urllib3.exceptions import InsecureRequestWarning  # type: ignore

requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

CML_HOST = "https://ip6-localhost"  # CML server URL; this should not need to be changed

# Configuration (set in the /etc/default/cml-exporter file)
CML_USERNAME = os.environ.get("CML_USERNAME", "admin")  # CML username
CML_PASSWORD = os.environ.get("CML_PASSWORD", "password")  # CML password
EXPORTER_PORT = int(os.environ.get("EXPORTER_PORT", "9100"))  # Port for Prometheus exporter
POLL_INTERVAL = int(os.environ.get("POLL_INTERVAL", "15"))  # Polling interval in seconds
API_TIMEOUT = int(os.environ.get("API_TIMEOUT", "10"))  # API request timeout in seconds
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO").upper()  # Logging level
MAX_ERRORS = int(os.environ.get("MAX_ERRORS", "4"))  # Max number of errors before stopping

# Set up logging
logging.basicConfig(level=LOG_LEVEL, format="%(asctime)s %(levelname)s %(threadName)s %(name)s: %(message)s")
logger = logging.getLogger("cml-exporter")

# Prometheus metrics definitions
cpu_usage = Gauge("cml_cpu_usage_percent", "CML CPU usage percent", ["host", "is_compute"])
memory_usage = Gauge("cml_memory_usage_percent", "CML memory usage percent", ["host", "is_compute"])
disk_usage = Gauge("cml_disk_usage_percent", "CML disk usage percent", ["host", "is_compute"])
labs_running = Gauge("cml_labs_running_total", "Number of labs running")
labs_running_per_user = Gauge("cml_labs_running_per_user", "Labs running per user", ["username"])
nodes_running_per_user = Gauge("cml_nodes_running_per_user", "Nodes running per user", ["username"])
nodes_running = Gauge("cml_nodes_running_total", "Number of total nodes running")


class CMLClient(object):
    """
    Client for interacting with the CML API.
    Handles authentication and provides methods to fetch system and lab information.
    """

    def __init__(self, host, username, password):
        self.base_url = host.rstrip("/")
        self.session = requests.Session()
        self.session.verify = False  # This typically can be left as False, even if using valid certs.
        self.token = None
        self.username = username
        self.password = password

        # Counter for number of successive failures.
        self.error_count = 0

    def login(self) -> None:
        """
        Authenticate with the CML API and store the token for future requests.
        """
        url = f"{self.base_url}/api/v0/authenticate"
        try:
            resp = self.session.post(
                url,
                json={"username": self.username, "password": self.password},
                timeout=API_TIMEOUT,
            )
            resp.raise_for_status()
            self.token = resp.json()
            self.session.headers.update({"Authorization": f"Bearer {self.token}"})
            logger.info("Authenticated with CML API")
        except Exception as e:
            logger.exception(f"Failed to authenticate with CML API: {e}")
            raise

    def check_authentication(self) -> None:
        """
        Check if the current session is authenticated.
        If not, re-authenticate.
        """
        if self.token:
            url = f"{self.base_url}/api/v0/authok"
            try:
                resp = self.session.get(url, timeout=API_TIMEOUT)
                resp.raise_for_status()
            except requests.HTTPError as e:
                if e.response.status_code == 401:  # Unauthorized, re-authenticate
                    logger.debug("Authentication failed, re-authenticating")
                    self.token = None
            except requests.RequestException as e:
                logger.error(f"Error checking authentication: {e}")
                raise

        # If token is None or authentication failed, re-authenticate
        if not self.token:
            logger.debug("Re-authenticating with CML API")
            self.login()

    def get_system_stats(self) -> dict:
        """
        Retrieve system statistics (CPU, memory, disk usage) from CML.
        """
        url = f"{self.base_url}/api/v0/system_stats"
        resp = self.session.get(url, timeout=API_TIMEOUT)
        resp.raise_for_status()
        return resp.json()

    def get_labs(self) -> list:
        """
        Get a list of all lab IDs in the CML system.
        """
        url = f"{self.base_url}/api/v0/labs"
        resp = self.session.get(url, timeout=API_TIMEOUT)
        resp.raise_for_status()
        return resp.json()

    def get_lab_details(self, lab_id: str) -> dict:
        """
        Get details (state, owner, nodes running) for a specific lab.
        """
        url = f"{self.base_url}/api/v0/labs/{lab_id}"
        resp = self.session.get(url, timeout=API_TIMEOUT)
        resp.raise_for_status()
        return resp.json()

    def get_lab_element_states(self, lab_id: str) -> dict:
        """
        Get the states of all elements in a specific lab.
        """
        url = f"{self.base_url}/api/v0/labs/{lab_id}/lab_element_state"
        resp = self.session.get(url, timeout=API_TIMEOUT)
        resp.raise_for_status()
        return resp.json()


def collect_metrics(client: CMLClient) -> None:
    """
    Collect metrics from the CML API and update Prometheus gauges.
    """
    try:
        client.check_authentication()  # Ensure we are authenticated
        logger.debug("Collecting metrics from CML API")
        # [Cluster] System stats
        sys_stats = client.get_system_stats()
        for _, compute_stats in sys_stats.get("computes", {}).items():
            stats = compute_stats.get("stats", {})
            cpu_stats = stats.get("cpu", {})
            memory_stats = stats.get("memory", {})
            disk_stats = stats.get("disk", {})
            cpu_usage.labels(host=compute_stats.get("hostname", "unknown"), is_compute=True).set(cpu_stats.get("percent", 0))
            memory_usage.labels(host=compute_stats.get("hostname", "unknown"), is_compute=True).set(
                memory_stats.get("used", 0) / memory_stats.get("total", 1) * 100
            )

            if not compute_stats.get("is_controller", False):
                disk_usage.labels(host=compute_stats.get("hostname", "unknown"), is_compute=True).set(
                    disk_stats.get("used", 0) / disk_stats.get("total", 1) * 100
                )

        controller_stats = sys_stats.get("controller", {})
        controller_disk_stats = controller_stats.get("disk", {})
        disk_usage.labels(host="cml-controller", is_compute=False).set(
            controller_disk_stats.get("used", 0) / controller_disk_stats.get("total", 1) * 100
        )

        # Labs and nodes
        labs = client.get_labs()
        running_labs = 0
        total_nodes_running = 0
        user_node_count = {}
        user_lab_count = {}

        # Iterate through all labs to count running labs and nodes, and labs per user
        for lab_id in labs:
            lab_details = client.get_lab_details(lab_id)
            if lab_details.get("state") == "STARTED":
                running_labs += 1
                owner = lab_details.get("owner_username", "unknown")
                user_lab_count[owner] = user_lab_count.get(owner, 0) + 1
                element_states = client.get_lab_element_states(lab_id)
                for _, node_state in element_states.get("nodes", {}).items():
                    if node_state == "BOOTED":
                        total_nodes_running += 1
                        user_node_count[owner] = user_node_count.get(owner, 0) + 1

        labs_running.set(running_labs)
        nodes_running.set(total_nodes_running)

        # Labs running per user
        labs_running_per_user.clear()
        for user, count in user_lab_count.items():
            labs_running_per_user.labels(username=user).set(count)

        # Nodes running per user
        nodes_running_per_user.clear()
        for user, count in user_node_count.items():
            nodes_running_per_user.labels(username=user).set(count)

        logger.info("Metrics collected successfully")
        client.error_count = 0  # Reset error count on successful collection

    except Exception as e:
        logger.error(f"Error collecting metrics: {e}", exc_info=True)
        # Increment error count and log if necessary
        client.error_count += 1
        if client.error_count > MAX_ERRORS:
            logger.critical("Max error limit reached, stopping metrics collection")
            sys.exit(1)


def metrics_loop(client: CMLClient) -> None:
    """
    Loop to periodically collect metrics at the specified polling interval.
    """
    while True:
        collect_metrics(client)
        time.sleep(POLL_INTERVAL)


def main():
    """
    Main entry point: initializes the CML client, starts the Prometheus exporter,
    and begins the metrics collection loop in a background thread.
    """
    try:
        client = CMLClient(CML_HOST, CML_USERNAME, CML_PASSWORD)
        start_http_server(EXPORTER_PORT)
        logger.info(f"Prometheus exporter started on port {EXPORTER_PORT}")
        thread = threading.Thread(target=metrics_loop, args=(client,), daemon=True)
        thread.start()
        thread.join()
    except Exception as e:
        logger.critical(f"Exporter failed to start: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
