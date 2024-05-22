#!/bin/bash

if [[ -r /etc/os-release ]]; then
	. /etc/os-release
else
	echo "Error: \"/etc/os-release\" does not exist."
	exit
fi

DGX_REPO=false
NO_INSTALL_DOCKER=false

for arg in $*; do
	case $arg in
		--dgx-repo)
			DGX_REPO=true
			shift
			;;
		--no-install-docker)
			NO_INSTALL_DOCKER=true
			shift
			;;
	esac
done

if ! command -v curl > /dev/null; then
	apt update
	DEBIAN_FRONTEND=noninteractive apt install -y curl
fi

if [ $DGX_REPO == true ]; then	
	if [[ $UBUNTU_CODENAME = jammy ]] || [[ $UBUNTU_CODENAME = focal ]]; then
		curl -fkSL https://repo.download.nvidia.com/baseos/ubuntu/$UBUNTU_CODENAME/dgx-repo-files.tgz | tar xzf - -C /
	elif [[ $UBUNTU_CODENAME = bionic ]]; then
		curl -fkSLO https://repo.download.nvidia.com/dgx/repos/bionic/pool/multiverse/d/dgx-repo/dgx-repo_1.0-5_amd64.deb
		curl -fkSLO https://repo.download.nvidia.com/dgx/repos/bionic/pool/multiverse/d/dgx-bionic-repos/dgx-bionic-r418+cuda10.1-repo_1.0-8_amd64.deb
		curl -fkSLO https://repo.download.nvidia.com/dgx/repos/bionic/pool/multiverse/d/dgx-bionic-repos/dgx-bionic-r450+cuda11.0-repo_1.0-8_amd64.deb
		curl -fkSLO https://repo.download.nvidia.com/dgx/repos/bionic/pool/multiverse/n/nvidia-repo-keys/nvidia-repo-keys_22.04-1_all.deb
		dpkg -i dgx-repo_1.0-5_amd64.deb dgx-bionic-r418+cuda10.1-repo_1.0-8_amd64.deb dgx-bionic-r450+cuda11.0-repo_1.0-8_amd64.deb nvidia-repo-keys_22.04-1_all.deb
		rm dgx-repo_1.0-5_amd64.deb dgx-bionic-r418+cuda10.1-repo_1.0-8_amd64.deb dgx-bionic-r450+cuda11.0-repo_1.0-8_amd64.deb nvidia-repo-keys_22.04-1_all.deb
	else
		if [[ $UBUNTU_CODENAME = xenial ]]; then
			curl -fkSLO https://repo.download.nvidia.com/dgx/repos/pool/multiverse/d/dgx-repo/dgx-repo_1.0-1_amd64.deb
			curl -fkSLO https://repo.download.nvidia.com/dgx/repos/bionic/pool/multiverse/d/dgx-repo-keys/dgx-repo-keys_2.0_amd64.deb
			curl -fkSLO https://repo.download.nvidia.com/dgx/repos/pool/multiverse/d/dgx-docker-repo/dgx-docker-repo_1.0-1_amd64.deb
			dpkg -i dgx-repo_1.0-1_amd64.deb dgx-docker-repo_1.0-1_amd64.deb
			rm dgx-repo_1.0-1_amd64.deb dgx-docker-repo_1.0-1_amd64.deb
			apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 7EA0A9C3F273FCD8
		elif [[ $VERSION_ID = 14.04 ]]; then
			curl -fkSLO https://international.download.nvidia.com/dgx1/repos/pool/multiverse/d/dgx1-repo/dgx1-repo-ubuntu1404_1.1-1_amd64.deb
			curl -fkSLO https://repo.download.nvidia.com/dgx/repos/bionic/pool/multiverse/d/dgx-repo-keys/dgx-repo-keys_2.0_amd64.deb
			dpkg -i dgx1-repo-ubuntu1404_1.1-1_amd64.deb dgx-repo-keys_2.0_amd64.deb
			rm dgx1-repo-ubuntu1404_1.1-1_amd64.deb dgx-repo-keys_2.0_amd64.deb
		else
			echo "Error: unsupported ubuntu version."
		fi
	fi
fi

if [ $NO_INSTALL_DOCKER == true ]; then
	exit
fi

if [[ $VERSION_ID = 14.04 ]]; then
	reqs="docker.io"
else
	reqs="docker-ce docker-ce-cli containerd.io"
	
	if cat /etc/apt/sources.list.d/dgx.list > /dev/null; then
		reqs="$reqs dgx-docker-cleanup dgx-docker-options"
		
		if [[ $UBUNTU_CODENAME = jammy ]] || [[ $UBUNTU_CODENAME = focal ]]; then
			reqs="$reqs nvidia-container-toolkit"
		elif [[ $UBUNTU_CODENAME = bionic ]] || [[ $UBUNTU_CODENAME = xenial ]]; then
			reqs="$reqs nvidia-docker2"
		fi
	else
		pre_reqs="apt-transport-https ca-certificates"
		
		if ! command -v gnupg > /dev/null; then
			pre_reqs="$pre_reqs gnupg"
		fi
		
		if [[ $UBUNTU_CODENAME = jammy ]] || [[ $UBUNTU_CODENAME = focal ]]; then
			reqs="$reqs docker-buildx-plugin docker-compose-plugin nvidia-container-toolkit"
		else
			reqs="$reqs nvidia-container-toolkit"
		fi
	
		apt update
		DEBIAN_FRONTEND=noninteractive apt install -y $pre_reqs
		install -m 0755 -d /etc/apt/keyrings
		echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
		curl -fkSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
		chmod a+r /etc/apt/keyrings/docker.gpg
		curl -ksL https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
		curl -ksL https://nvidia.github.io/nvidia-docker/$(. /etc/os-release;echo $ID$VERSION_ID)/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list
	fi
fi

apt update
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends $reqs
service docker restart
systemctl enable docker
