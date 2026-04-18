autoload -Uz colors add-zsh-hook vcs_info
colors

setopt PROMPT_SUBST

zmodload zsh/datetime

# PowerShell prompt visual parity, optimized for Zsh.
# Target shape: "cwd at HH:mm [branch symbols] $"

# --- Palette ---
# Match the original PowerShell prompt more closely:
# cwd/time/arrow keep terminal default color, git uses the same pink tone.
typeset -gr POWERLINE_DIR_FG="default"
typeset -gr POWERLINE_TIME_FG="default"
typeset -gr POWERLINE_GIT_FG="#CC6F82"
typeset -gr POWERLINE_ARROW_FG="default"
typeset -gr POWERLINE_ERROR_FG="#E06C75"
typeset -gr POWERLINE_META_FG="#7F848E"
typeset -gr POWERLINE_ROOT_FG="#E5C07B"
typeset -gr POWERLINE_ROOT_LOGIN_FG="#D19A66"
typeset -gr POWERLINE_ROOT_SUDO_FG="#E5C07B"

# --- vcs_info: branch detection without parsing full status every draw ---
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' use-simple true
zstyle ':vcs_info:git:*' formats '%b'
zstyle ':vcs_info:git:*' actionformats '%b'
zstyle ':vcs_info:*' check-for-changes false

typeset -g POWERLINE_EXIT_CODE=0
typeset -g POWERLINE_LAST_PWD=''
typeset -g POWERLINE_CWD='~'
typeset -g POWERLINE_TIME=''
typeset -g POWERLINE_GIT_SEGMENT=''
typeset -g POWERLINE_STATUS_SEGMENT=''
typeset -g POWERLINE_HOST_SEGMENT=''
typeset -g POWERLINE_DURATION_SEGMENT=''
typeset -g POWERLINE_CONTEXT_SEGMENT=''
typeset -g POWERLINE_USER_SYMBOL='$'
typeset -g POWERLINE_CMD_START=0

powerline_preexec() {
  POWERLINE_CMD_START=$EPOCHREALTIME
}

powerline_elapsed_ms() {
  local start_time=$1
  local end_time=$2
  local start_s=${start_time%%.*}
  local start_frac=${start_time#*.}
  local end_s=${end_time%%.*}
  local end_frac=${end_time#*.}

  [[ $start_frac == $start_time ]] && start_frac=0
  [[ $end_frac == $end_time ]] && end_frac=0

  start_frac=${(r:6::0:)start_frac[1,6]}
  end_frac=${(r:6::0:)end_frac[1,6]}

  local start_us=$(( 10#$start_frac ))
  local end_us=$(( 10#$end_frac ))
  local sec_diff=$(( end_s - start_s ))
  local usec_diff=$(( end_us - start_us ))

  if (( usec_diff < 0 )); then
    usec_diff=$(( usec_diff + 1000000 ))
    sec_diff=$(( sec_diff - 1 ))
  fi

  print -r -- $(( sec_diff * 1000 + usec_diff / 1000 ))
}

powerline_format_duration() {
  local elapsed_ms=$1

  if (( elapsed_ms >= 60000 )); then
    printf '%dm %02ds' $(( elapsed_ms / 60000 )) $(( (elapsed_ms % 60000) / 1000 ))
  else
    printf '%.2fs' "$(( elapsed_ms / 1000.0 ))"
  fi
}

powerline_pwd_label() {
  if [[ $PWD == $HOME ]]; then
    print -r -- '~'
    return
  fi

  print -r -- "${PWD:t}"
}

powerline_precmd() {
  POWERLINE_EXIT_CODE=$?
  POWERLINE_TIME=${EPOCHSECONDS:+$(strftime '%H:%M' $EPOCHSECONDS)}

  if [[ $PWD != $POWERLINE_LAST_PWD ]]; then
    POWERLINE_CWD=$(powerline_pwd_label)
    POWERLINE_LAST_PWD=$PWD
  fi

  POWERLINE_DURATION_SEGMENT=''
  if (( POWERLINE_CMD_START > 0 )); then
    local elapsed_ms
    elapsed_ms=$(powerline_elapsed_ms "$POWERLINE_CMD_START" "$EPOCHREALTIME")
    if (( elapsed_ms >= 1000 )); then
      POWERLINE_DURATION_SEGMENT=" %F{$POWERLINE_META_FG}($(powerline_format_duration $elapsed_ms))%f"
    fi
  fi
  POWERLINE_CMD_START=0

  POWERLINE_HOST_SEGMENT=''
  if [[ -n $SSH_CONNECTION || -n $SSH_CLIENT || -n $SSH_TTY ]]; then
    POWERLINE_HOST_SEGMENT=" %F{$POWERLINE_META_FG}@%m%f"
  fi

  POWERLINE_USER_SYMBOL='$'
  POWERLINE_CONTEXT_SEGMENT=''
  if (( EUID == 0 )); then
    local root_context_fg=$POWERLINE_ROOT_LOGIN_FG
    local root_context_label='[root]'

    if [[ -n $SUDO_USER ]]; then
      root_context_fg=$POWERLINE_ROOT_SUDO_FG
      root_context_label='[sudo]'
    fi

    POWERLINE_CONTEXT_SEGMENT=" %F{$root_context_fg}${root_context_label}%f"
    POWERLINE_USER_SYMBOL="%F{$root_context_fg}#%f"
  fi

  POWERLINE_STATUS_SEGMENT=''
  if (( POWERLINE_EXIT_CODE != 0 )); then
    POWERLINE_STATUS_SEGMENT=" %F{$POWERLINE_ERROR_FG}[x ${POWERLINE_EXIT_CODE}]%f"
  fi

  vcs_info
  POWERLINE_GIT_SEGMENT=''

  if [[ -n ${vcs_info_msg_0_} ]]; then
    local branch=${vcs_info_msg_0_}
    local git_dir porcelain first_line symbols=''

    git_dir=$(command git rev-parse --git-dir 2>/dev/null) || git_dir=''
    if [[ -n $git_dir ]]; then
      porcelain=$(command git status --porcelain=2 --branch 2>/dev/null)
      first_line=${porcelain%%$'\n'*}

      [[ $first_line == *'ahead '* ]] && symbols+='>'
      [[ $first_line == *'behind '* ]] && symbols+='<'
      [[ $porcelain == *$'\n1 '* || $porcelain == *$'\n2 '* || $porcelain == *$'\nu '* || $porcelain == *$'\n? '* ]] && symbols+='!'

      if [[ -n $symbols ]]; then
        POWERLINE_GIT_SEGMENT=" %F{$POWERLINE_GIT_FG}[${branch} ${symbols}]%f"
      else
        POWERLINE_GIT_SEGMENT=" %F{$POWERLINE_GIT_FG}[${branch}]%f"
      fi
    fi
  fi

  PROMPT="%F{$POWERLINE_DIR_FG}${POWERLINE_CWD}%f${POWERLINE_HOST_SEGMENT} %F{$POWERLINE_TIME_FG}at ${POWERLINE_TIME}%f${POWERLINE_DURATION_SEGMENT}${POWERLINE_STATUS_SEGMENT}${POWERLINE_GIT_SEGMENT}${POWERLINE_CONTEXT_SEGMENT} ${POWERLINE_USER_SYMBOL} "
}

add-zsh-hook preexec powerline_preexec
add-zsh-hook precmd powerline_precmd
