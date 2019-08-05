#!groovy

pipeline {
    agent any
    stages {
        stage('Prepare') {
            steps {
                 sh 'echo "Hello World, Im preparing"'
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
            }
        }

        stage('Test') {
            steps {
                 sh 'echo "Hello World, Im testing"'
            }
        }
    }
}