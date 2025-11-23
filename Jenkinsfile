pipeline {
    agent any
    tools { 
        maven 'Maven_3_9_6'  
    }
    stages {
        stage('Compile and Run Sonar Analysis') {
            steps {    
                sh 'mvn clean verify sonar:sonar -Dsonar.projectKey=dbak3ybugywebapp -Dsonar.organization=dbak3ybugywebapp -Dsonar.host.url=https://sonarcloud.io -Dsonar.token=5169cafefbe8232c4f60dbbbbaf3995de3e750fb'
            }
        }

        stage('Run SCA Analysis Using Snyk') {
            steps {        
                withCredentials([string(credentialsId: 'SNYK_TOKEN', variable: 'SNYK_TOKEN')]) {
                    sh 'mvn snyk:test -fn'
                }
            }
        }

        stage('Build') { 
            steps { 
                withDockerRegistry([credentialsId: "dockerlogin", url: ""]) {
                    script {
                        app = docker.build("asg")
                    }
                }
            }
        }

        stage('Push') {
            steps {
                script {
                    docker.withRegistry('https://268428820004.dkr.ecr.us-west-2.amazonaws.com', 'ecr:us-west-2:aws-credentials') {
                        app.push("latest")
                    }
                }
            }
        }

        stage('Kubernetes Deployment of ASG Buggy Web Application') {
            steps {
                withKubeConfig([credentialsId: 'kubelogin']) {
                    sh('kubectl delete all --all -n devsecops || true')
                    sh('kubectl apply -f deployment.yaml --namespace=devsecops')
                }
            }
        }

        stage('Wait for Testing') {
            steps {
                sh 'sleep 180; echo "Application has been deployed on K8S"'
            }
        }

        stage('Run DAST Using ZAP') {
            steps {
                withKubeConfig([credentialsId: 'kubelogin']) {
                    script {
                        // Wait extra 180s for service readiness (optional, can keep or remove)
                        sh 'sleep 180'

                        // Get LoadBalancer hostname
                        def hostname = sh(
                            script: 'kubectl get service/asgbuggy -n devsecops -o json | jq -r ".status.loadBalancer.ingress[0].hostname"',
                            returnStdout: true
                        ).trim()

                        // Run ZAP scan using official GHCR image
                        sh """
                            docker run --rm \
                                -v ${WORKSPACE}:/zap/wrk/:rw \
                                ghcr.io/zaproxy/zaproxy:latest \
                                zap.sh -cmd -quickurl http://${hostname} \
                                -quickprogress -quickout /zap/wrk/zap_report.html
                        """

                        archiveArtifacts artifacts: 'zap_report.html'
                    }
                }
            }
        }
    }
}
