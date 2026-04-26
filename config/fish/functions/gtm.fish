function gtm --description 'Git commit with default message'
  set -l comment $argv[1]

  if test -z "$comment"
    set comment 'f: minor update'
  end

  printf "Committing changes with message: '%s'\n" $comment
  git commit -m $comment
end
