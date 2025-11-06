/**
 * ACEest Fitness CI/CD Pipeline
 *
 * This pipeline orchestrates the CI/CD flow, including quality gates, testing,
 * image building, and deployment to Minikube.
 *
 * FIX APPLIED: Stage 7 now uses `withKubeConfig` to securely inject the Kubernetes
 * configuration (Kubeconfig secret file) into the environment, fixing the "Authentication required" error.
 *
 * NOTE: This Jenkinsfile assumes the following are configured in Jenkins:
 * 1. Credentials: 'docker-hub-credentials' (Username/Password), 'SonarQube-Server' (Secret Text/API Token).
 * 2. SonarQube Server is configured in "Configure System" and named 'SonarQube-Server'.
 * 3. A Secret File credential named 'minikube-kubeconfig-file' containing your ~/.kube/config content is configured.
 */
pipeline {
    agent any

    environment {
        // --- Configuration ---
        // !! REPLACE 26kishorekumar with your actual Docker Hub username !!
        DOCKER_IMAGE_NAME = "26kishorekumar/aceest-fitness"
        SONAR_PROJECT_KEY = "aceest-fitness"
        
        // **NEW/CRITICAL FIX VARIABLE**
        // You MUST create a Jenkins Secret File credential containing your Minikube Kubeconfig
        // and replace the ID below with its actual ID.
        KUBECONFIG_CREDENTIAL_ID = "minikube-kubeconfig-file"
        // --- End Configuration ---

        IMAGE_TAG = "build-${env.BUILD_NUMBER}"
    }

    stages {
        // --- Stage 1: Checkout (Declarative is sufficient) ---
        stage('1. Checkout Code') {
            steps {
                echo 'Source code checked out by Declarative Pipeline SCM block.'
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
                echo 'Building temporary test image and running Pytest to bypass volume mount issues...'
                
                // 1. Build a temporary image.
                sh "docker build -t aceest-test-runner:temp -f Dockerfile ."
                
                // 2. Run the tests inside the temporary image.
                sh "docker run --rm aceest-test-runner:temp /usr/local/bin/python -m pytest"
                
                // 3. Clean up the temporary image immediately after testing
                sh "docker rmi aceest-test-runner:temp"
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

        // --- Stage 7: Deploy to Minikube (FIXED) ---
        stage('7. Deploy to Minikube') {
            steps {
                echo "Attempting deployment by injecting Kubeconfig credentials..."
                
                // **FIX:** Use withKubeConfig to inject the necessary KUBECONFIG environment variable.
                withKubeConfig(credentialsId: "${KUBECONFIG_CREDENTIAL_ID}") {
                    echo "Deploying new image to Kubernetes using tag: ${IMAGE_TAG}"
                    sh "kubectl set image deployment/aceest-fitness-deployment aceest-fitness=${DOCKER_IMAGE_NAME}:${IMAGE_TAG}"

                    echo "Waiting for deployment to stabilize..."
                    sh "kubectl rollout status deployment/aceest-fitness-deployment"
                }
            }
        }
    }

    // --- Post-Pipeline Actions ---
    post {
        always {
            echo 'Pipeline finished. Cleaning up workspace.'
            cleanWs()
            // Logout from Docker Hub for security
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
