            try {
                timeout(time: 20, unit: 'MINUTES') {
                    node("maven") {
                      stage("Checkout") {
                        git url: "https://github.com/dperez-atsistemas/ocp4-jenkins-example-app.git", branch: "master"
                      }
                      stage ('Build image') {
                          sh '''
                            oc start-build eap-app -n ci-cd --follow
                          '''
                          }
                    }
                    node {
                      stage('Deploy to dev') {
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
                      stage('Promote') {
                        timeout(time:15, unit:'MINUTES') {
                              input message: "Approve Promotion to Prod?", ok: "Promote"
                            }
                          }
                    stage('Deploy to prod') {
                                  
                      }      
                    }
                }
            } catch (err) {
                echo "in catch block"
                echo "Caught: ${err}"
                currentBuild.result = 'FAILURE'
                throw err
              }