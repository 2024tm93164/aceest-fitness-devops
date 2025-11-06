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

        // --- Phase 4: Unit Testing ---
        stage('4. Unit Testing (Pytest)') {
            steps {
                echo 'Running unit tests with Pytest...'
                // Runs tests inside a temporary Python container
                // NOTE: This will require the 'docker' command to be available on the Jenkins agent.
                sh 'docker run --rm -v ${WORKSPACE}:/app -w /app python:3.9-slim sh -c "pip install -r requirements.txt && pytest"'
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

        // --- Phase 7: Deploy to Minikube ---
        stage('7. Deploy to Minikube') {
            steps {
                echo "Deploying new image to Kubernetes..."
                
                // Securely inject the Kubeconfig file credential and set KUBECONFIG env var
                withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIAL_ID, variable: 'KUBECONFIG_FILE_PATH')]) {
                    withEnv(["KUBECONFIG=${KUBECONFIG_FILE_PATH}"]) {
                        // Rollout the new image tag
                        sh "kubectl set image deployment/aceest-fitness-deployment aceest-fitness=${DOCKER_IMAGE_NAME}:${IMAGE_TAG}"

                        echo "Waiting for deployment to stabilize..."
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