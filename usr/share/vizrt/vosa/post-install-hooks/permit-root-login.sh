#!/bin/bash

# 0wn the machine lol
ssh -F $2/ssh.conf guest 'sudo cp /home/ubuntu/.ssh/authorized_keys /root/.ssh/'

