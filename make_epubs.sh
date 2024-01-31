#!/bin/sh

# From https://www.etalabs.net/sh_tricks.html, for working with arrays in portable POSIX
save () {
    for i do printf %s\\n "$i" | sed "s/'/'\\\\''/g;1s/^/'/;\$s/\$/' \\\\/" ; done
    echo " "
}

# Save the original argument array in case it's needed later.
_script_args=$(save "$@")

BOOK_SOURCES_DIR="$(dirname "$(realpath "$0")")"
EPUB_OUT_DIR="${BOOK_SOURCES_DIR}/epubs"
LOGS_OUT_DIR="${BOOK_SOURCES_DIR}/logs"
TIMESTAMP="$(date "+%F_%H-%M-%S")"

printf "Setting working directory: \"%s\"\n" "$BOOK_SOURCES_DIR"
cd "$BOOK_SOURCES_DIR" || exit

printf "Making sure epub output directory \"%s\" exists\n" "$EPUB_OUT_DIR"
mkdir -p "$EPUB_OUT_DIR"

printf "Making sure log output directory \"%s\" exists\n" "$LOGS_OUT_DIR"
mkdir -p "$LOGS_OUT_DIR"

if [ -d "$EPUB_OUT_DIR" ] && [ -z "$(find "$EPUB_OUT_DIR" -type d -empty)" ]; then
    printf "epub out dir \"%s\" is not empty, cleaning up\n" "$EPUB_OUT_DIR"
    rm -rf "${EPUB_OUT_DIR:?}/*"
fi
printf -- "\n"

set -- "make pristine" "make -C src pristine" "git clean -fxd"
# setup output fifos for output redirection
stdout_fifo="${TMPDIR:-/tmp}/make_epubs_out.$$"
stderr_fifo="${TMPDIR:-/tmp}/make_epubs_err.$$"
mkfifo "$stdout_fifo" "$stderr_fifo"
trap 'rm "$stdout_fifo" "$stderr_fifo"' EXIT
for book in ./*; do
    BOOK_NAME="$(basename "$book")"
    if [ "$BOOK_NAME" = "logs" ] || [ "$BOOK_NAME" = "epubs" ] || [ -f "$book" ]; then
        printf -- "************************* SKIPPING \"%s\"\n" "$book"
        continue
    fi

    BOOK_DIR="$(realpath "$book")"
    STDOUT_FILE="${LOGS_OUT_DIR}/${TIMESTAMP}-${BOOK_NAME}.stdout"
    tee -a "$STDOUT_FILE" < "$stdout_fifo" &
    STDOUT_PID=$!

    STDERR_FILE="${LOGS_OUT_DIR}/${TIMESTAMP}-${BOOK_NAME}.stderr"
    tee -a "$STDERR_FILE" < "$stderr_fifo" >&2 &
    STDERR_PID=$!
    {
        printf -- "***** Starting task for for \"%s\"\n" "$BOOK_NAME"
        printf -- "-- Changing working directory to \"%s\"\n" "$BOOK_DIR"
        cd "$BOOK_DIR" || exit
        printf -- "-- Cleaning up previous build for \"%s\"\n" "$BOOK_NAME"
        for next_cmd in "$@"; do
            printf -- "  -- Running command \"%s\"\n" "$next_cmd"
            eval "$next_cmd" >> "$STDOUT_FILE" 2>> "$STDERR_FILE"
        done

        printf -- "-- Building epub for \"%s\"\n" "$BOOK_NAME"
        make_cmd="make -C src ${BOOK_NAME}.epub"
        printf -- "  -- Running command \"%s\"\n" "$make_cmd"
        eval "$make_cmd" >> "$STDOUT_FILE" 2>> "$STDERR_FILE"
        printf -- "-- Moving epub for \"%s\" to \"%s\"\n" "$BOOK_NAME" "${EPUB_OUT_DIR}/${BOOK_NAME}.epub"
        mv "src/${BOOK_NAME}.epub" "${EPUB_OUT_DIR}/${BOOK_NAME}.epub"
    } >"$stdout_fifo" 2>"$stderr_fifo"

    printf -- "***** Completed task for for \"%s\"\n" "$BOOK_NAME"
    # shellcheck disable=SC2015
    [ -s "$STDERR_FILE" ] && printf -- "***** Task completed with errors, stderr contents at \"%s\"\n" "$STDERR_FILE" || rm -r "$STDERR_FILE"
    # shellcheck disable=SC2015
    [ -s "$STDOUT_FILE" ] && printf -- "***** stdout contents at \"%s\"\n" "$STDOUT_FILE" || rm -r "$STDOUT_FILE"

    kill -s 0 $STDOUT_PID > /dev/null 2>&1 && printf "Stopping stdout fifo capture at PID %s\n" "$STDOUT_PID" && kill -s INT $STDOUT_PID
    kill -s 0 $STDERR_PID > /dev/null 2>&1 && printf "Stopping stderr fifo capture at PID %s\n" "$STDERR_PID" && kill -s INT $STDERR_PID

    printf -- "\n"
    cd "$BOOK_SOURCES_DIR" || exit
done
