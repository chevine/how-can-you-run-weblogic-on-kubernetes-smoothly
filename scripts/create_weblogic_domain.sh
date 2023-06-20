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

exit 0


# Configure the environment for the AWS CLI
# AWS Access Key ID [None]: AKIA42B43KUUDQ2CPTGA
# AWS Secret Access Key [None]: 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
# Default region name [None]: us-west-2
# Default output format [None]: json
aws configure


# Use "Model in Image" to install a WebLogic Operator
# https://oracle.github.io/weblogic-kubernetes-operator/samples/domains/model-in-image/

docker login container-registry-frankfurt.oracle.com
docker pull container-registry-frankfurt.oracle.com/middleware/weblogic:14.1.1.0-11
docker logout container-registry-frankfurt.oracle.com
kubectl apply -f manifests/ingress-nginx.yaml

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
cd model-in-image/model-images
curl -m 120 -fL https://github.com/oracle/weblogic-deploy-tooling/releases/latest/download/weblogic-deploy.zip -o ./weblogic-deploy.zip
./imagetool/bin/imagetool.sh cache deleteEntry --key wdt_latest
./imagetool/bin/imagetool.sh cache addInstaller --type wdt --version latest --path ./weblogic-deploy.zip
cd ../archives/archive-v1/
zip -r ../../model-images/playground-model/archive.zip wlsdeploy

# Build Image With Domain Model
cd ../../model-images
./imagetool/bin/imagetool.sh update \
--tag cloud-coaching-demo-app:1.0 \
--fromImage container-registry-frankfurt.oracle.com/middleware/weblogic:14.1.1.0-11 \
--wdtModel      ./playground-model/playground.yaml \
--wdtVariables  ./playground-model/playground.properties \
--wdtArchive    ./playground-model/archive.zip \
--wdtModelOnly \
--wdtDomainType WLS \
--chown oracle:root

aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 880595916072.dkr.ecr.us-west-2.amazonaws.com
docker tag cloud-coaching-demo-app:1.0 880595916072.dkr.ecr.us-west-2.amazonaws.com/cloud-coaching-demo-app:1.0
docker push 880595916072.dkr.ecr.us-west-2.amazonaws.com/cloud-coaching-demo-app:1.0

# Deploy WebLogic Domain to Kubernetes with Operator











# Install the weblogic operator
# https://oracle.github.io/weblogic-kubernetes-operator/quickstart/install/
set -x
kubectl create namespace sample-weblogic-operator-ns
kubectl create serviceaccount -n sample-weblogic-operator-ns sample-weblogic-operator-sa

# https://oracle.github.io/weblogic-kubernetes-operator/2.6/userguide/managing-operators/using-the-operator/using-helm/
helm repo add weblogic-operator https://oracle.github.io/weblogic-kubernetes-operator/charts --force-update  
helm install sample-weblogic-operator weblogic-operator/weblogic-operator \
  --namespace sample-weblogic-operator-ns \
  --set serviceAccount=sample-weblogic-operator-sa \
  --wait

kubectl get pods -n sample-weblogic-operator-ns
kubectl logs -n sample-weblogic-operator-ns -c weblogic-operator deployments/weblogic-operator
set +x

# Create a Traefik ingress controller
helm repo add traefik https://helm.traefik.io/traefik --force-update
kubectl create namespace traefik
helm install traefik-operator traefik/traefik \
    --namespace traefik \
    --set "ports.web.nodePort=30305" \
    --set "ports.websecure.nodePort=30443" \
    --set "kubernetes.namespaces={traefik}"

# Prepare for a domain
kubectl create namespace sample-domain1-ns
kubectl label ns sample-domain1-ns weblogic-operator=enabled
helm upgrade traefik-operator traefik/traefik \
    --namespace traefik \
    --reuse-values \
    --set "kubernetes.namespaces={traefik,sample-domain1-ns}"

# Prepare for a domain
docker login -u chevine -p Lucinda11
kubectl create secret docker-registry weblogic-repo-credentials \
     --docker-server=container-registry.oracle.com \
     --docker-username=chevine \
     --docker-password=Lucinda11 \
     --docker-email=chevine@verizon.net \
     -n sample-domain1-ns

# Create the domain
kubectl create secret generic sample-domain1-weblogic-credentials \
  --from-literal=username=admin --from-literal=password=Lucinda11 \
  -n sample-domain1-ns
kubectl -n sample-domain1-ns create secret generic \
  sample-domain1-runtime-encryption-secret \
   --from-literal=password=Lucinda11
kubectl apply -f https://raw.githubusercontent.com/oracle/weblogic-kubernetes-operator/release/4.0/kubernetes/samples/quick-start/domain-resource.yaml
if $? -ne 0
then
   echo "FATAL ERROR: The following command failed:"
   echo "   kubectl apply -f https://raw.githubusercontent.com/oracle/weblogic-kubernetes-operator/release/4.0/kubernetes/samples/quick-start/domain-resource.yaml"
   exit 999
fi

#kubectl get ValidatingWebhookConfiguration -o yaml > ./validating-backup.yaml
#kubectl delete validatingWebhookConfiguration weblogic.validating.webhook
#kubectl apply -f https://raw.githubusercontent.com/oracle/weblogic-kubernetes-operator/release/4.0/kubernetes/samples/quick-start/domain-resource.yaml

# Download the weblogic operator software
#mkdir -p ~/install
#git clone https://github.com/oracle/weblogic-kubernetes-operator

# https://oracle.github.io/weblogic-kubernetes-operator/samples/domains/model-in-image/