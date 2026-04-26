function fcm --description 'Fast commit: add, commit, push'
  set -l comment $argv[1]
  printf '%s\n' 'Performing fast commit...'
  gta; and gtm $comment; and gtp
end
