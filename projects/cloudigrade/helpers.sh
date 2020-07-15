# Collect various common helper functions for demos here to stay DRY.

DEFAULT_MASCOT_PNG="/Users/brasmith/Desktop/misc/Cloudigrade Mascot/cheers1.png"
MASCOT_PNG=${MASCOT_PNG:="$DEFAULT_MASCOT_PNG"}
export MASCOT_PNG
# echo "$MASCOT_PNG"

DEFAULT_MASCOT_SIZE=115
MASCOT_SIZE=${MASCOT_SIZE:="$DEFAULT_MASCOT_SIZE"}
export MASCOT_SIZE
# echo "$MASCOT_SIZE"

DEFAULT_SLEEP_SECS=3
SLEEP_SECS=${SLEEP_SECS:="$DEFAULT_SLEEP_SECS"}
export SLEEP_SECS
# echo "$SLEEP_SECS"

# sleep 4

function screen_break() {
    sleep "${SLEEP_SECS}"
    clear
}

function dunzo() {
    echo
    chafa --symbols solid+space -s "${MASCOT_SIZE}" --stretch "${MASCOT_PNG}"
    echo
    sleep "${SLEEP_SECS}"
    sleep "${SLEEP_SECS}"
    clear
    exit
}

function title() {
    toilet -f standard -d /usr/local/share/figlet/fonts/ -t "$1"
}

function ecko() {
    tput setaf 245
    echo "$1" | sed -e 's/^/### /g'
    tput sgr0
}

function header() {
    ecko "$1"
    echo
    sleep "${SLEEP_SECS}"
}
