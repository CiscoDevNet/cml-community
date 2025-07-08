#!/bin/sh

. /opt/cml-exporter/bin/activate
exec /usr/local/bin/cml-exporter.py
