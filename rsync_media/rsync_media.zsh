#compdef rsync_media.sh rsync_media rsync-media rsync_media/rsync_media.sh ./rsync_media/rsync_media.sh

_rsync_media() {
  _arguments -s -S \
    '(-m --movies -t --tv)'{-m,--movies}'[Copy into /mnt/trahan-nas/Movies]' \
    '(-m --movies -t --tv)'{-t,--tv}'[Copy into /mnt/trahan-nas/TV]' \
    '(-d --dest-subdir)'{-d,--dest-subdir}'[Append a destination subdirectory]:destination subdirectory:' \
    '(-s --sane-dir)'{-s,--sane-dir}'[Derive a sanitized destination subdirectory from SOURCE_PATH]' \
    '(-h --help)'{-h,--help}'[Show help message]' \
    '*--[Pass remaining arguments directly to rsync]' \
    '1:source path:_files' \
    '2:destination subdirectory:'
}

if ! whence -w compdef >/dev/null 2>&1; then
  autoload -Uz compinit
  compinit -i >/dev/null 2>&1
fi

compdef _rsync_media \
  rsync_media.sh \
  rsync_media \
  rsync-media \
  rsync_media/rsync_media.sh \
  ./rsync_media/rsync_media.sh
compdef -p _rsync_media '*/rsync_media.sh'
