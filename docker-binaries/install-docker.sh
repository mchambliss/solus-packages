#!/bin/bash

if [ $(whoami) != 'root' ]; then
  echo "Must be root to run $0"
  exit 1;
fi

# Must have jq installed
command -v jq >/dev/null 2>&1 || { echo >&2 "jq required but it's not installed.  Aborting."; exit 1; }

# Get the latest binaries based on github releases
VERSION=$(curl -s https://api.github.com/repos/docker/docker-ce/releases/latest | jq -r ".name")
PACKAGE=docker-$VERSION.tgz
RELEASE_URL=https://download.docker.com/linux/static/edge/x86_64/$PACKAGE
wget $RELEASE_URL

if [ ! -f $PACKAGE ]; then
  echo "Looks like there was a problem when downloading the package."
  exit
fi

if [ -f /usr/lib64/systemd/system/docker.service ]; then
  # Assume everything has already been installed and we're just upgrading
  systemctl stop docker
else
  # Assume nothing was installed and install systemd and config files
  echo 'DOCKER_OPTS="--config-file=/etc/docker/daemon.json"' > /etc/default/docker

  # From: https://github.com/moby/moby/tree/master/contrib/init/systemd
  cp ./systemd/docker.socket /usr/lib64/systemd/system
  cp ./systemd/docker.service /usr/lib64/systemd/system

  # User overlay2
  mkdir -p /etc/docker
  cp ./config/daemon.json /etc/docker
  
  systemctl enable docker.socket
  systemctl enable docker.service
  systemctl daemon-reload
  
  groupadd docker
  #usermod -aG docker <username>
fi

# Extract and install
tar xzvf $PACKAGE -C /usr/bin --strip-components=1
rm $PACKAGE

systemctl start docker
