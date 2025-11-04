/**
 * ACEest Fitness CI/CD Pipeline
 *
 * This pipeline orchestrates the CI/CD flow, including quality gates, testing,
 * image building, and deployment to Minikube.
 *
 * NOTE: This Jenkinsfile assumes the following are configured in Jenkins:
 * 1. Credentials: 'docker-hub-credentials' (Username/Password), 'SonarQube-Server' (Secret Text/API Token).
 * 2. SonarQube Server is configured in "Configure System" and named 'SonarQube-Server'.
 */
pipeline {
    agent any

    environment {
        // --- Configuration ---
        // !! Replace 26kishorekumar with your actual Docker Hub username !!
        DOCKER_IMAGE_NAME = "26kishorekumar/aceest-fitness"
        SONAR_PROJECT_KEY = "aceest-fitness"
        // --- End Configuration ---

        IMAGE_TAG = "build-${env.BUILD_NUMBER}"
    }

    stages {
        // --- Stage 1: Checkout (Declarative is sufficient) ---
        stage('1. Checkout Code') {
            steps {
                echo 'Source code checked out by Declarative Pipeline SCM block.'
                // The actual 'checkout scm' runs automatically before the first stage.
            }
        }

        // --- Stage 2: Code Quality (SonarQube) ---
        stage('2. Code Quality Analysis') {
            steps {
                echo "Starting SonarQube analysis for project: ${SONAR_PROJECT_KEY}"
                withCredentials([string(credentialsId: 'SonarQube-Server', variable: 'SONAR_TOKEN_VAR')]) {
                    withSonarQubeEnv('SonarQube-Server') {
                        // Securely execute the scanner
                        sh "sonar-scanner -Dsonar.projectKey=${SONAR_PROJECT_KEY} -Dsonar.sources=. -Dsonar.login=\$SONAR_TOKEN_VAR"
                    }
                }
            }
        }

        // --- Stage 3: Quality Gate Check (Fixed Timeout) ---
        stage('3. SonarQube Quality Gate') {
            steps {
                echo 'Waiting for SonarQube analysis to complete...'
                
                // Add sleep buffer and increase timeout for compute engine reliability
                sleep 30
                
                timeout(time: 20, unit: 'MINUTES') { 
                    waitForQualityGate abortPipeline: true
                }
                echo 'SonarQube Quality Gate passed!'
            }
        }

        // --- Stage 4: Unit Testing (Pytest) ---
        stage('4. Unit Testing (Pytest)') {
            steps {
                echo 'Running unit tests with Pytest...'
                
                // DEBUG FIX: We are adding 'ls -l /app' and 'cat requirements.txt' to verify 
                // volume mounting and file visibility/readability inside the container.
                sh """
                    docker run --rm \
                        -v ${WORKSPACE}:/app \
                        -w /app \
                        python:3.9-slim \
                        bash -c "ls -l /app && cat requirements.txt && pip install -r requirements.txt && pytest"
                """
            }
        }

        // --- Stage 5: Build Docker Image ---
        stage('5. Build Container Image') {
            steps {
                echo "Building Docker image: ${DOCKER_IMAGE_NAME}:${IMAGE_TAG}"
                sh "docker build -t ${DOCKER_IMAGE_NAME}:${IMAGE_TAG} ."

                echo "Tagging image as 'latest'"
                sh "docker tag ${DOCKER_IMAGE_NAME}:${IMAGE_TAG} ${DOCKER_IMAGE_NAME}:latest"
            }
        }

        // --- Stage 6: Push to Registry ---
        stage('6. Push Image to Docker Hub') {
            steps {
                echo "Pushing image to Docker Hub..."
                withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', passwordVariable: 'DOCKER_PASS', usernameVariable: 'DOCKER_USER')]) {
                    sh "echo ${DOCKER_PASS} | docker login -u ${DOCKER_USER} --password-stdin"
                    sh "docker push ${DOCKER_IMAGE_NAME}:${IMAGE_TAG}"
                    sh "docker push ${DOCKER_IMAGE_NAME}:latest"
                }
            }
        }

        // --- Stage 7: Deploy to Minikube ---
        stage('7. Deploy to Minikube') {
            steps {
                echo "Deploying new image to Kubernetes..."
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
            cleanWs()
            sh 'docker logout'
        }
        success {
            echo 'Deployment successful! 🎉'
        }
        failure {
            echo 'Pipeline failed! 😔'
        }
        aborted {
            echo 'Pipeline was aborted, likely due to a timeout.'
        }
    }
}
