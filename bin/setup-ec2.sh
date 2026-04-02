#!/usr/bin/env bash
set -e

echo "======================================"
echo " Bookstore API - EC2 Bootstrap Script"
echo "======================================"

OS=$(uname -s)
if [ "$OS" != "Linux" ]; then
  echo "This script is intended for Linux (EC2). Detected: $OS"
  exit 1
fi

USE_SYSTEM_RUBY=false

echo ""
echo "--- [1/6] Installing system packages ---"
if command -v apt-get &>/dev/null; then
  echo "Detected: Debian/Ubuntu (apt-get)"
  sudo apt-get update -y
  sudo apt-get install -y \
    git curl wget build-essential \
    libssl-dev libreadline-dev zlib1g-dev \
    libsqlite3-dev sqlite3 \
    libyaml-dev libffi-dev libgdbm-dev \
    pkg-config

elif command -v dnf &>/dev/null; then
  echo "Detected: Amazon Linux 2023 / Fedora (dnf)"
  sudo dnf update -y
  sudo dnf groupinstall -y "Development Tools"
  # curl-minimal is pre-installed on AL2023 and conflicts with the full curl package
  sudo dnf install -y \
    git wget \
    openssl-devel readline-devel zlib-devel \
    sqlite sqlite-devel \
    libyaml-devel libffi-devel gdbm-devel \
    pkg-config
  # AL2023 ships Ruby 3.2 via dnf — use it directly to avoid compiling from
  # source, which hits an 'ar' bug in the system binutils on this platform
  echo ""
  echo "Installing Ruby from Amazon Linux package repo (avoids source-compile bugs)..."
  sudo dnf install -y ruby ruby-devel rubygems
  USE_SYSTEM_RUBY=true

elif command -v yum &>/dev/null; then
  echo "Detected: Amazon Linux 2 / CentOS / RHEL (yum)"
  sudo yum update -y
  sudo yum groupinstall -y "Development Tools"
  sudo yum install -y \
    git curl wget \
    openssl-devel readline-devel zlib-devel \
    sqlite sqlite-devel \
    libyaml-devel libffi-devel gdbm-devel \
    pkgconfig

else
  echo "ERROR: No supported package manager found (apt-get, dnf, yum)."
  exit 1
fi

echo ""
if [ "$USE_SYSTEM_RUBY" = true ]; then
  echo "--- [2/6] Skipping rbenv (using system Ruby) ---"
  ruby --version
else
  echo "--- [2/6] Installing rbenv + ruby-build ---"
  if [ ! -d "$HOME/.rbenv" ]; then
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(rbenv init -)"' >> ~/.bashrc
  fi
  export PATH="$HOME/.rbenv/bin:$PATH"
  eval "$(rbenv init -)"

  echo ""
  echo "--- [3/6] Installing Ruby 3.3.6 via rbenv ---"
  RUBY_VERSION="3.3.6"
  if ! rbenv versions | grep -q "$RUBY_VERSION"; then
    rbenv install "$RUBY_VERSION"
  fi
  rbenv global "$RUBY_VERSION"
  ruby --version
fi

echo ""
echo "--- [4/6] Installing Bundler and gems ---"
if [ "$USE_SYSTEM_RUBY" = true ]; then
  # Install Bundler 3.x for Rails 8 compatibility (4.x not yet supported)
  sudo gem uninstall bundler -a -x &>/dev/null || true
  sudo gem install bundler -v "~> 3.5" --no-document
else
  gem install bundler -v "~> 3.5" --no-document
fi
cd "$(dirname "$0")/.."
bundle install

echo ""
echo "--- [5/6] Setting up database ---"
bundle exec rails db:create db:migrate RAILS_ENV=production

echo ""
echo "--- [6/6] Starting the server ---"
echo "Starting Rails on port 3000 (production mode)..."
RAILS_ENV=production \
  SECRET_KEY_BASE=$(bundle exec rails secret) \
  bundle exec rails server -b 0.0.0.0 -p 3000 -e production

echo ""
echo "Done! Server running at http://<your-ec2-ip>:3000"
