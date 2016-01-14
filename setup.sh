#!/bin/sh

# Forked from https://github.com/thoughtbot/laptop
# Last update 01/14/2016

fancy_echo() {
  local fmt="$1"; shift

  # shellcheck disable=SC2059
  printf "\n$fmt\n" "$@"
}

append_to_zshrc() {
  local text="$1" zshrc
  local skip_new_line="${2:-0}"

  if [ -w "$HOME/.zshrc.local" ]; then
    zshrc="$HOME/.zshrc.local"
  else
    zshrc="$HOME/.zshrc"
  fi

  if ! grep -Fqs "$text" "$zshrc"; then
    if [ "$skip_new_line" -eq 1 ]; then
      printf "%s\n" "$text" >> "$zshrc"
    else
      printf "\n%s\n" "$text" >> "$zshrc"
    fi
  fi
}

# shellcheck disable=SC2154
trap 'ret=$?; test $ret -ne 0 && printf "failed\n\n" >&2; exit $ret' EXIT

set -e

if [ ! -d "$HOME/.bin/" ]; then
  mkdir "$HOME/.bin"
fi

if [ ! -f "$HOME/.zshrc" ]; then
  touch "$HOME/.zshrc"
fi

# shellcheck disable=SC2016
append_to_zshrc 'export PATH="$HOME/.bin:$PATH"'

case "$SHELL" in
  */zsh) : ;;
  *)
    fancy_echo "Changing your shell to zsh ..."
      chsh -s "$(which zsh)"
    ;;
esac

brew_install_or_upgrade() {
  if brew_is_installed "$1"; then
    if brew_is_upgradable "$1"; then
      brew upgrade "$@"
    fi
  else
    brew install "$@"
  fi
}

brew_is_installed() {
  local name
  name="$(brew_expand_alias "$1")"

  brew list -1 | grep -Fqx "$name"
}

brew_is_upgradable() {
  local name
  name="$(brew_expand_alias "$1")"

  ! brew outdated --quiet "$name" >/dev/null
}

brew_tap() {
  brew tap "$1" --repair 2> /dev/null
}

brew_expand_alias() {
  brew info "$1" 2>/dev/null | head -1 | awk '{gsub(/.*\//, ""); gsub(/:/, ""); print $1}'
}

brew_launchctl_restart() {
  local name
  name="$(brew_expand_alias "$1")"
  local domain="homebrew.mxcl.$name"
  local plist="$domain.plist"

  mkdir -p "$HOME/Library/LaunchAgents"
  ln -sfv "/usr/local/opt/$name/$plist" "$HOME/Library/LaunchAgents"

  if launchctl list | grep -Fq "$domain"; then
    launchctl unload "$HOME/Library/LaunchAgents/$plist" >/dev/null
  fi
  launchctl load "$HOME/Library/LaunchAgents/$plist" >/dev/null
}

gem_install_or_update() {
  if gem list "$1" --installed > /dev/null; then
    gem update "$@"
  else
    gem install "$@"
    rbenv rehash
  fi
}

if ! command -v brew >/dev/null; then
  fancy_echo "Installing Homebrew ..."
    curl -fsS \
      'https://raw.githubusercontent.com/Homebrew/install/master/install' | ruby

    append_to_zshrc '# recommended by brew doctor'

    # shellcheck disable=SC2016
    append_to_zshrc 'export PATH="/usr/local/bin:$PATH"' 1

    export PATH="/usr/local/bin:$PATH"
fi

if brew list | grep -Fq brew-cask; then
  fancy_echo "Uninstalling old Homebrew-Cask ..."
  brew uninstall --force brew-cask
fi

fancy_echo "Updating Homebrew formulae ..."
brew_tap 'thoughtbot/formulae'
brew update

fancy_echo "Updating Unix tools ..."
brew_install_or_upgrade 'ctags'
brew_install_or_upgrade 'git'
brew_install_or_upgrade 'openssl'
brew unlink openssl && brew link openssl --force
# brew_install_or_upgrade 'rcm'
# brew_install_or_upgrade 'reattach-to-user-namespace'
# brew_install_or_upgrade 'the_silver_searcher'
brew_install_or_upgrade 'tmux'
brew_install_or_upgrade 'vim'
brew_install_or_upgrade 'zsh'
brew_install_or_upgrade 'tree'
brew_install_or_upgrade 'wget'

