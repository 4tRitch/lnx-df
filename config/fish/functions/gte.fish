function gte --description 'Mark files as assume-unchanged'
  if test (count $argv) -eq 0
    printf '%s\n' 'Error: Specify at least one file to exclude.' >&2
    return 1
  end

  printf 'Excluding files: %s\n' "$argv"
  git update-index --assume-unchanged $argv
end
