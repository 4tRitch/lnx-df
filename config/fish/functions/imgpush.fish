function imgpush --description "Transfer local clipboard image to a remote host /tmp and print the path"
    # Image paste into opencode over SSH cannot work natively: opencode reads the
    # clipboard by running wl-paste/xclip on the machine where IT runs, and the
    # remote is headless. This transfers the PNG bytes explicitly via scp instead.
    set -l host $argv[1]
    if test -z "$host"
        echo "usage: imgpush <host>"
        return 1
    end

    set -l tmp /tmp/.imgpush-(random).png
    if not wl-paste --type image/png >$tmp 2>/dev/null; or not test -s $tmp
        rm -f $tmp
        echo "imgpush: no image found in clipboard"
        return 1
    end

    set -l remote_path "/tmp/clipboard-"(date +%Y%m%d-%H%M%S)".png"
    if scp -q $tmp "$host:$remote_path"
        rm -f $tmp
        echo "$remote_path"
    else
        rm -f $tmp
        echo "imgpush: scp to $host failed"
        return 1
    end
end
