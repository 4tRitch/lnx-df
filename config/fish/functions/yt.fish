function yt --description 'yt-dlp downloader with progress and audio/video modes'
  argparse 'a/audio' 'v/video' -- $argv
  or return

  if test (count $argv) -eq 0
    printf '%s\n' 'Error: Specify at least one URL.' >&2
    return 1
  end

  if set -q _flag_audio; and set -q _flag_video
    printf '%s\n' 'Error: Use only one mode: -a for audio or -v for video.' >&2
    return 1
  end

  function __yt_render_progress --argument-names line
    set -l payload (string replace -r '^__YT_PROGRESS__' '' -- $line)
    set -l parts (string split '|' -- $payload)
    set -l percent_raw (string trim -- $parts[1])
    set -l speed_raw (string trim -- $parts[2])
    set -l eta_raw (string trim -- $parts[3])

    if test -z "$eta_raw" -o "$eta_raw" = "NA"
      set eta_raw '--:--'
    end

    set -l percent_num (string replace -r '%$' '' -- $percent_raw | string trim)

    if test -z "$percent_num"
      return
    end

    set -l width 24
    set -l filled (math "round(($percent_num / 100) * $width)")

    if test $filled -lt 0
      set filled 0
    else if test $filled -gt $width
      set filled $width
    end

    set -l empty (math "$width - $filled")
    set -l bar (string join '' -- (string repeat -n $filled '█') (string repeat -n $empty '░'))

    printf '\r\e[2K[%s] %6s • %s • ETA %s' $bar $percent_raw $speed_raw $eta_raw
  end

  function __yt_run_with_custom_progress
    yt-dlp --quiet --no-warnings --progress --newline \
      --progress-template "__YT_PROGRESS__%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s" \
      $argv 2>&1 | while read -l line
        if string match -qr '^__YT_PROGRESS__' -- $line
          __yt_render_progress $line
        else if string match -qr '^(ERROR:|WARNING:|ERROR |WARNING )' -- $line
          printf '\n%s\n' "$line" >&2
        end
      end

    return $pipestatus[1]
  end

  if set -q _flag_video
    __yt_run_with_custom_progress \
      -f "bestvideo*+bestaudio/best" \
      --embed-metadata \
      -o "%(artist,creator,uploader)s - %(title)s.%(ext)s" \
      $argv
  else
    __yt_run_with_custom_progress \
      -f "bestaudio/best" -x \
      --audio-format vorbis \
      --audio-quality 0 \
      --embed-thumbnail \
      --convert-thumbnails jpg \
      --embed-metadata \
      -o "%(artist,creator,uploader)s - %(title)s.%(ext)s" \
      $argv
  end

  set -l yt_status $status
  functions -e __yt_render_progress __yt_run_with_custom_progress

  if test $yt_status -ne 0
    return $yt_status
  end

  printf '\n'
end
