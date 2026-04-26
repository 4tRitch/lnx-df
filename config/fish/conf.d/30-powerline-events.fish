status is-interactive; or return

function __powerline_should_refresh_git --argument-names cmd
  string match -qr '(^|[;&|][[:space:]]*)(git|g)([[:space:]]+)(fetch|pull|push)([[:space:]]|$)' -- $cmd; and return 0
  string match -qr '(^|[;&|][[:space:]]*)(git|g)([[:space:]]+)remote([[:space:]]+)update([[:space:]]|$)' -- $cmd; and return 0
  string match -qr '(^|[;&|][[:space:]]*)(git|g)([[:space:]]+)(checkout|switch|commit|merge|rebase|reset|stash|cherry-pick|revert)([[:space:]]|$)' -- $cmd; and return 0
  return 1
end

function __powerline_preexec --on-event fish_preexec
  set -l cmd $argv[1]

  if __powerline_should_refresh_git $cmd
    set -g __POWERLINE_FORCE_GIT_REFRESH 1
  end
end
