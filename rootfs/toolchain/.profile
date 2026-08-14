# ~/.profile — login shell (SSH)
export HOME="${CONTAINER_HOME:-/toolchain}"
cd "$HOME/workspace" 2>/dev/null || cd "$HOME" || true

if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi
