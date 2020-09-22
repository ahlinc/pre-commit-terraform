#!/usr/bin/env bash

set -e

main() {
  initialize_
  parse_cmdline_ "$@"
  expand_config_param "${ARGS[@]}"
  tflint_
}

initialize_() {
  # get directory containing this script
  local dir
  local source
  source="${BASH_SOURCE[0]}"
  while [[ -L $source ]]; do # resolve $source until the file is no longer a symlink
    dir="$(cd -P "$(dirname "$source")" > /dev/null && pwd)"
    source="$(readlink "$source")"
    # if $source was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    [[ $source != /* ]] && source="$dir/$source"
  done
  _SCRIPT_DIR="$(dirname "$source")"

  # source getopt function
  # shellcheck source=lib_getopt
  . "$_SCRIPT_DIR/lib_getopt"
}

parse_cmdline_() {
  declare argv
  argv=$(getopt -o a: --long args: -- "$@") || return
  eval "set -- $argv"

  for argv; do
    case $argv in
      -a | --args)
        shift
        ARGS+=($1)
        shift
        ;;
      --)
        shift
        FILES=("$@")
        break
        ;;
    esac
  done
}

expand_config_param() {
    ARGS=()
    local passed=0 v c
    while [ $# -ne 0 ]; do
        echo "-- $1"
        case "$1" in
            -c|--config)
                c=$1
                shift
                if [ "${1:0:1}" != / ]; then
                    ARGS+=(--contig="$PWD/$1")
                else
                    ARGS+=($c)
                    ARGS+=($1)
                fi
                passed=1
                ;;
            --config=*)
                v="${1:9}"
                if [ "${v:0:1}" != / ]; then
                    ARGS+=(--config="$PWD/$v")
                else
                    ARGS+=($1)
                fi
                passed=1
                ;;
            *)
                ARGS+=($1)
                ;;
        esac
        shift
    done
    if [ "$passed" -eq 0 ]; then
        ARGS+=(--config="$PWD/.tflint.hcl")
    fi
}

tflint_() {
  local index=0
  for file_with_path in "${FILES[@]}"; do
    file_with_path="${file_with_path// /__REPLACED__SPACE__}"

    paths[index]=$(dirname "$file_with_path")

    ((index += 1))
  done

  for path_uniq in $(echo "${paths[*]}" | tr ' ' '\n' | sort -u); do
    path_uniq="${path_uniq//__REPLACED__SPACE__/ }"

    pushd "$path_uniq" > /dev/null
    tflint "${ARGS[@]}"
    popd > /dev/null
  done
}

# global arrays
declare -a ARGS
declare -a FILES

[[ ${BASH_SOURCE[0]} != "$0" ]] || main "$@"
