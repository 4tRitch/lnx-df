function gtl --description 'Git log, optionally limited by count'
  set -l index $argv[1]

  if test -z "$index"; or test "$index" -eq 0
    printf '%s\n' 'Showing full git log...'
    git log
  else
    printf 'Showing last %s commits...\n' $index
    git log "-$index"
  end
end
