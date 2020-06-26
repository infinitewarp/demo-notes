#!/usr/bin/env bash
# asciinema rec -i2 -c THIS_FILE

DEMO_PROMPT='\[$(tput bold)$(tput setaf 2)\]$\[$(tput sgr0)\] '

# -d disabled simulated typing
# -n no wait netween commands
# -w1 max wait for 1 second between commands
source ~/projects/personal/demo-magic/demo-magic.sh -w1

# gotta go fast? uncomment these:
# NO_WAIT=(true)
# unset TYPE_SPEED

function screen_break() {
    sleep 3
    clear
}

function dunzo() {
    echo
    chafa --symbols solid+space -s 135 --stretch /Users/brasmith/Desktop/misc/Cloudigrade\ Mascot/cheers1.png
    echo
    sleep 5
    clear
    exit
}

function title() {
    toilet -f standard -d /usr/local/share/figlet/fonts/ -t "$1"
}

function header() {
    tput setaf 245
    echo "$1" | sed -e 's/^/### /g'
    tput sgr0
    echo
    sleep 2
}

clear
##############################################

title "CloudAccount AttributeError"
header "
https://gitlab.com/cloudigrade/cloudigrade/-/issues/703
https://gitlab.com/cloudigrade/cloudigrade/-/merge_requests/755

This demo reproduces and attempts to fix an elusive AttributeError ('NoneType'
object has no attribute 'disable') that would occur as the result of
cloudigrade processing multiple requests in rapid succession to delete a
specific CloudAccount.

In this demo, I locally add a 'sleep' in CloudAccount.disable to make the
timing problem occur. The exception in the second request only happens if
it is timed to start after the first request has started the pre_delete
signal processing but before actually deleting the DB row.
"

screen_break
##############################################

header "Reproduce error with multiple screen sessions using old code."

pe 'git checkout master'
pe 'git stash pop'
pe 'git diff'
pe 'screen-4.8.0'
# Once inside screen...
# `^c |`, `^c tab`, `^c c`, `^c X`, etc.
# ./cloudigrade/manage.py shell
pe 'git stash'

screen_break
##############################################

header "Verify no error with multiple screen sessions using new code."

pe 'git checkout 703-attribute-error'
pe 'git stash pop'
pe 'git diff'
pe 'screen-4.8.0'
# Once inside screen...
# `^c |`, `^c tab`, `^c c`, `^c X`, etc.
# ./cloudigrade/manage.py shell
pe 'git stash'

screen_break

##############################################

dunzo
