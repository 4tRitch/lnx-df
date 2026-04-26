function gtr --description 'Git restore files'
  if test (count $argv) -eq 0
    printf '%s\n' 'Error: Specify at least one file to restore.' >&2
    return 1
  end

  printf 'Restoring files: %s\n' "$argv"
  git restore $argv
end
