def DOCKER_IMAGE_NAME = "26kishorekumar/aceest-fitness"

pipeline {
    agent any
    
    tools {
        'hudson.plugins.sonar.SonarRunnerInstallation' 'SonarScannerTool'
    }

    environment {
        SONAR_PROJECT_KEY = "aceest-fitness"
        DOCKER_USER = '26kishorekumar'
        KUBECONFIG_CREDENTIAL_ID = 'MINIKUBE_KUBECONFIG' 
        IMAGE_TAG = "build-${env.BUILD_NUMBER}"
    }

    stages {
        stage('1. Checkout Code') {
            steps {
                echo 'Source code checked out successfully (MOCK).' 
            }
        }

        stage('2. Code Quality') {
            environment {
                SONAR_SCANNER_HOME = tool 'SonarScannerTool'
            }
            steps {
                echo 'SonarScanner analysis simulated. (MOCK)'
            }
        }

        stage('3. Quality Gate') {
            steps {
                echo 'SonarQube Quality Gate passed! (MOCK)'
            }
        }

        stage('4. Unit Testing') {
            steps {
                echo 'Pytest simulated. All 10 tests passed! (MOCK)'
            }
        }

        stage('5. Build Image') {
            steps {
                echo 'Container image built successfully. (MOCK)'
            }
        }

        stage('6. Push Image') {
            steps {
                echo 'Image pushed to Docker Hub. (MOCK)'
            }
        }

        stage('7. Deploy to K8s') {
            steps {
                echo "Deployment applied to Kubernetes. (MOCK)"
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
            echo 'Pipeline failed! 😔 (This should not happen with mocked steps)'
        } 
    }
}