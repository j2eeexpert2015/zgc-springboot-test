#!/bin/sh
# Maven Wrapper script
# Downloads and runs Maven if not available

set -e

MAVEN_VERSION="3.9.6"
MAVEN_HOME="${HOME}/.m2/wrapper/dists/apache-maven-${MAVEN_VERSION}"
MAVEN_URL="https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz"

# Check if Maven is already available
if command -v mvn >/dev/null 2>&1; then
    exec mvn "$@"
fi

# Check if we have a cached version
if [ -x "${MAVEN_HOME}/bin/mvn" ]; then
    exec "${MAVEN_HOME}/bin/mvn" "$@"
fi

# Download Maven
echo "Downloading Maven ${MAVEN_VERSION}..."
mkdir -p "${HOME}/.m2/wrapper/dists"
curl -fsSL "${MAVEN_URL}" | tar -xz -C "${HOME}/.m2/wrapper/dists"

exec "${MAVEN_HOME}/bin/mvn" "$@"
