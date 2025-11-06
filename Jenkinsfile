/**
 * ACEest Fitness CI/CD Pipeline (Final Version)
 * * This Declarative Pipeline orchestrates the entire flow:
 * Checkout -> SonarQube Analysis & Quality Gate -> Unit Testing -> 
 * Docker Build & Push -> Kubernetes Deployment.
 */
pipeline {
    agent any
    
    // --- TOOL CONFIGURATION ---
    tools {
        // This name MUST exactly match the Name configured in Jenkins -> Global Tool Configuration.
        sonarQubeScanner 'SonarScannerTool'
    }

    environment {
        // These are the constants used throughout the pipeline
        DOCKER_IMAGE_NAME = "26kishorekumar/aceest-fitness"
        SONAR_PROJECT_KEY = "aceest-fitness"
        
        // Credential IDs used by the pipeline (must be configured in Jenkins Credentials Manager)
        DOCKER_CREDENTIAL_ID = "docker-hub-credentials"
        KUBECONFIG_CREDENTIAL_ID = "MINIKUBE_KUBECONFIG" // Using the ID from the guide
        SONAR_SERVER_NAME = "SonarQube-Server" // Matches SonarQube server configuration name
        
        // Dynamically generated tag for the current build
        IMAGE_TAG = "build-${env.BUILD_NUMBER}"
    }

    stages {
        stage('1. Checkout Code') {
            steps {
                echo 'Source code checked out by Declarative Pipeline SCM block.'
            }
        }

        stage('2. Code Quality Analysis') {
            steps {
                echo "Starting SonarQube analysis for project: ${SONAR_PROJECT_KEY}"
                
                // Uses the SonarQube server configuration defined in Configure System
                withSonarQubeEnv("${SONAR_SERVER_NAME}") {
                    // Note: sonar-scanner executable is made available by the 'tools' directive
                    sh "sonar-scanner -Dsonar.projectKey=${SONAR_PROJECT_KEY} -Dsonar.sources=. -Dsonar.login= " // SonarQube plugin handles the token securely
                }
            }
        }

        stage('3. SonarQube Quality Gate') {
            steps {
                echo 'Waiting for SonarQube analysis to complete...'
                timeout(time: 20, unit: 'MINUTES') { 
                    // This pauses the pipeline until the Quality Gate result is returned
                    waitForQualityGate abortPipeline: true
                }
                echo 'SonarQube Quality Gate passed!'
            }
        }

        stage('4. Unit Testing (Pytest)') {
            steps {
                echo 'Building temporary test image and running Pytest using Docker Pipeline steps.'
                
                script {
                    // Use native Docker Pipeline step for building a temporary image
                    def testImage = docker.build('aceest-test-runner:temp', '-f Dockerfile .')
                    
                    // Run the tests inside the temporary image
                    testImage.inside {
                        sh "/usr/local/bin/python -m pytest"
                    }
                }
            }
        }

        stage('5. Build Container Image') {
            steps {
                // Use native Docker Pipeline step for building
                echo "Building Docker image: ${DOCKER_IMAGE_NAME}:${IMAGE_TAG} using Multi-Stage Dockerfile."
                script {
                    // Build and tag the image using the unique build number
                    def builtImage = docker.build("${DOCKER_IMAGE_NAME}:${IMAGE_TAG}", '-f Dockerfile .')
                    
                    echo "Tagging image as 'latest'"
                    // Tag the same image reference as 'latest'
                    builtImage.tag("${DOCKER_IMAGE_NAME}:latest")
                }
            }
        }

        stage('6. Push Image to Docker Hub') {
            steps {
                echo "Pushing optimized image to Docker Hub..."
                // Use native Docker Pipeline step for pushing, securely using credentials
                script {
                    docker.withRegistry('https://registry.hub.docker.com', "${DOCKER_CREDENTIAL_ID}") {
                        sh "docker push ${DOCKER_IMAGE_NAME}:${IMAGE_TAG}"
                        sh "docker push ${DOCKER_IMAGE_NAME}:latest"
                    }
                }
            }
        }

        stage('7. Deploy to Minikube') {
            steps {
                echo "Attempting deployment by securely injecting Kubeconfig credentials..."
                
                // Use the Secret File credential type (MINIKUBE_KUBECONFIG)
                withCredentials([file(credentialsId: "${KUBECONFIG_CREDENTIAL_ID}", variable: 'KUBECONFIG_FILE')]) {
                    // Set the KUBECONFIG environment variable to point to the temporary file
                    withEnv(["KUBECONFIG=${KUBECONFIG_FILE}"]) {
                        echo "Deploying new image to Kubernetes using tag: ${IMAGE_TAG}"
                        
                        // Execute the kubectl command with the authenticated kubeconfig
                        sh "kubectl set image deployment/aceest-fitness-deployment aceest-fitness=${DOCKER_IMAGE_NAME}:${IMAGE_TAG}"
                        
                        // Wait for the rollout to complete before marking the stage successful
                        sh "kubectl rollout status deployment/aceest-fitness-deployment"
                    }
                }
            }
        }
    }

    post {
        always {
            echo 'Pipeline finished. Cleaning up workspace.'
            cleanWs()
        }
        success {
            echo 'Deployment successful! 🎉'
        }
        failure {
            echo 'Pipeline failed! 😔'
        }
    }
}