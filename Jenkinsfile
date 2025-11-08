def DOCKER_IMAGE_NAME = "26kishorekumar/aceest-fitness"

pipeline {
    // Run on any available Jenkins agent
    agent any
    
    // Explicitly define the SonarScanner tool
    tools {
        'hudson.plugins.sonar.SonarRunnerInstallation' 'SonarScannerTool'
    }

    // Environment variables used throughout the pipeline
    environment {
        // --- Configuration ---
        SONAR_PROJECT_KEY = "aceest-fitness"
        DOCKER_USER = '26kishorekumar'
        
        // This ID MUST match the Secret File credential uploaded to Jenkins
        KUBECONFIG_CREDENTIAL_ID = 'MINIKUBE_KUBECONFIG' 
        // --- End Configuration ---
        
        IMAGE_TAG = "build-${env.BUILD_NUMBER}"
    }

    stages {
        // ... (Stages 1-6 remain unchanged) ...

        stage('1. Checkout Code') {
            steps {
                echo 'Checking out source code from Git...'
                checkout scm
            }
        }

        stage('2. Code Quality Analysis') {
            environment {
                SONAR_SCANNER_HOME = tool 'SonarScannerTool'
            }
            steps {
                echo "Starting SonarQube analysis for project: ${SONAR_PROJECT_KEY}"
                withCredentials([string(credentialsId: 'SonarQube-Server', variable: 'SONAR_TOKEN_VAR')]) {
                    withSonarQubeEnv('SonarQube-Server') {
                        sh "${SONAR_SCANNER_HOME}/bin/sonar-scanner -Dsonar.projectKey=${SONAR_PROJECT_KEY} -Dsonar.sources=. -Dsonar.login=\$SONAR_TOKEN_VAR"
                    }
                }
            }
        }

        stage('3. SonarQube Quality Gate') {
            steps {
                echo 'Waiting for SonarQube analysis to complete...'
                sleep 30
                timeout(time: 20, unit: 'MINUTES') { 
                    waitForQualityGate abortPipeline: true
                }
                echo 'SonarQube Quality Gate passed!'
            }
        }

        stage('4. Unit Testing (Pytest)') {
            steps {
                echo 'Creating virtual environment, installing dependencies, and running unit tests.'
                sh """
                    /usr/bin/python3 -m venv venv
                    . venv/bin/activate
                    pip install -r requirements.txt
                    pytest
                """
            }
        }

        stage('5. Build Container Image') {
            steps {
                echo "Building Docker image: ${DOCKER_IMAGE_NAME}:${IMAGE_TAG}"
                sh "docker build -t ${DOCKER_IMAGE_NAME}:${IMAGE_TAG} ."
                echo "Tagging image as 'latest'"
                sh "docker tag ${DOCKER_IMAGE_NAME}:${IMAGE_TAG} ${DOCKER_IMAGE_NAME}:latest"
            }
        }

        stage('6. Push Image to Docker Hub') {
            steps {
                echo "Pushing image to Docker Hub..."
                withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', passwordVariable: 'DOCKER_PASS', usernameVariable: 'DOCKER_USER_VAR')]) {
                    sh "echo ${DOCKER_PASS} | docker login -u ${DOCKER_USER_VAR} --password-stdin"
                    sh "docker push ${DOCKER_IMAGE_NAME}:${IMAGE_TAG}"
                    sh "docker push ${DOCKER_IMAGE_NAME}:latest"
                }
            }
        }

        // --- Phase 7: Deploy to Minikube (NEW FIX: Uses command substitution for reliable piping) ---
        stage('7. Deploy to Minikube') {
            steps {
                echo "Deploying new image to Kubernetes..."
                
                withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIAL_ID, variable: 'KUBECONFIG_FILE_PATH')]) {
                    withEnv(["KUBECONFIG=${KUBECONFIG_FILE_PATH}"]) {
                        
                        // 1. CRITICAL FIX: Securely create/update the Docker Hub Secret.
                        echo "1. Creating/Updating Docker Hub registry secret ('docker-hub-regcred')..."
                        withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', passwordVariable: 'DOCKER_PASS', usernameVariable: 'DOCKER_USER_VAR')]) {
                            sh """
                                # Assign DOCKER credentials to shell variables for secure, reliable piping.
                                DOCKER_USER_SHELL='${DOCKER_USER_VAR}'
                                DOCKER_PASS_SHELL='${DOCKER_PASS}'

                                # 1. Generate the Secret YAML and store it in a shell variable using command substitution (\$).
                                # We use escaped \$ for the command substitution to happen inside the shell block.
                                SECRET_YAML=\$(kubectl create secret docker-registry docker-hub-regcred \\
                                    --docker-server=docker.io \\
                                    --docker-username="\${DOCKER_USER_SHELL}" \\
                                    --docker-password="\${DOCKER_PASS_SHELL}" \\
                                    --dry-run=client -o yaml)
                                
                                # 2. Safely echo the generated YAML and pipe it to kubectl apply -f -
                                echo "\${SECRET_YAML}" | kubectl apply -f -
                            """
                        }

                        // 2. Rollout the new image tag
                        echo "2. Applying new image tag via kubectl set image..."
                        sh "kubectl set image deployment/aceest-fitness-deployment aceest-fitness=${DOCKER_IMAGE_NAME}:${IMAGE_TAG}"

                        // 3. Wait for stabilization
                        echo "3. Waiting for deployment to stabilize..."
                        sh "kubectl rollout status deployment/aceest-fitness-deployment"
                    }
                }
            }
        }
    }

    // --- Post-Pipeline Actions ---
    post {
        always {
            echo 'Pipeline finished. Cleaning up workspace.'
            cleanWs()
        }
        success {
            echo 'Logging out of Docker Hub.'
            sh 'docker logout'
            echo 'Deployment successful! 🎉'
        }
        failure {
            echo 'Logging out of Docker Hub.'
            sh 'docker logout'
            echo 'Pipeline failed! 😔'
        }
    }
}