function ll --description 'Custom dotfiles item list with icons and colors'
  set -l target .

  if test (count $argv) -gt 0
    set target $argv[1]
  end

  if not test -e $target
    printf 'll: no such file or directory: %s\n' $target >&2
    return 1
  end

  set -l supports_vt 1
  if not isatty stdout; or test "$TERM" = dumb
    set supports_vt 0
  end

  set -l items
  if test -d $target
    set -l dirs
    set -l files
    set -l candidates "$target"/*
    set -a candidates "$target"/.*
    set candidates (path sort -- $candidates)

    for item in $candidates
      set -l name (path basename -- $item)
      test "$name" = . -o "$name" = ..; and continue

      if test -d $item
        set -a dirs $item
      else if test -f $item
        set -a files $item
      end
    end

    set items $dirs $files
  else
    set items $target
  end

  printf '%s\n' '-----------------'
  for item in $items
    set -l key (__lnx_df_item_entry_key $item)
    set -l item_name (path basename -- $item)

    if test $supports_vt -eq 1
      set -l icon (__lnx_df_item_icon $key)
      set -l color (__lnx_df_item_color $key)

      if test -n "$icon"
        printf '%s%s  %s%s\n' $color $icon $item_name (set_color normal)
      else
        printf '%s%s%s\n' $color $item_name (set_color normal)
      end
    else
      printf '%s\n' $item_name
    end
  end
  printf '%s\n' '-----------------'
end
