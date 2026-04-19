typeset -gA LNX_DF_ITEM_ICONS
typeset -gA LNX_DF_ITEM_COLORS

lnx_df_rgb() {
  printf '\033[38;2;%s;%s;%sm' "$1" "$2" "$3"
}

LNX_DF_ITEM_ICONS=(
  '.default' $'\uf0f6'
  '.folder' $'\ue5ff'
  '.png' $'\uf03e'
  '.jpg' $'\uf03e'
  '.jpeg' $'\uf03e'
  '.webp' $'\uf03e'
  '.gif' $'\uf03e'
  '.ico' $'\uf03e'
  '.mkv' $'\uf03d'
  '.mp4' $'\uf03d'
  '.mov' $'\uf03d'
  '.avi' $'\uf03d'
  '.webm' $'\uf03d'
  '.flv' $'\uf03d'
  '.ogg' $'\uf001'
  '.wav' $'\uf001'
  '.mp3' $'\uf001'
  '.m4a' $'\uf001'
  '.flac' $'\uf001'
  '.aac' $'\uf001'
  '.aiff' $'\uf001'
  '.zip' $'\uf410'
  '.rar' $'\uf410'
  '.7z' $'\uf410'
  '.exe' $'\ue70f'
  '.msi' $'\ue70f'
  '.pdf' $'\uf1c1'
  '.doc' $'\uf1c2'
  '.docx' $'\uf1c2'
  '.xls' $'\uf1c3'
  '.xlsx' $'\uf1c3'
  '.xml' $'\uf1c3'
  '.csv' $'\uf1c3'
  '.ps1' $'\ue86c'
  '.bat' $'\uf489'
  '.sh' $'\ue691'
  '.zsh' $'\ue691'
  '.zshrc' $'\ue691'
  '.conf' $'\uf013'
  '.md' $'\u039b'
  '.gitignore' $'\ue702'
  '.gitattributes' $'\ue702'
  '.git' $'\ue702'
  '.js' $'\ued0d'
  '.jsx' $'\ued0d'
  '.json' $'\ued0d'
  '.jsonc' $'\ued0d'
  '.lua' $'\ue620'
  '.cmakelists' $'\ue673'
  '.c' $'\ue61e'
  '.clangd' $'\ue61e'
  '.cpp' $'\ue61e'
  '.h' $'\ue61e'
  '.rs' $'\ue7a8'
  '.toml' $'\ue7a8'
  '.lock' $'\ue7a8'
  '.cs' $'\ue7b2'
  '.csproj' $'\ue7b2'
  '.sln' $'\ue7b2'
  '.go' $'\ue627'
  '.mod' $'\ue627'
  '.sum' $'\ue627'
  '.sql' $'\ue76e'
  '.psql' $'\ue76e'
  'readme' $'\ueda4'
  'license' $'\ue60a'
)

