function gti --description 'Remove assume-unchanged from files'
  if test (count $argv) -eq 0
    printf '%s\n' 'Error: Specify at least one file to include.' >&2
    return 1
  end

  printf 'Including files: %s\n' "$argv"
  git update-index --no-assume-unchanged $argv
end
