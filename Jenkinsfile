pipeline {
    agent any

    tools {
        maven 'Maven_3_9_6'
    }

    environment {
        SONAR_PROJECT_KEY = 'dbak3ybugywebapp'
        SONAR_ORG         = 'dbak3ybugywebapp'
        SONAR_HOST_URL    = 'https://sonarcloud.io'

        DOCKER_IMAGE = 'asg'
        ECR_REGISTRY = '268428820004.dkr.ecr.us-west-2.amazonaws.com'
        K8S_NAMESPACE = 'devsecops'
    }

    stages {

        /* ------------------------------
         * STAGE 1 — SONARCLOUD (SAST)
         * ------------------------------ */
        stage('Compile & Sonar Analysis') {
            steps {
                sh """
                    mvn clean verify sonar:sonar \
                        -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                        -Dsonar.organization=${SONAR_ORG} \
                        -Dsonar.host.url=${SONAR_HOST_URL} \
                        -Dsonar.token=5169cafefbe8232c4f60dbbbbaf3995de3e750fb
                """
            }
        }

        /* ------------------------------
         * STAGE 2 — SNYK (SCA)
         * ------------------------------ */
        stage('SCA Analysis with Snyk') {
            steps {
                withCredentials([string(credentialsId: 'SNYK_TOKEN', variable: 'SNYK_TOKEN')]) {
                    sh """
                        mvn snyk:test \
                            -Dsnyk.token=${SNYK_TOKEN} \
                            -fn
                    """
                }
            }
        }

        /* ------------------------------
         * STAGE 3 — DOCKER BUILD
         * ------------------------------ */
        stage('Build Docker Image') {
            steps {
                withDockerRegistry([credentialsId: 'dockerlogin', url: '']) {
                    script {
                        app = docker.build("${DOCKER_IMAGE}")
                    }
                }
            }
        }

        /* ------------------------------
         * STAGE 4 — PUSH TO ECR
         * ------------------------------ */
        stage('Push Docker Image to ECR') {
            steps {
                script {
                    docker.withRegistry("https://${ECR_REGISTRY}", 'ecr:us-west-2:aws-credentials') {
                        app.push("latest")
                    }
                }
            }
        }

        /* ------------------------------
         * STAGE 5 — KUBERNETES DEPLOYMENT
         * ------------------------------ */
        stage('Deploy to Kubernetes') {
            steps {
                withKubeConfig([credentialsId: 'kubelogin']) {
                    sh "kubectl delete all --all -n ${K8S_NAMESPACE} || true"
                    sh "kubectl apply -f deployment.yaml -n ${K8S_NAMESPACE}"
                }
            }
        }

        /* ------------------------------
         * STAGE 6 — WAIT FOR LOAD BALANCER
         * ------------------------------ */
        stage('Wait for Load Balancer Ready') {
            steps {
                withKubeConfig([credentialsId: 'kubelogin']) {
                    script {

                        echo "Waiting for ELB hostname..."

                        def serviceUrl = ""
                        timeout(time: 5, unit: 'MINUTES') {
                            waitUntil {
                                serviceUrl = sh(
                                    script: "kubectl get svc asgbuggy -n ${K8S_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'",
                                    returnStdout: true
                                ).trim()

                                return serviceUrl != null && serviceUrl != "" && serviceUrl != "null"
                            }
                        }

                        echo "ELB Ready: ${serviceUrl}"
                        env.ELB_URL = serviceUrl
                    }
                }
            }
        }

        /* ------------------------------
         * STAGE 7 — OWASP ZAP (DAST)
         * ------------------------------ */
        stage('Run DAST Using ZAP') {
            steps {
                withKubeConfig([credentialsId: 'kubelogin']) {
                    script {

                        def scanUrl = "http://${env.ELB_URL}"
                        echo "Running ZAP against: ${scanUrl}"

                        sh """
                            mkdir -p "${WORKSPACE}/zap-output"
                            chmod -R 777 "${WORKSPACE}/zap-output"
                        """

                        def maxRetries = 3
                        for (int attempt = 1; attempt <= maxRetries; attempt++) {

                            try {
                                sh """
                                    docker run --rm \
                                      -v ${WORKSPACE}/zap-output:/zap/wrk:rw \
                                      ghcr.io/zaproxy/zaproxy:latest \
                                      zap.sh -cmd \
                                           -quickurl ${scanUrl} \
                                           -quickprogress \
                                           -quickout /zap/wrk/zap_report.html
                                """

                                if (!fileExists("${WORKSPACE}/zap-output/zap_report.html")) {
                                    error "ZAP did not generate zap_report.html"
                                }

                                echo "ZAP scan completed."
                                break

                            } catch (err) {
                                echo "ZAP failed on attempt ${attempt}/3"

                                if (attempt == maxRetries) {
                                    error "ZAP failed after 3 attempts"
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

    /* ------------------------------
     * POST ACTIONS
     * ------------------------------ */
    post {
        always {
            echo "Pipeline completed (success or fail)."
        }
        success {
            echo "✅ Pipeline finished successfully."
        }
        failure {
            echo "❌ Pipeline failed — review the logs above."
        }
    }
}
