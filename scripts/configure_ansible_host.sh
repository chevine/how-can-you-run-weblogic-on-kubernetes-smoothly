#!/bin/bash
#
# Common setup for all non-Kubernetes hosts

set -euxo pipefail

# Variable Declaration

# DNS Setting
if [ ! -d /etc/systemd/resolved.conf.d ]; then
	sudo mkdir /etc/systemd/resolved.conf.d/
fi
cat <<EOF | sudo tee /etc/systemd/resolved.conf.d/dns_servers.conf
[Resolve]
DNS=${DNS_SERVERS}
EOF

sudo systemctl restart systemd-resolved

# disable swap
sudo swapoff -a

# keeps the swap off during reboot
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab - || true
sudo apt-get update -y

sudo sysctl --system

# Install jq
sudo apt-get install jq -y

# Install Ansible
sudo apt-add-repository ppa:ansible/ansible
sudo apt update
sudo apt install ansible ansible-lint -y


# Generate the key
echo ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa <<<y >/dev/null 2>&1
# start the ssh-agent in the background and add the key for the user
eval "$(ssh-agent -s)"
echo ssh-add ~/.ssh/id_rsa
# Copy the public key to the remote hosts
echo ssh-copy-id -i ~/.ssh/id_rsa.pub master-node
echo ssh-copy-id -i ~/.ssh/id_rsa.pub worker-node01

# Display the facts for the hosts
echo ansible all -m gather_facts -i /vagrant/inventory_dev
