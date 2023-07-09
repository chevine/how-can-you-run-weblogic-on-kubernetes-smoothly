#!/bin/bash
#
# Install Docker
# https://docs.docker.com/engine/install/ubuntu/
# Update the apt package index and install packages to allow apt to use a repository over HTTPS
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
# Add Docker’s official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
# set up the repository
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
# Install the Docker Engine
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
sudo chmod go+rw /var/run/docker.sock
# Verify the installation
docker run hello-world
if [ $? -ne 0 ]
then
   echo "FATAL ERROR: Was not able to create the hello-world container!!!"
   exit 999
fi

# Create Oracle container
mkdir -p ~/.tmp
chmod -R og-rwx ~/.tmp
echo "Lucinda11#" > ~/.tmp/.passwd.txt
cat ~/.tmp/.passwd.txt | docker login container-registry.oracle.com --username chevine@verizon.net --password-stdin
docker run -d --name RAS_DEV container-registry.oracle.com/database/enterprise:21.3.0.0
sleep 60
docker logs RAS_DEV
sleep 300
docker exec RAS_DEV ./setPassword.sh Lucinda11
#docker exec -it RAS_DEV bash
#docker exec -it RAS_DEV sqlplus / as sysdba
#docker exec -it RAS_DEV sqlplus sys/Lucinda11@ORCLCDB as sysdba