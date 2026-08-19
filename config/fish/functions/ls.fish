function ls --description 'Pretty item list without args, classic ls with args'
  if count $argv >/dev/null
    command ls $argv
  else
    ll
  end
end