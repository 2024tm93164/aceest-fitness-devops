/**
 * This Declarative Pipeline file orchestrates the entire CI/CD flow for the
 * ACEest Fitness application, from testing to deployment on Kubernetes.
 *
 * Required Jenkins Configuration:
 * 1. Plugins: SonarQube Scanner, Docker Pipeline, Kubernetes CLI.
 * 2. Credentials:
 * - 'docker-hub-credentials': Your Docker Hub username/password (Secret Text).
 * - 'SonarQube-Server': Your SonarQube generated API Token (Secret Text).
 * 3. Tools:
 * - SonarQube Scanner configured in "Global Tool Configuration".
 * 4. System Config:
 * - SonarQube server connection configured in "Configure System" (URL set to http://172.17.0.1:9000).
 */
pipeline {
    // Run on any available Jenkins agent
    agent any

    // Environment variables used throughout the pipeline
    environment {
        // --- Configuration ---
        // !! Replace <YOUR_DOCKERHUB_USERNAME> with your actual username !!
        DOCKER_IMAGE_NAME = "26kishorekumar/aceest-fitness"
        SONAR_PROJECT_KEY = "aceest-fitness"
        // --- End Configuration ---

        IMAGE_TAG = "build-${env.BUILD_NUMBER}"
    }

    stages {
        // --- Phase 1: Checkout ---
        stage('1. Checkout Code') {
            steps {
                echo 'Checking out source code from Git...'
                // 'scm' automatically checks out from the repo linked to this pipeline job
                checkout scm
            }
        }

        // --- Phase 2: Code Quality (SonarQube) ---
        stage('2. Code Quality Analysis') {
            steps {
                script {
                    echo "Starting SonarQube analysis for project: ${SONAR_PROJECT_KEY}"
                    // 1. Use withCredentials to securely fetch the 'SonarQube-Server' token and store it in SONAR_AUTH_TOKEN
                    withCredentials([string(credentialsId: 'SonarQube-Server', variable: 'SONAR_AUTH_TOKEN')]) {
                        withSonarQubeEnv('SonarQube-Server') { // Matches the name in "Configure System"
                            // 2. Pass the token to the scanner using -Dsonar.login
                            // FIX: Escaping the '$' prevents Groovy interpolation, allowing the shell to resolve the token variable.
                            sh "sonar-scanner -Dsonar.projectKey=${SONAR_PROJECT_KEY} -Dsonar.sources=. -Dsonar.login=\${SONAR_AUTH_TOKEN}"
                        }
                    }
                }
            }
        }

        // --- Phase 3: Quality Gate ---
        stage('3. SonarQube Quality Gate') {
            steps {
                echo 'Waiting for SonarQube analysis to complete...'
                // Halts the pipeline if the SonarQube Quality Gate fails (e.g., new bugs, low coverage)
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
                echo 'SonarQube Quality Gate passed!'
            }
        }

        // --- Phase 4: Unit Testing ---
        stage('4. Unit Testing (Pytest)') {
            steps {
                echo 'Running unit tests with Pytest...'
                // Run tests inside a temporary container for a clean environment
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
                // Uses the 'docker-hub-credentials' ID configured in Jenkins
                withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', passwordVariable: 'DOCKER_PASS', usernameVariable: 'DOCKER_USER')]) {
                    sh "echo ${DOCKER_PASS} | docker login -u ${DOCKER_USER} --password-stdin"
                    sh "docker push ${DOCKER_IMAGE_NAME}:${IMAGE_TAG}"
                    sh "docker push ${DOCKER_IMAGE_NAME}:latest"
                }
            }
        }

        // --- Phase 7: Deploy to Kubernetes ---
        stage('7. Deploy to Minikube') {
            steps {
                echo "Deploying new image to Kubernetes..."
                // Ensures the Jenkins agent has kubectl configured to talk to your Minikube cluster
                // This command triggers a zero-downtime Rolling Update
                sh "kubectl set image deployment/aceest-fitness-deployment aceest-fitness=${DOCKER_IMAGE_NAME}:${IMAGE_TAG}"

                echo "Waiting for deployment to stabilize..."
                sh "kubectl rollout status deployment/aceest-fitness-deployment"
            }
        }
    }

    // --- Post-Pipeline Actions ---
    post {
        always {
            echo 'Pipeline finished. Cleaning up workspace.'
            // Clean up the Jenkins workspace
            cleanWs()
            // Log out of Docker
            sh 'docker logout'
        }
        success {
            echo 'Deployment successful!'
            // Add success notifications (e.g., Slack, Email) here
        }
        failure {
            echo 'Pipeline failed!'
            // Add failure notifications here
        }
    }
}
