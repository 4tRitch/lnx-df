function __powerline_set_default_color --argument-names color
  if test -n "$color"; and test "$color" != default
    set_color $color
  end
end

function __powerline_pwd_label
  if test "$PWD" = "$HOME"
    printf '~'
    return 0
  end

  path basename -- $PWD
end

function __powerline_format_duration --argument-names elapsed_ms
  if test "$elapsed_ms" -ge 60000
    printf '%dm %02ds' (math --scale=0 "$elapsed_ms / 60000") (math --scale=0 "($elapsed_ms % 60000) / 1000")
  else
    printf '%.2fs' (math "$elapsed_ms / 1000")
  end
end

function __powerline_git_segment --argument-names now_ms
  if test $__POWERLINE_FORCE_GIT_REFRESH -eq 0; and test "$PWD" = "$__POWERLINE_GIT_LAST_PWD"; and test -n "$__POWERLINE_GIT_LAST_STATUS"; and test $__POWERLINE_GIT_LAST_CHECK_MS -gt 0
    set -l cached_age_ms (math --scale=0 "$now_ms - $__POWERLINE_GIT_LAST_CHECK_MS")

    if test $cached_age_ms -lt $__POWERLINE_GIT_CACHE_MS
      printf '%s' $__POWERLINE_GIT_LAST_STATUS
      return 0
    end
  end

  set -l porcelain (command git status --porcelain=2 --branch --no-renames 2>/dev/null); or begin
    set -g __POWERLINE_GIT_LAST_PWD $PWD
    set -g __POWERLINE_GIT_LAST_STATUS ''
    set -g __POWERLINE_GIT_LAST_CHECK_MS $now_ms
    set -g __POWERLINE_FORCE_GIT_REFRESH 0
    return 0
  end

  set -l lines (string split \n -- $porcelain)
  set -l branch ''
  set -l oid ''
  set -l symbols ''

  for line in $lines
    if string match -q '# branch.head *' -- $line
      set branch (string replace '# branch.head ' '' -- $line)
    else if string match -q '# branch.oid *' -- $line
      set oid (string replace '# branch.oid ' '' -- $line)
    else if string match -q '# branch.ab *' -- $line
      string match -q '*+0 -0' -- $line; or begin
        string match -q '*+0 *' -- $line; or set symbols "$symbols>"
        string match -q '* -0' -- $line; or set symbols "$symbols<"
      end
    else
      switch $line
        case '1 *' '2 *' 'u *' '? *'
          string match -q '*!*' -- $symbols; or set symbols "$symbols!"
      end
    end
  end

  if test -z "$branch" -o "$branch" = '(detached)'
    if test -n "$oid"
      set branch (string sub -l 7 -- $oid)
    else
      return 0
    end
  end

  set -l status_segment ' '
  set status_segment "$status_segment"(set_color $__POWERLINE_GIT_FG)'['$branch

  if test -n "$symbols"
    set status_segment "$status_segment $symbols"
  end

  set status_segment "$status_segment]"(set_color normal)

  set -g __POWERLINE_GIT_LAST_PWD $PWD
  set -g __POWERLINE_GIT_LAST_BRANCH $branch
  set -g __POWERLINE_GIT_LAST_STATUS $status_segment
  set -g __POWERLINE_GIT_LAST_CHECK_MS $now_ms
  set -g __POWERLINE_FORCE_GIT_REFRESH 0

  printf '%s' $status_segment
end

function fish_prompt
  set -l last_status $status
  set -l cmd_duration $CMD_DURATION
  set -l now (command date '+%s%3N:%H:%M')
  set -l now_parts (string split : -- $now)
  set -l now_ms $now_parts[1]
  set -l time_label "$now_parts[2]:$now_parts[3]"

  if test "$PWD" != "$__POWERLINE_LAST_PWD"
    set -g __POWERLINE_CWD (__powerline_pwd_label)
    set -g __POWERLINE_LAST_PWD $PWD
  end

  __powerline_set_default_color $__POWERLINE_DIR_FG
  printf '%s' $__POWERLINE_CWD
  set_color normal

  if test -n "$SSH_CONNECTION$SSH_CLIENT$SSH_TTY"
    printf ' '
    set_color $__POWERLINE_META_FG
    printf '@%s' $__POWERLINE_HOSTNAME
    set_color normal
  end

  printf ' '
  __powerline_set_default_color $__POWERLINE_TIME_FG
  printf 'at %s' $time_label
  set_color normal

  if test "$cmd_duration" -ge 1000
    printf ' '
    set_color $__POWERLINE_META_FG
    printf '(%s)' (__powerline_format_duration $cmd_duration)
    set_color normal
  end

  if test $last_status -ne 0
    printf ' '
    set_color $__POWERLINE_ERROR_FG
    printf '[x %d]' $last_status
    set_color normal
  end

  __powerline_git_segment $now_ms

  set -l user_symbol '$'
  if test $__POWERLINE_IS_ROOT -eq 1
    set -l root_context_fg $__POWERLINE_ROOT_LOGIN_FG
    set -l root_context_label '[root]'

    if test -n "$SUDO_USER"
      set root_context_fg $__POWERLINE_ROOT_SUDO_FG
      set root_context_label '[sudo]'
    end

    printf ' '
    set_color $root_context_fg
    printf '%s' $root_context_label
    set user_symbol '#'
    set_color normal
  end

  printf ' '
  if test $__POWERLINE_IS_ROOT -eq 1
    if test -n "$SUDO_USER"
      set_color $__POWERLINE_ROOT_SUDO_FG
    else
      set_color $__POWERLINE_ROOT_LOGIN_FG
    end
  end

  printf '%s ' $user_symbol
  set_color normal
end
