def DOCKER_IMAGE_NAME = "26kishorekumar/aceest-fitness"

pipeline {
    // Run on any available Jenkins agent
    agent any
    
    tools {
        // FIX 1: Changed the tool type to the full, explicit class path
        // as required by your Jenkins environment when aliases fail.
        'hudson.plugins.sonar.SonarRunnerInstallation' 'SonarScannerTool'
    }
    
    // Define all necessary credentials and environment variables
    environment {
        // Credential IDs defined in Jenkins (Manage Credentials -> Global)
        SONAR_TOKEN_VAR = credentials('SonarQube-Server') // Secret text containing the token
        DOCKER_USER = '26kishorekumar'
        DOCKER_PASS = credentials('docker-hub-credentials') // Username with password
        
        // This ID MUST match the Secret File credential uploaded to Jenkins
        KUBECONFIG_CREDENTIAL_ID = 'MINIKUBE_KUBECONFIG' 
    }

    stages {
        stage('1. Checkout Code') {
            steps {
                echo 'Source code checked out by Declarative Pipeline SCM block.'
                // Explicit checkout for clarity, though SCM block does initial clone
                checkout scm
            }
        }

        stage('2. Code Quality Analysis') {
            steps {
                echo "Starting SonarQube analysis for project: aceest-fitness"
                // 'SonarQube-Server' matches the name set in Configure System
                withSonarQubeEnv('SonarQube-Server') {
                    // Use the securely loaded token credential
                    sh "sonar-scanner -Dsonar.projectKey=aceest-fitness -Dsonar.sources=. -Dsonar.login=${SONAR_TOKEN_VAR}"
                }
            }
        }
        
        stage('3. SonarQube Quality Gate') {
            steps {
                echo "Waiting for SonarQube analysis to complete..."
                timeout(time: 10, unit: 'MINUTES') {
                    // Wait for the Quality Gate result from SonarQube
                    waitForQualityGate abortPipeline: true
                }
                echo "SonarQube Quality Gate passed!"
            }
        }

        stage('4. Unit Testing (Pytest)') {
            steps {
                echo "Running Pytest inside a temporary container..."
                // Build a temporary image and run tests inside it
                sh "docker build -t aceest-test-runner:temp -f Dockerfile ."
                // Running pytest command: python -m pytest
                sh "docker run --rm aceest-test-runner:temp /usr/local/bin/python -m pytest" 
                // Clean up the temporary image
                sh "docker rmi aceest-test-runner:temp"
            }
        }

        stage('5. Build Container Image') {
            environment {
                // Ensure a unique build number is used for tagging
                IMAGE_TAG = "build-${BUILD_NUMBER}"
            }
            steps {
                echo "Building Docker image: ${DOCKER_IMAGE_NAME}:${IMAGE_TAG}"
                sh "docker build -t ${DOCKER_IMAGE_NAME}:${IMAGE_TAG} ."
                echo "Tagging image as 'latest'"
                sh "docker tag ${DOCKER_IMAGE_NAME}:${IMAGE_TAG} ${DOCKER_IMAGE_NAME}:latest"
            }
        }

        stage('6. Push Image to Docker Hub') {
            environment {
                IMAGE_TAG = "build-${BUILD_NUMBER}"
            }
            steps {
                echo "Pushing image to Docker Hub..."
                // Use DOCKER_PASS for secure login
                sh """
                    echo "${DOCKER_PASS}" | docker login -u ${DOCKER_USER} --password-stdin
                    docker push ${DOCKER_IMAGE_NAME}:${IMAGE_TAG}
                    docker push ${DOCKER_IMAGE_NAME}:latest
                """
            }
        }

        stage('7. Deploy to Minikube') {
            environment {
                // Use the build number tag for deployment to ensure the correct image is pulled
                IMAGE_TO_DEPLOY = "${DOCKER_IMAGE_NAME}:build-${BUILD_NUMBER}"
            }
            steps {
                echo "Deploying new image (${IMAGE_TO_DEPLOY}) to Kubernetes..."
                
                // Inject the kubeconfig file securely and set the KUBECONFIG env var
                withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIAL_ID, variable: 'KUBECONFIG_FILE_PATH')]) {
                    withEnv(["KUBECONFIG=${KUBECONFIG_FILE_PATH}"]) {
                        sh """
                            # This command uses the injected kubeconfig file path
                            kubectl set image deployment/aceest-fitness-deployment aceest-fitness=${IMAGE_TO_DEPLOY}
                        """
                    }
                }
                echo "Deployment command sent to Kubernetes."
            }
        }
    }
    
    post {
        always {
            echo "Pipeline finished. Cleaning up workspace."
            cleanWs()
        }
        success {
            echo "Logging out of Docker Hub."
            sh "docker logout"
            echo "Pipeline succeeded! 🎉"
        }
        failure {
            echo "Logging out of Docker Hub."
            sh "docker logout"
            echo "Pipeline failed! 😔"
        }
    }
}