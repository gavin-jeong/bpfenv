#!/usr/bin/env bash
nsenter -a -t 1 -- apt install linux-headers-$(uname -r) -y
