function __lnx_df_item_entry_key --argument-names item_path
  set -l item_name (path basename -- $item_path)
  set -l item_lower (string lower -- $item_name)

  if test -d $item_path
    printf '.folder'
    return 0
  end

  if test "$item_name" = 'CMakeLists.txt'
    printf '.cmakelists'
    return 0
  end

  if string match -q '.*' -- $item_name
    set -l ext .$item_lower
    switch $ext
      case '.zshrc' '.gitignore' '.gitattributes'
        printf '%s' $ext
        return 0
    end
  end

  set -l ext (string lower -- (path extension -- $item_name))
  if test -z "$ext"
    switch $item_lower
      case readme license
        printf '%s' $item_lower
      case '*'
        printf '.default'
    end
    return 0
  end

  switch $ext
    case '.png' '.jpg' '.jpeg' '.webp' '.gif' '.ico' '.mkv' '.mp4' '.mov' '.avi' '.webm' '.flv' '.ogg' '.wav' '.mp3' '.m4a' '.flac' '.aac' '.aiff' '.zip' '.rar' '.7z' '.exe' '.msi' '.pdf' '.doc' '.docx' '.xls' '.xlsx' '.xml' '.csv' '.ps1' '.bat' '.sh' '.zsh' '.conf' '.md' '.js' '.jsx' '.json' '.jsonc' '.lua' '.c' '.clangd' '.cpp' '.h' '.rs' '.toml' '.lock' '.cs' '.csproj' '.sln' '.go' '.mod' '.sum' '.sql' '.psql'
      printf '%s' $ext
    case '*'
      printf '.default'
  end
end
