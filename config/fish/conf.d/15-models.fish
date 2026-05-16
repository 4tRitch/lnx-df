# ============================================
# Models configuration
# ============================================

function models --description 'List or run available AI models'
    set -l models_dir "$HOME/dev/ai"
    
    if not test -d "$models_dir"
        echo "Models directory not found: $models_dir" >&2
        return 1
    end
    
    # Get all model directories
    set -l all_models (realpath -s $models_dir/* 2>/dev/null)
    set -l model_count (count $all_models)
    
    if test $model_count -eq 0
        echo "No models found in $models_dir" >&2
        return 1
    end
    
    # Parse arguments - remove 'models' and '-l'/'--list' flags
    set -l args $argv
    set -l show_list false
    set -l show_help false
    set -l model_name ""
    set -l model_index ""
    
    for arg in $args
        if string match -q -- -l $arg || string match -q -- --list $arg
            set show_list true
        else if string match -q -- -h $arg || string match -q -- --help $arg
            set show_help true
        else if string match -q -- -r $arg
            # Next arg is model name
            set model_name $argv[2]
            set -e $argv[2]
        else if string match -q -- -ri $arg
            # Next arg is index
            set model_index $argv[2]
            set -e $argv[2]
        else if string match -q -- --run $arg
            # Next arg is model name
            set model_name $argv[2]
            set -e $argv[2]
        end
    end
    
    # Handle --help or -h FIRST
    if $show_help
        show_usage $all_models $model_count
        return 0
    end
    
    # Handle -l or --list
    if $show_list
        for model in $all_models
            printf '  - %s\n' (basename "$model")
        end
        return 0
    end
    
    # Handle -r (run by name)
    if test -n "$model_name"
        set -l model_path "$models_dir/$model_name"
        
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
    
    # Handle -ri (run by index)
    if test -n "$model_index"
        set -l index ($model_index | string match -r '^[0-9]+?$')
        
        if test -z "$index" || test "$index" -lt 0 || test "$index" -ge $model_count
            echo "Error: Invalid index. Available: 0 to $model_count" >&2
            return 1
        end
        
        set -l model_path "$models_dir/$all_models[$index]"
        
        if not test -f "$model_path/run.fish"
            echo "Error: run.fish not found in $model_path" >&2
            return 1
        end
        
        echo "Running model: $all_models[$index]"
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
    set -l model_paths $argv[1]
    set -l model_count $argv[2]
    
    echo "Usage:"
    echo "  models -l, --list          List available models"
    echo "  models --help, -h          Show this help"
    echo "  models -r <nombre>         Run model by name (executes run.fish)"
    echo "  models -ri <index>         Run model by index (0-based)"
    echo "  models --run <nombre>      Run model by name"
    echo ""
    echo "Available models:"
    set -l idx 1
    for path in $model_paths
        printf '  - %s\n' (basename "$path")
        set idx (math $idx + 1)
    end
end

# Alias para acceso rápido
alias mlist 'models -l'
