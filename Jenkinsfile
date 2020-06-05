pipeline {
    agent {
    node {label 'maven'}   
}

    stages {
        stage('Get Latest Code') {
            steps {
                git branch: "master", url: "https://github.com/dperez-atsistemas/ocp4-jenkins-example-app.git"
            }
        }
        stage ('Build image') {
            steps {
                sh '''
                    oc start-build eap-app -n ci-cd --follow
                    '''   
                }
         }

                
        stage('Deploy to dev') {
              steps {
                    openshift.withCluster() {
                        openshift.withProject('ci-cd') {
                            def dc = openshift.selector("dc", 'eap-app')
                            dc.rollout().latest()
                            timeout(10) {
                                dc.rollout().status()
                              }
                            }
                        }                  
                    }
          }

        stage('Promote') {
              steps {
                        timeout(time:15, unit:'MINUTES') {
                              input message: "Approve Promotion to Prod?", ok: "Promote"
                       }
       }

                          }
        stage('Deploy to prod') {
              steps {
                                  
                  }      
        }      

    }
}
        