#!groovy

def remote = [:]
remote.name = "ec2-3-87-205-14.compute-1.amazonaws.com"
remote.host = "ec2-3-87-205-14.compute-1.amazonaws.com"
remote.user = "ubuntu"
remote.identityFile = "/var/lib/jenkins/.ssh/server-app-key"
remote.allowAnyHosts = true

pipeline {
    agent any
    stages {
        
        stage("Prepare") {
            steps {
                sh 'echo "Hello World, Im preparing"'
                sshCommand remote: remote, command: 'sudo -u wildfly /opt/bitnami/wildfly/bin/jboss-cli.sh --connect --command="undeploy myApp.war"'
            }
        }

        stage('Download from repository') {
            steps {
                 sh 'echo "Hello World, Im pulling"'
            }
        }

        stage('Build') {
            steps {
                 sh 'echo "Hello World, Im building"'
            }
        }

        stage('Upload artifacts') {
            steps {
                 sh 'echo "Hello World, Im uploading"'
            }
        }

        stage('Deploy') {
            steps {
                 sh 'echo "Hello World, Im deploying"'
                 sshCommand remote: remote, command: 'sudo -u wildfly /opt/bitnami/wildfly/bin/jboss-cli.sh --connect --command="deploy --force myApp.war"'
            }
        }

        stage('Test') {
            steps {
                 sh 'echo "Hello World, Im testing"'
            }
        }
    }
}