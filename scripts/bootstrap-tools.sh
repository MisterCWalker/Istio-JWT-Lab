#!/usr/bin/env bash
set -euo pipefail

# Install required tools via Homebrew if not present
brew_install_if_missing() {
  local pkg="$1"
  if ! command -v "$pkg" >/dev/null 2>&1; then
    echo "Installing $pkg with Homebrew..."
    brew install "$pkg"
  fi
}

brew_install_if_missing kind
brew_install_if_missing kubectl
brew_install_if_missing helm
brew_install_if_missing istioctl
brew_install_if_missing jq
brew_install_if_missing openssl
brew_install_if_missing pre-commit

# Create kind cluster if missing
if ! kind get clusters 2>/dev/null | grep -q '^jwt-lab$'; then
  kind create cluster --name jwt-lab --config kind-cluster.yaml
fi

echo "OK: kind, kubectl, helm, istioctl, jq, openssl, pre-commit installed; cluster 'jwt-lab' ready."