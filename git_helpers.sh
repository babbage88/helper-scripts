set-gitssh-origin() {
  local baseurl="git@github.com:babbage88"
  local reponame="infra-cli.git"
  local remotename="origin"
  while [[ $# -gt 0 ]]; do
      case "$1" in
          --baseurl)
              baseurl="$2"
              shift 2
              ;;
          --reponame)
              reponame="$2"
              shift 2
              ;;
          --remotename)
              remotename="$2"
              shift 2
              ;;
          -h|--help)
              echo "Usage: set-gitssh-origin [--baseurl <url>] [--reponame <string>] [--remotename <string>]"
              echo "  --baseurl   Base Github URL (default: $baseurl)"
              echo "  --reponame   Repo short name (default: $reponame)"
              echo "  --remotename The name for the remote entry. (default: $remotename)"
              echo "  -h, --help    Show this help message"
              return 0
              ;;
          *)
              echo "Unknown argument: $1"
              echo "Use -h or --help for usage information."
              return 1
              ;;
      esac
  done
  echo "Changing $remotename to: $${baseurl}/$${reponame}"
  git remote set-url $remotename $${baseurl}/$${reponame}
  echo
  export outp=$(git remote -v)
  echo "git remote -v commd output:"
  echo $outp
}
