set -g LNX_DF_FISH_BOOTSTRAP_FILE (status filename)

if test "$LNX_DF_FISH_BOOTSTRAP_FILE" = "Standard input"
  set -g LNX_DF_FISH_CONFIG_ROOT $HOME/.config/fish
else
  set -g LNX_DF_FISH_CONFIG_ROOT (path dirname (path dirname (path resolve $LNX_DF_FISH_BOOTSTRAP_FILE)))
end

set -gx DCONF (path dirname $LNX_DF_FISH_CONFIG_ROOT)
set -gx DFL (path dirname $DCONF)

if not set -q DEVD
  set -gx DEVD $HOME/dev
end

set -g __POWERLINE_DIR_FG default
set -g __POWERLINE_TIME_FG default
set -g __POWERLINE_GIT_FG '#CC6F82'
set -g __POWERLINE_ERROR_FG '#E06C75'
set -g __POWERLINE_META_FG '#7F848E'
set -g __POWERLINE_ROOT_LOGIN_FG '#D19A66'
set -g __POWERLINE_ROOT_SUDO_FG '#E5C07B'
set -g __POWERLINE_GIT_CACHE_MS 1500

set -g __POWERLINE_LAST_PWD ''
set -g __POWERLINE_CWD '~'
set -g __POWERLINE_GIT_LAST_PWD ''
set -g __POWERLINE_GIT_LAST_BRANCH ''
set -g __POWERLINE_GIT_LAST_STATUS ''
set -g __POWERLINE_GIT_LAST_CHECK_MS 0
set -g __POWERLINE_FORCE_GIT_REFRESH 0
set -g __POWERLINE_HOSTNAME (prompt_hostname)

if fish_is_root_user
  set -g __POWERLINE_IS_ROOT 1
else
  set -g __POWERLINE_IS_ROOT 0
end