LNX_DF_ITEM_COLORS=(
  '.default' "$(lnx_df_rgb 163 163 163)"
  '.folder' "$(lnx_df_rgb 210 210 210)"
  '.png' "$(lnx_df_rgb 246 95 156)"
  '.jpg' "$(lnx_df_rgb 246 95 156)"
  '.jpeg' "$(lnx_df_rgb 246 95 156)"
  '.webp' "$(lnx_df_rgb 246 95 156)"
  '.gif' "$(lnx_df_rgb 246 95 156)"
  '.ico' "$(lnx_df_rgb 246 95 156)"
  '.mkv' "$(lnx_df_rgb 147 145 195)"
  '.mp4' "$(lnx_df_rgb 147 145 195)"
  '.mov' "$(lnx_df_rgb 147 145 195)"
  '.avi' "$(lnx_df_rgb 147 145 195)"
  '.webm' "$(lnx_df_rgb 147 145 195)"
  '.flv' "$(lnx_df_rgb 147 145 195)"
  '.ogg' "$(lnx_df_rgb 178 168 255)"
  '.wav' "$(lnx_df_rgb 178 168 255)"
  '.mp3' "$(lnx_df_rgb 178 168 255)"
  '.m4a' "$(lnx_df_rgb 178 168 255)"
  '.flac' "$(lnx_df_rgb 178 168 255)"
  '.aac' "$(lnx_df_rgb 178 168 255)"
  '.aiff' "$(lnx_df_rgb 178 168 255)"
  '.zip' "$(lnx_df_rgb 239 234 95)"
  '.rar' "$(lnx_df_rgb 239 234 95)"
  '.7z' "$(lnx_df_rgb 239 234 95)"
  '.exe' "$(lnx_df_rgb 255 70 135)"
  '.msi' "$(lnx_df_rgb 255 70 135)"
  '.pdf' "$(lnx_df_rgb 255 80 80)"
  '.doc' "$(lnx_df_rgb 107 164 255)"
  '.docx' "$(lnx_df_rgb 107 164 255)"
  '.xls' "$(lnx_df_rgb 140 255 140)"
  '.xlsx' "$(lnx_df_rgb 140 255 140)"
  '.xml' "$(lnx_df_rgb 140 255 140)"
  '.csv' "$(lnx_df_rgb 140 255 140)"
  '.ps1' "$(lnx_df_rgb 110 191 252)"
  '.bat' "$(lnx_df_rgb 110 191 252)"
  '.sh' "$(lnx_df_rgb 77 201 77)"
  '.zsh' "$(lnx_df_rgb 77 201 77)"
  '.zshrc' "$(lnx_df_rgb 77 201 77)"
  '.conf' "$(lnx_df_rgb 214 190 92)"
  '.md' "$(lnx_df_rgb 255 255 255)"
  '.gitignore' "$(lnx_df_rgb 245 0 0)"
  '.gitattributes' "$(lnx_df_rgb 245 0 0)"
  '.git' "$(lnx_df_rgb 245 0 0)"
  '.js' "$(lnx_df_rgb 229 192 123)"
  '.jsx' "$(lnx_df_rgb 229 192 123)"
  '.json' "$(lnx_df_rgb 229 192 123)"
  '.jsonc' "$(lnx_df_rgb 229 192 123)"
  '.lua' "$(lnx_df_rgb 110 119 250)"
  '.cmakelists' "$(lnx_df_rgb 131 140 242)"
  '.c' "$(lnx_df_rgb 131 140 242)"
  '.clangd' "$(lnx_df_rgb 131 140 242)"
  '.cpp' "$(lnx_df_rgb 131 140 242)"
  '.h' "$(lnx_df_rgb 131 140 242)"
  '.rs' "$(lnx_df_rgb 244 80 111)"
  '.toml' "$(lnx_df_rgb 244 80 111)"
  '.lock' "$(lnx_df_rgb 244 80 111)"
  '.cs' "$(lnx_df_rgb 162 131 242)"
  '.csproj' "$(lnx_df_rgb 162 131 242)"
  '.sln' "$(lnx_df_rgb 162 131 242)"
  '.go' "$(lnx_df_rgb 110 191 252)"
  '.mod' "$(lnx_df_rgb 110 191 252)"
  '.sum' "$(lnx_df_rgb 110 191 252)"
  '.sql' "$(lnx_df_rgb 235 235 235)"
  '.psql' "$(lnx_df_rgb 235 235 235)"
  'readme' "$(lnx_df_rgb 163 163 163)"
  'license' "$(lnx_df_rgb 229 192 123)"
)

lnx_df_item_entry_key() {
  local item_path=$1
  local item_name=${item_path:t}
  local item_lower=${item_name:l}
  local ext=${item_name:e:l}

  if [[ -d $item_path ]]; then
    printf '.folder'
    return 0
  fi

  if [[ $item_name == 'CMakeLists.txt' ]]; then
    printf '.cmakelists'
    return 0
  fi

  if [[ -z $ext ]]; then
    if [[ -n ${LNX_DF_ITEM_ICONS[$item_lower]:-} ]]; then
      printf '%s' "$item_lower"
    else
      printf '.default'
    fi
    return 0
  fi

  ext=".${ext}"
  if [[ -n ${LNX_DF_ITEM_ICONS[$ext]:-} ]]; then
    printf '%s' "$ext"
  else
    printf '.default'
  fi
}

ll() {
  local path=$1
  local target
  local supports_vt=1
  local reset=$'\033[0m'
  local key icon color
  local -a items dirs files
  local item_name

  if [[ -z $path ]]; then
    target='.'
  else
    target=$path
  fi

  if [[ ! -e $target ]]; then
    print -u2 -- "ll: no such file or directory: $target"
    return 1
  fi

  if [[ ! -t 1 || ${TERM:-dumb} == dumb ]]; then
    supports_vt=0
    reset=''
  fi

  if [[ -d $target ]]; then
    dirs=("$target"/*(/DN))
    files=("$target"/*(.DN))
    items=("${dirs[@]}" "${files[@]}")
  else
    items=("$target")
  fi

  print -- '-----------------'
  for item_name in "${items[@]}"; do
    key=$(lnx_df_item_entry_key "$item_name")
    icon=${LNX_DF_ITEM_ICONS[$key]:-${LNX_DF_ITEM_ICONS[.default]}}
    color=${LNX_DF_ITEM_COLORS[$key]:-${LNX_DF_ITEM_COLORS[.default]}}

    if (( ! supports_vt )); then
      icon=''
      color=''
    fi

    if [[ -n $icon ]]; then
      print -r -- "${color}${icon}  ${item_name:t}${reset}"
    else
      print -r -- "${color}${item_name:t}${reset}"
    fi
  done
  print -- '-----------------'
}
