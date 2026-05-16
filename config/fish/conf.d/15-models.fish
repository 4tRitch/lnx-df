# ============================================
# Models configuration
# ============================================

function models --description 'List or run available AI models'
    set -l models_dir "$HOME/dev/ai"
    
    if not test -d "$models_dir"
        echo "Models directory not found: $models_dir" >&2
        return 1
    end
    
    # Get all model directories (using realpath instead of ls -d)
    set -l all_models (realpath -s $models_dir/* 2>/dev/null)
    set -l model_count (count $all_models)
    
    if test $model_count -eq 0
        echo "No models found in $models_dir" >&2
        return 1
    end
    
    # Get command line args as a single string
    set -l cmd_line $commandline
    set -l args (string replace -r '^models ' '' (echo $cmd_line))
    
    # Check for --help or -h FIRST
    if string match -q -- --help -- -h -- $args
        show_usage $all_models $model_count
        return 0
    end
    
    # Check for -l or --list
    if string match -q -- --list -- -l -- $args
        for model in $all_models
            printf '  - %s\n' (basename "$model")
        end
        return 0
    end
    
    # Check for -r
    if string match -q -- -r (echo $cmd_line)
        set -l model_name (echo $cmd_line | string match -r '^-r[[:space:]]+(.*)$' | string match -r -i '.*$')
        set -l model_path $models_dir/$model_name
        
        if not test -d "$model_path"
            echo "Error: Model '$model_name' not found in $models_dir" >&2
            return 1
        end
        
        if not test -f "$model_path/run.fish"
            echo "Error: run.fish not found in $model_path" >&2
            return 1
        end
        
        echo "Running model: $model_name"
        echo "Path: $model_path"
        cd "$model_path"
        . run.fish
        return 0
    end
    
    # Check for --run
    if string match -q -- --run (echo $cmd_line)
        set -l remaining (echo $cmd_line | string replace -r '^--run ' '')
        
        if string match -q -- -ri (echo $cmd_line)
            set -l index (echo $cmd_line | string replace -r '^--ri ' '')
            set -l index ($index | string match -r '^[0-9]+?$')
            
            if test -z "$index" || test "$index" -lt 0 || test "$index" -gt $model_count
                echo "Error: Invalid index. Available: 0 to $model_count" >&2
                return 1
            end
            
            set -l model_path $models_dir/$all_models[$index]
        else
            set -l model_name (echo $cmd_line | string replace -r '^--run ' '')
            set -l model_path $models_dir/$model_name
        end
        
        if not test -d "$model_path"
            echo "Error: Model '$model_name' not found in $models_dir" >&2
            return 1
        end
        
        if not test -f "$model_path/run.fish"
            echo "Error: run.fish not found in $model_path" >&2
            return 1
        end
        
        echo "Running model: $model_name"
        echo "Path: $model_path"
        cd "$model_path"
        . run.fish
        return 0
    end
    
    # No valid flags - show usage
    echo "Error: Invalid command."
    echo ""
    show_usage $all_models $model_count
    return 1
end

# Function to show usage
function show_usage
    set -l all_models $argv[1]
    set -l model_count $argv[2]
    
    echo "Usage:"
    echo "  models -l, --list          List available models"
    echo "  models --help, -h          Show this help"
    echo "  models -r <nombre>         Run model by name (executes run.fish)"
    echo "  models -ri <index>         Run model by index (0-based)"
    echo "  models --run --index <n>   Run model by index"
    echo ""
    echo "Available models:"
    for idx in $all_models
        printf '  - %s\n' (basename "$idx")
    end
end

# Alias para acceso rápido
alias mlist 'models -l'
