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

        stage('Kubernetes Deployment of ASG Buggy Web Application') {
            steps {
                withKubeConfig([credentialsId: 'kubelogin']) {
                    sh 'kubectl delete all --all -n devsecops || true'
                    sh 'kubectl apply -f deployment.yaml --namespace=devsecops'
                }
            }
        }

        stage('Wait for Deployment') {
            steps {
                sh 'echo "Waiting 180 seconds for app to be ready"; sleep 180'
            }
        }

        stage('Run DAST Using ZAP') {
            steps {
                withKubeConfig([credentialsId: 'kubelogin']) {
                    script {
                        // Get service hostname
                        def serviceUrl = sh(
                            script: 'kubectl get service/asgbuggy -n devsecops -o json | jq -r ".status.loadBalancer.ingress[0].hostname"',
                            returnStdout: true
                        ).trim()

                        // Ensure a writable folder for ZAP inside the workspace
                        sh 'mkdir -p ${WORKSPACE}/zap-output'

                        // Retry ZAP Docker run
                        def retryCount = 0
                        def maxRetries = 3
                        def success = false

                        while(!success && retryCount < maxRetries) {
                            try {
                                sh """
                                docker run --rm -v ${WORKSPACE}/zap-output:/zap/wrk:rw \
                                    ghcr.io/zaproxy/zaproxy:latest \
                                    zap.sh -cmd -quickurl http://${serviceUrl} -quickprogress -quickout /zap/wrk/zap_report.html
                                """
                                if (!fileExists("${WORKSPACE}/zap-output/zap_report.html")) {
                                    error "ZAP report not found after scan!"
                                }
                                success = true
                            } catch (Exception e) {
                                retryCount++
                                echo "ZAP Docker run failed, retry ${retryCount}/${maxRetries}..."
                                if (retryCount == maxRetries) {
                                    error "ZAP scan failed after ${maxRetries} attempts."
                                }
                                sleep 30
                            }
                        }

                        archiveArtifacts artifacts: 'zap-output/zap_report.html'
                    }
                }
            }
        }
    }
}