# fancy_echo "Updating Heroku tools ..."
# brew_install_or_upgrade 'heroku-toolbelt'
# brew_install_or_upgrade 'parity'

# fancy_echo "Updating GitHub tools ..."
# brew_install_or_upgrade 'hub'

fancy_echo "Updating image tools ..."
brew_install_or_upgrade 'imagemagick'

# fancy_echo "Updating testing tools ..."
# brew_install_or_upgrade 'qt'

fancy_echo "Updating programming languages ..."
brew_install_or_upgrade 'libyaml' # should come after openssl
brew_install_or_upgrade 'node'
brew_install_or_upgrade 'rbenv'
brew_install_or_upgrade 'ruby-build'

# fancy_echo "Updating databases ..."
# brew_install_or_upgrade 'postgres'
# brew_install_or_upgrade 'redis'
# brew_launchctl_restart 'postgresql'
# brew_launchctl_restart 'redis'

fancy_echo "Configuring Ruby ..."
find_latest_ruby() {
  rbenv install -l | grep -v - | tail -1 | sed -e 's/^ *//'
}

ruby_version="$(find_latest_ruby)"
# shellcheck disable=SC2016
append_to_zshrc 'eval "$(rbenv init - --no-rehash)"' 1
eval "$(rbenv init -)"

if ! rbenv versions | grep -Fq "$ruby_version"; then
  rbenv install -s "$ruby_version"
fi

rbenv global "$ruby_version"
rbenv shell "$ruby_version"
gem update --system
gem_install_or_update 'bundler'
number_of_cores=$(sysctl -n hw.ncpu)
bundle config --global jobs $((number_of_cores - 1))

if [ -f "$HOME/.laptop.local" ]; then
  fancy_echo "Running your customizations from ~/.laptop.local ..."
  # shellcheck disable=SC1090
  . "$HOME/.laptop.local"
fi

fancy_echo "Setting up ~/.zsh ..."
append_to_zshrc 'export EDITOR=vim'
append_to_zshrc "alias kedit='open -a \"/Applications/PhpStorm.app\"'"
append_to_zshrc "alias kdeit='open -a \"/Applications/PhpStorm.app\"'"
append_to_zshrc "alias keidt='open -a \"/Applications/PhpStorm.app\"'"
append_to_zshrc "alias mvim=\"/Applications/MacVim.app/Contents/MacOS/Vim\""
append_to_zshrc "alias vim='mvim -v'"
append_to_zshrc "alias flushdns='sudo killall -HUP mDNSResponder'"
append_to_zshrc "alias git_add='git add -A'"
append_to_zshrc "alias externalIP=\"curl -s http://checkip.dyndns.org | sed 's/[a-zA-Z/<> :]//g'\""
append_to_zshrc "alias publicIP=\"curl -s http://checkip.dyndns.org | sed 's/[a-zA-Z/<> :]//g'\""
append_to_zshrc "alias myIP=\"ipconfig getifaddr en0\""
append_to_zshrc "alias localIP=\"ipconfig getifaddr en0\""
append_to_zshrc "alias convert_png='mkdir pngs; sips -s format png *.jpg --out pngs'"
append_to_zshrc "alias listSVNexternals=\"svn propget svn:externals -R .\""
append_to_zshrc "alias svnDiff=\"svn diff -r PREV:COMMITTED\""
append_to_zshrc "alias apacheStart=\"sudo apachectl start\""
append_to_zshrc "alias apacheStop=\"sudo apachectl stop\""
append_to_zshrc "alias apacheRestart=\"sudo apachectl restart\""
append_to_zshrc "alias sqlStart=\"sudo /usr/local/mysql/support-files/mysql.server start\""
append_to_zshrc "alias sqlStop=\"sudo /usr/local/mysql/support-files/mysql.server stop\""
append_to_zshrc "alias mkdir=\"mkdir -p\""
append_to_zshrc "alias doSSH=\"ssh root@159.203.217.20\""
append_to_zshrc "alias errorLog=\"rm /tmp/php.log && tail -f /tmp/php.log\""
append_to_zshrc "alias masterDiff=\"git diff \$(git merge-base --fork-point master)\""
append_to_zshrc "alias latestTag='git describe --tags \`git rev-list --tags --max-count=1\`'"
append_to_zshrc "alias latestTagDiff='git show --name-only \`git describe --tags\` \`git rev-list --tags --max-count=1\`..'"

fancy_echo "Cleaning up old Homebrew formulae ..."
brew cleanup
brew cask cleanup