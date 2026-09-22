#!/usr/bin/env bash
# Rebuild and re-run on every save -- the C++ equivalent of nodemon.
#
#   ./scripts/watch.sh          # rebuild + run
#   ./scripts/watch.sh build    # rebuild only
#
# Needs: brew install watchexec

set -euo pipefail
cd "$(dirname "$0")/.."

case "${1:-run}" in
    build) CMD="cmake --build --preset debug" ;;
    run)   CMD="cmake --build --preset debug && ./build/debug/diskmon" ;;
    *)     echo "usage: $0 [build|run]" >&2; exit 2 ;;
esac

if ! command -v watchexec >/dev/null 2>&1; then
    echo "needs watchexec:  brew install watchexec" >&2
    exit 1
fi

# --restart kills the previous run before starting the next one, which is what
# makes this work once diskmon becomes a long-running loop.
exec watchexec \
    --exts cpp,hpp,txt,json \
    --clear --restart \
    --watch src --watch CMakeLists.txt \
    -- "$CMD"
