# Base image: Use the same base as specified in your docker-compose.yml
FROM jenkins/jenkins:2.534-jdk17

# Switch to root user to install tools
USER root

# 1. Install necessary dependencies (wget, apt-transport-https, curl, python3, pip)
# 2. Install the Docker CLI: This allows the container to talk to the host's Docker daemon via the mounted socket.
# 3. Install kubectl: Necessary for deploying to Kubernetes/Minikube in Stage 7.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        wget \
        python3 \
        python3-pip \
        apt-transport-https \
        ca-certificates \
        gnupg2 \
        lsb-release && \
    # Install Docker CLI
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli && \
    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    # Clean up
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Switch back to the jenkins user
USER jenkins