openshift-cicd-base-sample
====================

A sample app with a jenkins pipeline to be deployed on openshift environments (Tested on version 3.11)

- Prerequisites:

    - An openshift cluster installed and configured
    - Credentials to access the cluster
    - [oc client](https://github.com/openshift/origin/releases/download/v3.11.0/openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz) and git installed
  

- Deploy instructions:

    - Clone or download this repository and open the folder in terminal
    - Login to the cluster: `oc login -u <user> <hostname>`
    - Run `./openshift/deploy.sh` (Execution time: around 5 minutes)
    

- Clean environment

    - Run `./openshift/deploy.sh --delete`
