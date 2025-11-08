def DOCKER_IMAGE_NAME = "26kishorekumar/aceest-fitness"

pipeline {
    // Run on any available Jenkins agent
    agent any
    
    tools {
        'hudson.plugins.sonar.SonarRunnerInstallation' 'SonarScannerTool'
    }

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
                withCredentials([string(credentialsId: 'SonarQube-Server', variable: 'SONAR_TOKEN_VAR')]) {
                    withSonarQubeEnv('SonarQube-Server') {
                        sh "${SONAR_SCANNER_HOME}/bin/sonar-scanner -Dsonar.projectKey=${SONAR_PROJECT_KEY} -Dsonar.sources=. -Dsonar.login=\$SONAR_TOKEN_VAR"
                    }
                }
            }
        }

        stage('3. SonarQube Quality Gate') {
            steps {
                sleep 30
                timeout(time: 20, unit: 'MINUTES') { 
                    waitForQualityGate abortPipeline: true
                }
                echo 'SonarQube Quality Gate passed!'
            }
        }

        stage('4. Unit Testing (Pytest)') {
            steps {
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
                sh "docker build -t ${DOCKER_IMAGE_NAME}:${IMAGE_TAG} ."
                sh "docker tag ${DOCKER_IMAGE_NAME}:${IMAGE_TAG} ${DOCKER_IMAGE_NAME}:latest"
            }
        }

        stage('6. Push Image to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', passwordVariable: 'DOCKER_PASS', usernameVariable: 'DOCKER_USER_VAR')]) {
                    sh "echo ${DOCKER_PASS} | docker login -u ${DOCKER_USER_VAR} --password-stdin"
                    sh "docker push ${DOCKER_IMAGE_NAME}:${IMAGE_TAG}"
                    sh "docker push ${DOCKER_IMAGE_NAME}:latest"
                }
            }
        }

        // --- PHASE 7: DEPLOY TO MINIKUBE (FINAL, ABSOLUTE FIX: MANUAL BASE64 SECRET) ---
        stage('7. Deploy to Minikube') {
            steps {
                echo "Deploying new image to Kubernetes..."
                
                withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIAL_ID, variable: 'KUBECONFIG_FILE_PATH')]) {
                    withEnv(["KUBECONFIG=${KUBECONFIG_FILE_PATH}"]) {
                        
                        // 1. Create/Update the Docker Hub Secret using a manually constructed Base64 file.
                        echo "1. Creating/Updating Docker Hub registry secret ('docker-hub-regcred') via Base64 encoding..."
                        withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', passwordVariable: 'DOCKER_PASS', usernameVariable: 'DOCKER_USER_VAR')]) {
                            sh """
                                # Assign Groovy credentials to shell variables
                                DOCKER_USER='${DOCKER_USER_VAR}'
                                DOCKER_PASS='${DOCKER_PASS}'
                                SECRET_FILENAME="docker-secret-base64.yaml"
                                REGISTRY_URL="docker.io"

                                # CRITICAL: Base64 encode the raw username:password string
                                # The -n flag ensures no trailing newline is included in the base64 string.
                                # The -w 0 flag prevents line wrapping on some Linux systems.
                                AUTH_BASE64=\$(echo -n "\${DOCKER_USER}:\${DOCKER_PASS}" | base64 -w 0)

                                # Manually construct the .dockerconfigjson content, which is required
                                # for Kubernetes imagePullSecrets.
                                cat <<EOF > \${SECRET_FILENAME}
apiVersion: v1
kind: Secret
metadata:
  name: docker-hub-regcred
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: eyJhdXRocyI6eyJkb2NrZXIuaW8iOntcInVzZXJuYW1lXCI6XCIyNmtpc2hvcmVrdW1hclwiLFwicGFzc3dvcmRcIjpcIiR7RE9DS0VSX1BBU1N9XCIsXCJlbWFpbFwiOlwiXCIsXCJhdXRoXCI6XCJhVVl6TzNwb1pGZHlaWFJmYkZOcGNXMXpZWjFoYkdsMWJWUnFhWFYzY3k1dlkyRXJkRzhnXCIsXCJuYW1lXCI6XCJyZWdkcmVjXCJ9fX0=
EOF
                                
                                # FIX: Inject the actual base64 auth string into the YAML using sed
                                # This replaces the placeholder token 'aU9QW....' with the generated Base64 string.
                                # We must use a separate sed command since the heredoc structure makes Groovy interpolation complex.
                                # Note: I am now using a different approach to bypass the shell issues. 
                                
                                # Use a simpler approach by manually creating the full .dockerconfigjson
                                # This JSON object contains the entire required Docker config and is what we Base64 encode.
                                JSON_CONFIG="{\\"auths\\": {\\"\${REGISTRY_URL}\\": {\\"username\\": \\"\${DOCKER_USER}\\", \\"password\\": \\"\${DOCKER_PASS}\\", \\"email\\": \\"none@none.com\\", \\"auth\\": \\"\${AUTH_BASE64}\\"}}}"
                                
                                # Now, Base64 encode the entire JSON configuration string
                                FULL_CONFIG_BASE64=\$(echo -n \${JSON_CONFIG} | base64 -w 0)

                                # Create the Secret YAML using the FULL_CONFIG_BASE64
                                cat <<EOF_YAML > \${SECRET_FILENAME}
apiVersion: v1
kind: Secret
metadata:
  name: docker-hub-regcred
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: \${FULL_CONFIG_BASE64}
EOF_YAML
                                
                                # Step B: Apply the secret from the file
                                echo "-> Applying secret from \${SECRET_FILENAME}"
                                kubectl apply -f \${SECRET_FILENAME}
                                
                                # Step C: Clean up the temporary file immediately.
                                rm \${SECRET_FILENAME}
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