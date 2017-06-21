#!/bin/bash

set -euo pipefail

# Get the master node IP from the yml file generated by vagrant
contiv_master=$(grep -B 3 master cluster/.cfg_legacy-swarm.yaml | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}" | xargs)

node_os=${CONTIV_NODE_OS:-"centos"}
# Default user is vagrant for non-ubuntu and ubuntu for ubuntu boxes.
if [ "$node_os" == "ubuntu" ]; then
	def_user="ubuntu"
	def_key="$HOME/.ssh/id_rsa"
else
	def_user="vagrant"
	def_key=""
fi
user=${CONTIV_SSH_USER:-"$def_user"}

# If BUILD_VERSION is not defined, we use a local dev build, that must have been created with make release
install_version="contiv-${BUILD_VERSION:-devbuild}"
pushd cluster
ssh_key=${CONTIV_SSH_KEY:-"$def_key"}
if [ "$ssh_key" == "" ]; then
	ssh_key=$(vagrant ssh-config legacy-swarm-master | grep IdentityFile | awk '{print $2}' | xargs)
fi
popd
# Extract and launch the installer
mkdir -p release
cd release
if [ ! -f "${install_version}.tgz" ]; then
	# For release builds, get the build from github releases
	curl -L -O https://github.com/contiv/install/releases/download/${BUILD_VERSION}/${install_version}.tgz
fi

tar oxf $install_version.tgz
cd $install_version
./install/ansible/install_swarm.sh -f ../../cluster/.cfg_legacy-swarm.yaml -e $ssh_key -u $user -i

# Wait for CONTIV to start for up to 10 minutes
sleep 10
for i in {0..20}; do
	response=$(curl -k -s -H "Content-Type: application/json" -X POST -d '{"username": "admin", "password": "admin"}' https://$contiv_master:10000/api/v1/auth_proxy/login/ || true)
	if [[ $response == *"token"* ]]; then
		echo "Install SUCCESS"
		echo ""
		cat <<EOF
  NOTE: Because the Contiv Admin Console is using a self-signed certificate for this demo,
  you will see a security warning when the page loads.  You can safely dismiss it.
  
  You can access the Contiv master node with:
    cd cluster && vagrant ssh legacy-swarm-master
EOF
		exit 0
	else
		echo "$i. Retry login to Contiv"
		sleep 30
	fi
done
echo "Install FAILED"
exit 1
