#!/bin/bash
set -e -x
# This script is meant to be run in the User Data of each EC2 Instance while it's booting.
function waitForJenkins() {
    echo "Waiting jenkins to launch on 8080..."

    while ! nc -z localhost 8080; do
      sleep 0.1 # wait for 1/10 of the second before check again
    done

    echo "Jenkins launched"
}

function waitForPasswordFile() {
    echo "Waiting jenkins to generate password..."
	
	until [[ -f /var/lib/jenkins/secrets/initialAdminPassword ]]; do
	  sleep 2
	done

    echo "Password created"
}

sudo update-rc.d jenkins defaults

waitForJenkins

# UPDATE PLUGIN LIST
curl  -L http://updates.jenkins-ci.org/update-center.json | sed '1d;$d' | curl -X POST -H 'Accept: application/json' -d @- http://localhost:8080/updateCenter/byId/default/postBack

sleep 10

waitForJenkins

# INSTALL CLI
sudo cp /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar /var/lib/jenkins/jenkins-cli.jar

# waitForPasswordFile

PASS=$(sudo bash -c "cat /var/lib/jenkins/secrets/initialAdminPassword")

sleep 10

# SET AGENT PORT
sudo service jenkins restart

waitForJenkins

sleep 10

# INSTALL PLUGINS
sudo java -jar /var/lib/jenkins/jenkins-cli.jar -s http://localhost:8080 -auth admin:$PASS install-plugin git

# RESTART JENKINS TO ACTIVATE PLUGINS
sudo java -jar /var/lib/jenkins/jenkins-cli.jar -s http://localhost:8080 -auth admin:$PASS restart