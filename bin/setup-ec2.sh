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

echo ""
echo "--- [1/6] Updating system packages ---"
if command -v apt-get &>/dev/null; then
  echo "Using apt-get (Debian/Ubuntu)..."
  sudo apt-get update -y
  sudo apt-get install -y \
    git curl wget build-essential \
    libssl-dev libreadline-dev zlib1g-dev \
    libsqlite3-dev sqlite3 \
    libyaml-dev libffi-dev libgdbm-dev \
    pkg-config
elif command -v dnf &>/dev/null; then
  echo "Using dnf (Amazon Linux 2023 / Fedora)..."
  sudo dnf update -y
  sudo dnf groupinstall -y "Development Tools"
  # curl-minimal is pre-installed on Amazon Linux 2023 and conflicts with curl; skip it
  sudo dnf install -y \
    git wget \
    openssl-devel readline-devel zlib-devel \
    sqlite sqlite-devel \
    libyaml-devel libffi-devel gdbm-devel \
    pkg-config
elif command -v yum &>/dev/null; then
  echo "Using yum (Amazon Linux 2 / CentOS / RHEL)..."
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
echo "--- [3/6] Installing Ruby 3.3.6 ---"
echo "Checking available disk space..."
AVAIL_KB=$(df -k / | awk 'NR==2 {print $4}')
AVAIL_GB=$(echo "scale=1; $AVAIL_KB / 1048576" | bc)
echo "Available: ${AVAIL_GB}GB"
if [ "$AVAIL_KB" -lt 2097152 ]; then  # less than 2GB free
  echo "WARNING: Less than 2GB free. Ruby compile may fail."
  echo "Consider expanding your EBS volume or terminating unused processes."
fi

RUBY_VERSION="3.3.6"
if ! rbenv versions | grep -q "$RUBY_VERSION"; then
  # --disable-static skips building libruby-static.a, saving ~500MB of disk and
  # avoiding an 'ar' bug on some Linux versions; not needed for running Rails
  RUBY_CONFIGURE_OPTS="--disable-static" rbenv install "$RUBY_VERSION"
fi
rbenv global "$RUBY_VERSION"
ruby --version

echo ""
echo "--- [4/6] Installing Bundler and gems ---"
gem install bundler --no-document
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
