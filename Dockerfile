FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install Java (Jenkins dependency) + utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-17-jdk \
    curl \
    wget \
    git \
    bash \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install Jenkins (pinned version)
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    ca-certificates \
    && curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2026.key | gpg --dearmor -o /usr/share/keyrings/jenkins-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] https://pkg.jenkins.io/debian binary/" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null \
    && apt-get update \
    && apt-get install -y jenkins \
    && rm -rf /var/lib/apt/lists/*

# E2B convention
RUN useradd --uid 1000 --create-home --shell /bin/bash user

# Copy broken Jenkins job config and scripts
COPY image_build/jenkins_home/ /var/lib/jenkins/
COPY image_build/scripts/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

# Copy entrypoint (starts Jenkins)
COPY image_build/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /workspace
USER user