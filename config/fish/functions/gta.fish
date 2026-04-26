function gta --description 'Git add all or specified files'
  if test (count $argv) -eq 0
    printf '%s\n' 'Adding all files...'
    git add .
  else
    printf 'Adding specified files: %s\n' "$argv"
    git add $argv
  end
end
