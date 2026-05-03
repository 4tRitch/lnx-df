function yt --description 'yt-dlp with images using ogg'
  if test (count $argv) -eq 0
    printf '%s\n' 'Error: Specify at least one file to restore.' >&2
    return 1
  end

  printf '%s\n' 'Downloading ogg file'
  yt-dlp -q -f "bestaudio/best" -x \
     --audio-format vorbis \
     --audio-quality 0 \
     --embed-thumbnail \
     --convert-thumbnails jpg \
     --embed-metadata \
     -o "%(artist,creator,uploader)s - %(title)s.%(ext)s" \
     $argv

  printf '%s\n' 'Download finished'
end

