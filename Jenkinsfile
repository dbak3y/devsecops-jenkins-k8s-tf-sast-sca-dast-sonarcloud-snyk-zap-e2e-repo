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
                    sh('kubectl delete all --all -n devsecops || true')
                    sh('kubectl apply -f deployment.yaml --namespace=devsecops')
                }
            }
        }

        stage('Wait for Application Deployment') {
            steps {
                sh 'echo "Waiting for application to become ready..."; sleep 180'
            }
        }

        stage('Run DAST Using ZAP') {
            steps {
                withKubeConfig([credentialsId: 'kubelogin']) {
                    script {
                        // Wait for LoadBalancer hostname
                        def hostname = ''
                        for (int i = 0; i < 30; i++) { // wait up to 5 minutes
                            hostname = sh(script: "kubectl get service/asgbuggy -n devsecops -o json | jq -r '.status.loadBalancer.ingress[0].hostname'", returnStdout: true).trim()
                            if (hostname && hostname != 'null') {
                                echo "Service is available at $hostname"
                                break
                            }
                            echo "Waiting for LoadBalancer hostname..."
                            sleep(10)
                        }
                        if (!hostname || hostname == 'null') {
                            error "LoadBalancer hostname not available after waiting"
                        }

                        // Set ZAP Docker image
                        def zapImage = "owasp/zap2docker-stable:latest"

                        // Pull image first
                        sh "docker pull ${zapImage}"

                        // Run ZAP scan
                        sh """
                            docker run --rm -v ${WORKSPACE}:/zap/wrk/:rw ${zapImage} \
                            zap.sh -cmd -quickurl http://${hostname} \
                            -quickprogress -quickout /zap/wrk/zap_report.html
                        """

                        // Archive report
                        archiveArtifacts artifacts: 'zap_report.html'
                    }
                }
            }
        }
    }
}
