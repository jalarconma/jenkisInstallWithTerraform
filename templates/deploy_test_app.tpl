#!/bin/bash
set -e -x
# This script is meant to be run in the User Data of each EC2 Instance while it's booting.
function waitForJboss() {
    echo "Waiting jboss to launch on 8080..."

    while ! nc -z localhost 8080; do
      sleep 0.1 # wait for 1/10 of the second before check again
    done

    echo "Jboss launched"
}

# Lauch Jboss
sudo chmod +x /opt/jboss/jboss-eap-7.1/bin/standalone.sh
sudo /opt/jboss/jboss-eap-7.1/bin/standalone.sh
echo "Jboss launched"

#waitForJboss

# Deploy test app
#sudo bash /opt/jboss/jboss-eap-7.1/bin/jboss-cli.sh --connect command="deploy --force /home/ubuntu/myApp.war"