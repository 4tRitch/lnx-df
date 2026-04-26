function gtd --description 'Git diff for a file or path'
  if test -z "$argv[1]"
    printf '%s\n' 'Error: You must specify a file or path.' >&2
    return 1
  end

  printf 'Showing diff for: %s\n' $argv[1]
  git diff $argv[1]
end
