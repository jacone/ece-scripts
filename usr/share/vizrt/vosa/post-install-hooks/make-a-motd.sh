#!/bin/bash

ssh -F $2/ssh.conf root@guest rm /etc/motd
echo 'This is a VOSA system!' | ssh -F $2/ssh.conf root@guest tee /etc/motd
