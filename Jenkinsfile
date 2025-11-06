/**
 * ACEest Fitness CI/CD Pipeline
 *
 * FIX APPLIED:
 * 1. Stage 2: Added 'tool' directive and updated 'sh' command to resolve 'sonar-scanner: not found' error.
 * 2. Stages 4, 5, 6: Replaced raw 'sh "docker..."' commands with native Docker Pipeline steps (e.g., 'docker.build()')
 * to resolve 'docker: not found' errors.
 *
 * NOTE: This Jenkinsfile assumes the following are configured in Jenkins:
 * - A SonarQube Scanner tool is configured in Global Tool Configuration with the name 'SonarScannerTool'.
 * - Credentials: 'docker-hub-credentials' (Username/Password), 'SonarQube-Server' (Secret Text/API Token).
 * - SonarQube Server is configured in "Configure System" and named 'SonarQube-Server'.
 * - A Secret File credential named 'minikube-kubeconfig-file' containing your ~/.kube/config content is configured.
 */
pipeline {
    agent any
    
    // --- CRITICAL FIX 1: Define the SonarScanner tool to be installed automatically ---
    tools {
        // Name must match the configuration in Manage Jenkins -> Global Tool Configuration
        // NOTE: The name 'SonarScannerTool' is used here, ensure it matches your configuration.
        sonarQubeScanner 'SonarScannerTool'
    }
    // ----------------------------------------------------------------------------------

    environment {
        // --- Configuration ---
        DOCKER_IMAGE_NAME = "26kishorekumar/aceest-fitness"
        SONAR_PROJECT_KEY = "aceest-fitness"
        KUBECONFIG_CREDENTIAL_ID = "minikube-kubeconfig-file"
        // --- End Configuration ---

        IMAGE_TAG = "build-${env.BUILD_NUMBER}"
    }

    stages {
        stage('1. Checkout Code') {
            steps {
                echo 'Source code checked out by Declarative Pipeline SCM block.'
            }
        }

        // --- Stage 2: Code Quality (SonarQube) - FIX APPLIED ---
        stage('2. Code Quality Analysis') {
            steps {
                echo "Starting SonarQube analysis for project: ${SONAR_PROJECT_KEY}"
                withCredentials([string(credentialsId: 'SonarQube-Server', variable: 'SONAR_TOKEN_VAR')]) {
                    withSonarQubeEnv('SonarQube-Server') {
                        // FIX: sonar-scanner is now found because the 'tools' directive installed it.
                        sh "sonar-scanner -Dsonar.projectKey=${SONAR_PROJECT_KEY} -Dsonar.sources=. -Dsonar.login=\$SONAR_TOKEN_VAR"
                    }
                }
            }
        }

        // --- Stage 3: Quality Gate Check (Fixed Timeout) ---
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

        // --- Stage 4: Unit Testing (Pytest) - FIX APPLIED (Docker Pipeline Step) ---
        stage('4. Unit Testing (Pytest)') {
            steps {
                echo 'Building temporary test image and running Pytest using Docker Pipeline steps.'
                
                // FIX: Use native Docker Pipeline step for building
                def testImage = docker.build('aceest-test-runner:temp', '-f Dockerfile .')
                
                // Run the tests inside the temporary image.
                testImage.inside {
                    sh "/usr/local/bin/python -m pytest"
                }
                // Cleanup will happen automatically
            }
        }

        // --- Stage 5: Build Docker Image - FIX APPLIED (Docker Pipeline Step) ---
        stage('5. Build Container Image') {
            steps {
                // FIX: Use native Docker Pipeline step for building
                echo "Building Docker image: ${DOCKER_IMAGE_NAME}:${IMAGE_TAG} using Multi-Stage Dockerfile."
                docker.build("${DOCKER_IMAGE_NAME}:${IMAGE_TAG}", '-f Dockerfile .')
                
                echo "Tagging image as 'latest'"
                sh "docker tag ${DOCKER_IMAGE_NAME}:${IMAGE_TAG} ${DOCKER_IMAGE_NAME}:latest"
            }
        }

        // --- Stage 6: Push to Registry - FIX APPLIED (Docker Pipeline Step) ---
        stage('6. Push Image to Docker Hub') {
            steps {
                echo "Pushing optimized image to Docker Hub..."
                // FIX: Use native Docker Pipeline step for pushing, which handles credentials securely
                withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', passwordVariable: 'DOCKER_PASS', usernameVariable: 'DOCKER_USER')]) {
                    docker.withRegistry('https://registry.hub.docker.com', 'docker-hub-credentials') {
                        sh "docker push ${DOCKER_IMAGE_NAME}:${IMAGE_TAG}"
                        sh "docker push ${DOCKER_IMAGE_NAME}:latest"
                    }
                }
            }
        }

        // --- Stage 7: Deploy to Minikube (FIXED AUTHENTICATION) ---
        stage('7. Deploy to Minikube') {
            steps {
                echo "Attempting deployment by securely injecting Kubeconfig credentials..."
                withCredentials([file(credentialsId: 'minikube-kubeconfig-file', variable: 'KUBECONFIG_FILE')]) {
                    withEnv(["KUBECONFIG=${KUBECONFIG_FILE}"]) {
                        echo "Deploying new image to Kubernetes using tag: ${IMAGE_TAG}"
                        // Use sh command, now that kubectl should be in the PATH of the container via the KubeConfig setup.
                        sh "kubectl set image deployment/aceest-fitness-deployment aceest-fitness=${DOCKER_IMAGE_NAME}:${IMAGE_TAG}"
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
            // FIX: Removed 'docker logout' since native steps handle login/logout
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