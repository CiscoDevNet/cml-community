# CML Exporter

A Prometheus exporter for Cisco Modeling Labs (CML) that exposes system resource and per-lab metrics for monitoring your CML controller.

## Features

This exporter provides the following metrics:

- **CPU Usage**: Percent CPU utilization for each host, with labels for host name and whether it is a compute node.
- **Memory Usage**: Percent memory utilization for each host, with labels for host name and compute status.
- **Disk Usage**: Percent disk utilization for each host, with labels for host name and compute status.
- **Labs Running**: Total number of labs currently running.
- **Labs Running Per User**: Number of labs running, broken down by username.
- **Nodes Running**: Total number of nodes running across all labs.
- **Nodes Running Per User**: Number of nodes running, broken down by username.

## Installation

1. Run the installer script as root on your CML controller:

    ```bash
    sudo bash cml-exporter-installer.sh
    ```

2. Edit `/etc/default/cml-exporter` and set the `CML_PASSWORD` variable to your CML admin password.  You may wish to adjust other parameters as well.
3. Restart the exporter service:

    ```bash
    sudo systemctl restart cml-exporter.service
    ```

## Usage

Once installed and running, the exporter will expose metrics on a Prometheus-compatible endpoint. Configure your Prometheus server to scrape metrics from your CML controller.
For example:

```yaml
  - job_name: 'cml_stats'
    static_configs:
      - targets: ['192.168.10.210:9100']
```

## License

This project is licensed under the [BSD License](LICENSE).
