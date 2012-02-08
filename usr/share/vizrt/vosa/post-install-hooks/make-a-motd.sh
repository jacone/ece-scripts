#!/bin/bash

echo 'This is a VOSA system!' | ssh -F $2/ssh.conf root@remote tee /etc/motd
