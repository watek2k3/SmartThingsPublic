#!/usr/bin/env bash
#
# Cloud Agent install script for SmartThingsPublic.
#
# SmartThingsPublic is a collection of Groovy SmartApps and Device Type
# Handlers. The canonical local developer check is the .githooks/pre-commit
# hook, which runs `groovyc` on changed *.groovy files to catch real syntax
# errors (SmartThings DSL "unable to resolve class" errors are ignored).
#
# The project pins Groovy 2.4.7 (see build.gradle) which requires a Java 8
# runtime, so this script installs both via SDKMAN and exposes version-pinned
# `groovy`/`groovyc` wrappers on PATH for non-interactive agent shells.
#
# Idempotent and non-interactive: safe to run repeatedly.
#
# Note: nounset (-u) is intentionally not used because SDKMAN's init script
# references unset variables.
set -eo pipefail

JAVA_VERSION="8.0.504+1-tem"
GROOVY_VERSION="2.4.7"
export SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"

echo "==> Installing SDKMAN (if needed)"
if [ ! -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]; then
  curl -fsSL "https://get.sdkman.io?rcupdate=false" | bash
fi
# Non-interactive: never prompt, do not auto-select installed candidates.
export sdkman_auto_answer=true
export sdkman_selfupdate_feature=false
# shellcheck disable=SC1091
source "$SDKMAN_DIR/bin/sdkman-init.sh"

echo "==> Installing Java ${JAVA_VERSION} (if needed)"
if [ ! -d "$SDKMAN_DIR/candidates/java/${JAVA_VERSION}" ]; then
  sdk install java "${JAVA_VERSION}" < /dev/null
fi

echo "==> Installing Groovy ${GROOVY_VERSION} (if needed)"
if [ ! -d "$SDKMAN_DIR/candidates/groovy/${GROOVY_VERSION}" ]; then
  sdk install groovy "${GROOVY_VERSION}" < /dev/null
fi

JAVA8_HOME="$SDKMAN_DIR/candidates/java/${JAVA_VERSION}"
GROOVY_BIN="$SDKMAN_DIR/candidates/groovy/${GROOVY_VERSION}/bin"

echo "==> Installing groovy/groovyc wrappers into /usr/local/bin"
# Wrappers pin JAVA_HOME to Java 8 so Groovy 2.4.7 runs regardless of the
# shell's default JDK, and work in non-interactive shells that don't source
# SDKMAN. sudo is available in the Cloud Agent VM.
# JAVA_OPTS forces UTF-8 source decoding so that files containing non-ASCII
# characters (e.g. the degree sign in temperature strings) compile the same way
# regardless of the shell's locale.
for tool in groovy groovyc; do
  sudo tee "/usr/local/bin/${tool}" > /dev/null <<EOF
#!/usr/bin/env bash
export JAVA_HOME="${JAVA8_HOME}"
export JAVA_OPTS="-Dfile.encoding=UTF-8 \${JAVA_OPTS:-}"
exec "${GROOVY_BIN}/${tool}" "\$@"
EOF
  sudo chmod 0755 "/usr/local/bin/${tool}"
done

echo "==> Configuring git to use the repository pre-commit hook"
# Mirrors the `configure` task in build.gradle. Best-effort: only when run
# inside the checked-out repository.
if git -C "$(dirname "$0")/.." rev-parse --git-dir > /dev/null 2>&1; then
  git -C "$(dirname "$0")/.." config core.hooksPath .githooks
fi

echo "==> Toolchain versions"
groovy --version
groovyc --version || true

echo "==> install.sh complete"
