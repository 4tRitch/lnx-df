function tmux --wraps tmux --description 'Attach to or create the main tmux session'
  if test (count $argv) -eq 0
    command tmux new-session -A -s main
  else
    command tmux $argv
  end
end
