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

        stage('Build Docker Image') { 
            steps { 
                withDockerRegistry([credentialsId: "dockerlogin", url: ""]) {
                    script {
                        app = docker.build("asg")
                    }
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                script {
                    docker.withRegistry('https://268428820004.dkr.ecr.us-west-2.amazonaws.com', 'ecr:us-west-2:aws-credentials') {
                        app.push("latest")
                    }
                }
            }
        }

        stage('Kubernetes Deployment') {
            steps {
                withKubeConfig([credentialsId: 'kubelogin']) {
                    // Clean previous resources
                    sh 'kubectl delete all --all -n devsecops || true'
                    // Apply deployment
                    sh 'kubectl apply -f deployment.yaml -n devsecops'
                }
            }
        }

        stage('Wait for Application') {
            steps {
                sh 'echo "Waiting for app to start..." && sleep 180'
            }
        }

        stage('Run DAST Using ZAP') {
            steps {
                withKubeConfig([credentialsId: 'kubelogin']) {
                    script {
                        // Get service hostname
                        def serviceUrl = sh(
                            script: "kubectl get service/asgbuggy -n devsecops -o json | jq -r '.status.loadBalancer.ingress[0].hostname'",
                            returnStdout: true
                        ).trim()

                        // Run ZAP in Docker
                        sh """
                        docker run --rm -v ${WORKSPACE}:/zap/wrk/:rw owasp/zap2docker-stable zap.sh \
                            -cmd -quickurl http://${serviceUrl} \
                            -quickprogress -quickout /zap/wrk/zap_report.html
                        """

                        // Archive the report
                        archiveArtifacts artifacts: 'zap_report.html'
                    }
                }
            }
        }
    }
}
