source <(kubectl completion bash) # set up autocomplete in bash into the current shell, bash-completion package should be installed first.
echo "source <(kubectl completion bash)" >> ~/.bashrc # add autocomplete permanently to your bash shell.
alias k=kubectl
complete -o default -F __start_kubectl k
echo "set -o vi" >> ~/.bashrc
chmod ~/.bashrc

# Ensure that is secure /home/vagrant/.kube/config
chmod og-rwx /home/vagrant/.kube/config


# Install Helm
# https://v3.helm.sh/docs/intro/install/
wget https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz 
tar -xvf helm-v3.12.0-linux-amd64.tar.gz 
sudo mv linux-amd64/helm /usr/local/bin

# Install Java
sudo apt update
sudo apt install default-jre -y
sudo apt install default-jdk -y
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64

# Install zip
sudo apt-get install zip -y

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
chmod go+rw /var/run/docker.sock
# Verify the installation
docker run hello-world
if [ $? -ne 0 ]
then
   echo "FATAL ERROR: Was not able to create the hello-world container!!!"
   exit 999
fi

# Install AWS CLI
sudo apt install unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Copy the source files over
cp -rp /vagrant/manifests .
cp -rp /vagrant/model-in-image .

# Use "Model in Image" to install a WebLogic Operator
# https://oracle.github.io/weblogic-kubernetes-operator/samples/domains/model-in-image/

# Retrieve the WebLogic Server container images
mkdir -p ~/.tmp
chmod -R og-rwx ~/.tmp
echo "Lucinda11#" > ~/.tmp/.passwd.txt
cat ~/.tmp/.passwd.txt | docker login container-registry-frankfurt.oracle.com --username chevine@verizon.net --password-stdin
docker login container-registry-frankfurt.oracle.com
docker pull container-registry-frankfurt.oracle.com/middleware/weblogic:14.1.1.0-11
docker logout container-registry-frankfurt.oracle.com

# Install Ingress Nginx Controller
kubectl apply -f manifests/ingress-nginx.yaml
kubectl get pods -n cloud-coaching-ingress-nginx

# Install WebLogic Operator
kubectl create namespace cloud-coaching-weblogic-operator-ns
kubectl create serviceaccount -n cloud-coaching-weblogic-operator-ns cloud-coaching-weblogic-operator-sa
helm repo add weblogic-operator https://oracle.github.io/weblogic-kubernetes-operator/charts --force-update
helm install cloud-coaching-weblogic-operator weblogic-operator/weblogic-operator \
  --namespace cloud-coaching-weblogic-operator-ns \
  --set image=ghcr.io/oracle/weblogic-kubernetes-operator:4.0.6 \
  --set serviceAccount=cloud-coaching-weblogic-operator-sa \
  --set "enableClusterRoleBinding=true" \
  --set "domainNamespaceSelectionStrategy=LabelSelector" \
  --set "domainNamespaceLabelSelector=cloud-coaching-weblogic-operator\=enabled" \
  --wait
kubectl get pods -n cloud-coaching-weblogic-operator-ns
helm list -n cloud-coaching-weblogic-operator-ns
helm history cloud-coaching-weblogic-operator -n cloud-coaching-weblogic-operator-ns
# helm uninstall cloud-coaching-weblogic-operator -n cloud-coaching-weblogic-operator-ns

# Build Image With Domain Model
cd model-in-image/model-images
# Dowload weblogic-deploy and the Image Tool
curl -m 120 -fL https://github.com/oracle/weblogic-deploy-tooling/releases/latest/download/weblogic-deploy.zip -o ./weblogic-deploy.zip
curl -m 120 -fL https://github.com/oracle/weblogic-image-tool/releases/latest/download/imagetool.zip -o ./imagetool.zip
unzip imagetool.zip
# Clear the cache
./imagetool/bin/imagetool.sh cache deleteEntry --key wdt_latest
# Install WIT and reference WDT
./imagetool/bin/imagetool.sh cache addInstaller --type wdt --version latest --path ./weblogic-deploy.zip
if [ $? -ne 0 ]
then
   echo "FATAL ERROR: Was not able to execute the following command:\n\t./imagetool/bin/imagetool.sh cache addInstaller --type wdt --version latest --path ./weblogic-deploy.zip"
   exit 888
fi
# Go in folder with WAR source
cd ../archives/archive-v1/
zip -r ../../model-images/playground-model/archive.zip wlsdeploy
# Go in the folder with model images
cd ../../model-images
# Build the image with inputs
./imagetool/bin/imagetool.sh update \
--tag cloud-coaching-demo-app:1.0 \
--fromImage container-registry-frankfurt.oracle.com/middleware/weblogic:14.1.1.0-11 \
--wdtModel      ./playground-model/playground.yaml \
--wdtVariables  ./playground-model/playground.properties \
--wdtArchive    ./playground-model/archive.zip \
--wdtModelOnly \
--wdtDomainType WLS \
--chown oracle:root
# Confirmed the existence of a freshly generated container image with the domain inside
docker images | grep cloud-coaching-demo-app


exit 0
# Tag the image and push it to the repository
aws --profile rasadmin-dev configure
aws ecr get-login-password --region us-west-2 | docker login --username rasadmin-dev --password-stdin 880595916072.dkr.ecr.us-west-2.amazonaws.com
docker tag cloud-coaching-demo-app:1.0 880595916072.dkr.ecr.us-west-2.amazonaws.com/cloud-coaching-demo-app:1.0
docker push 880595916072.dkr.ecr.us-west-2.amazonaws.com/cloud-coaching-demo-app:1.0

# Install the Oracle instance
docker pull container-registry.oracle.com/database/enterprise:latest
docker run -d --name RASDEV container-registry.oracle.com/database/enterprise:21.3.0.0
docker logs RASDEV
docker exec -it <container-id> bash
docker exec RASDEV ./setPassword.sh Lucinda11
docker exec -it RASDEV sqlplus / as sysdba


docker exec -it RASDEV sqlplus sys/Lucinda11@ORCLCDB as sysdba
docker exec -it RASDEV sqlplus system/Lucinda11@ORCLCDB