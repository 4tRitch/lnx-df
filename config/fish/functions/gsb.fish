function gsb --description 'Git switch branch using checkout'
  if test -z "$argv[1]"
    printf '%s\n' 'Error: You must specify a branch name.' >&2
    return 1
  end

  printf 'Switching to branch: %s\n' $argv[1]
  git checkout $argv[1]
end
