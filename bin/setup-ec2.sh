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
sudo apt-get update -y
sudo apt-get install -y \
  git curl wget build-essential \
  libssl-dev libreadline-dev zlib1g-dev \
  libsqlite3-dev sqlite3 \
  libyaml-dev libffi-dev libgdbm-dev \
  pkg-config

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
RUBY_VERSION="3.3.6"
if ! rbenv versions | grep -q "$RUBY_VERSION"; then
  rbenv install "$RUBY_VERSION"
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
