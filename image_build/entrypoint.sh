#!/bin/bash
set -e

# Mirror verifier path bridge (E2B requirement)
mkdir -p /workspace/.verifiers
if [ -d /home/user/.verifiers ]; then
    cp -r /home/user/.verifiers/. /workspace/.verifiers/
fi

# Set correct ownership for Jenkins
chown -R jenkins:jenkins /var/lib/jenkins
chown -R jenkins:jenkins /var/log/jenkins 2>/dev/null || true

# Re-export required env vars (E2B doesn't inherit Dockerfile ENV)
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH

# Start Jenkins as jenkins user in background
echo "[entrypoint] Starting Jenkins..."
su -s /bin/bash jenkins -c "
    export JAVA_HOME=$JAVA_HOME
    export PATH=$JAVA_HOME/bin:\$PATH
    java -jar /usr/share/jenkins/jenkins.war \
        --httpPort=8080 \
        --prefix=/ \
        --argumentsRealm.passwd.admin=admin \
        --argumentsRealm.roles.admin=admin \
        > /var/log/jenkins/jenkins.log 2>&1
" &

# Wait for Jenkins to be ready
echo "[entrypoint] Waiting for Jenkins to become available..."
MAX_WAIT=90
ELAPSED=0
until curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/login | grep -q "200"; do
    if [ $ELAPSED -ge $MAX_WAIT ]; then
        echo "[entrypoint] ERROR: Jenkins did not start within ${MAX_WAIT}s"
        cat /var/log/jenkins/jenkins.log
        exit 1
    fi
    sleep 3
    ELAPSED=$((ELAPSED + 3))
    echo "[entrypoint] Still waiting... (${ELAPSED}s)"
done

echo "[entrypoint] Jenkins is up at http://localhost:8080"

# Seed the broken pipeline job if not already present
JOB_DIR="/var/lib/jenkins/jobs/flaky-pipeline"
if [ ! -f "$JOB_DIR/config.xml" ]; then
    echo "[entrypoint] ERROR: Job config not found at $JOB_DIR/config.xml"
    exit 1
fi

# Reload Jenkins configuration from disk
curl -s -X POST http://admin:admin@localhost:8080/reload \
    --fail \
    || echo "[entrypoint] WARN: reload endpoint returned error (may be safe to ignore)"

echo "[entrypoint] Setup complete."

# Keep container alive
tail -f /var/log/jenkins/jenkins.log