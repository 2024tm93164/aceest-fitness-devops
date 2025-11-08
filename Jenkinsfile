def DOCKER_IMAGE_NAME = "26kishorekumar/aceest-fitness"

pipeline {
    // Run on any available Jenkins agent
    agent any
    
    // CRITICAL FIX: Explicitly define the SonarScanner tool using the full class path
    // This is required by your specific Jenkins environment configuration to pass compilation.
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
        // --- Phase 1: Checkout ---
        stage('1. Checkout Code') {
            steps {
                echo 'Checking out source code from Git...'
                checkout scm
            }
        }

        // --- Phase 2: Code Quality (SonarQube) ---
        stage('2. Code Quality Analysis') {
            environment {
                // CRITICAL FIX: Explicitly retrieve the installed tool's path to solve 'sonar-scanner: not found'
                SONAR_SCANNER_HOME = tool 'SonarScannerTool'
            }
            steps {
                echo "Starting SonarQube analysis for project: ${SONAR_PROJECT_KEY}"
                
                // Securely load SonarQube API token
                withCredentials([string(credentialsId: 'SonarQube-Server', variable: 'SONAR_TOKEN_VAR')]) {
                    withSonarQubeEnv('SonarQube-Server') {
                        // Use the full, precise path to the executable
                        sh "${SONAR_SCANNER_HOME}/bin/sonar-scanner -Dsonar.projectKey=${SONAR_PROJECT_KEY} -Dsonar.sources=. -Dsonar.login=\$SONAR_TOKEN_VAR"
                    }
                }
            }
        }

        // --- Phase 3: Quality Gate ---
        stage('3. SonarQube Quality Gate') {
            steps {
                echo 'Waiting for SonarQube analysis to complete...'
                
                // FIX for timeout: Wait 30 seconds to ensure the task is registered
                sleep 30
                
                // FIX for timeout: Increased timeout limit to 20 minutes for stability
                timeout(time: 20, unit: 'MINUTES') { 
                    waitForQualityGate abortPipeline: true
                }
                echo 'SonarQube Quality Gate passed!'
            }
        }

        // --- Phase 4: Unit Testing (FIXED: Using VENV for PEP 668 compliance) ---
        stage('4. Unit Testing (Pytest)') {
            steps {
                echo 'Creating virtual environment, installing dependencies, and running unit tests.'
                // CRITICAL FIX: Use venv to isolate dependencies and comply with "externally-managed-environment"
                sh """
                    # 1. Create a virtual environment named 'venv'
                    /usr/bin/python3 -m venv venv
                    
                    # 2. Activate the environment (using the '.' source command)
                    # This ensures subsequent commands use 'venv/bin/pip' and 'venv/bin/pytest'
                    . venv/bin/activate
                    
                    echo "Installing dependencies inside virtual environment..."
                    pip install -r requirements.txt
                    
                    echo "Running unit tests..."
                    pytest
                """
            }
        }

        // --- Phase 5: Build Docker Image ---
        stage('5. Build Container Image') {
            steps {
                echo "Building Docker image: ${DOCKER_IMAGE_NAME}:${IMAGE_TAG}"
                sh "docker build -t ${DOCKER_IMAGE_NAME}:${IMAGE_TAG} ."

                echo "Tagging image as 'latest'"
                sh "docker tag ${DOCKER_IMAGE_NAME}:${IMAGE_TAG} ${DOCKER_IMAGE_NAME}:latest"
            }
        }

        // --- Phase 6: Push to Registry ---
        stage('6. Push Image to Docker Hub') {
            steps {
                echo "Pushing image to Docker Hub..."
                // Securely load Docker Hub credentials
                withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', passwordVariable: 'DOCKER_PASS', usernameVariable: 'DOCKER_USER_VAR')]) {
                    sh "echo ${DOCKER_PASS} | docker login -u ${DOCKER_USER_VAR} --password-stdin"
                    sh "docker push ${DOCKER_IMAGE_NAME}:${IMAGE_TAG}"
                    sh "docker push ${DOCKER_IMAGE_NAME}:latest"
                }
            }
        }

        // --- Phase 7: Deploy to Minikube (FIXED: Added Docker Secret Creation) ---
        stage('7. Deploy to Minikube') {
            steps {
                echo "Deploying new image to Kubernetes..."
                
                // Securely inject the Kubeconfig file credential and set KUBECONFIG env var
                withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIAL_ID, variable: 'KUBECONFIG_FILE_PATH')]) {
                    withEnv(["KUBECONFIG=${KUBECONFIG_FILE_PATH}"]) {
                        
                        // 1. CRITICAL FIX: Create/Update the Docker Hub Secret ('docker-hub-regcred')
                        // This prevents the "error: EOF" by providing Kubernetes with the credentials needed for imagePullSecrets.
                        echo "1. Creating/Updating Docker Hub registry secret ('docker-hub-regcred')..."
                        withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', passwordVariable: 'DOCKER_PASS', usernameVariable: 'DOCKER_USER_VAR')]) {
                            // Use dry-run=client -o yaml | kubectl apply -f - to create or update the secret idempotently
                            sh "kubectl create secret docker-registry docker-hub-regcred --docker-server=docker.io --docker-username=${DOCKER_USER_VAR} --docker-password=${DOCKER_PASS} --dry-run=client -o yaml | kubectl apply -f -"
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