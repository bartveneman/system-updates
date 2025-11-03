#!/usr/bin/env bash

set -euo pipefail

echo "==> Updating Homebrew"
brew update
brew upgrade
brew upgrade --cask
brew cleanup

echo "==> Updating global npm and packages"
# Log current npm version
current_npm=$(npm --version)
echo "Current npm: $current_npm"
# update npm itself first
npm install -g npm
# update all global packages
npm update -g

echo "==> Updating NVM"
# Log current nvm version
if [ -d "$HOME/.nvm" ]; then
  cd "$HOME/.nvm"
  current_nvm=$(git describe --tags)
  echo "Current nvm: $current_nvm"
  cd -
fi
# fetch latest nvm version
latest_nvm=$(git ls-remote --tags https://github.com/nvm-sh/nvm.git | awk -F/ '{print $3}' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1)

if [ -d "$HOME/.nvm" ]; then
	cd "$HOME/.nvm"
	git fetch --tags origin
	git checkout "$latest_nvm"
	cd -
else
	git clone https://github.com/nvm-sh/nvm.git "$HOME/.nvm"
	cd "$HOME/.nvm"
	git checkout "$latest_nvm"
	cd -
fi

# reload nvm
. "$HOME/.nvm/nvm.sh"

echo "==> Updating Node via nvm"
# Log current Node version
current_node=$(node --version 2>/dev/null || echo "none")
echo "Current Node: $current_node"

latest_node=$(nvm version-remote --lts)
nvm install "$latest_node"
nvm alias default "$latest_node"

echo "==> Done"
