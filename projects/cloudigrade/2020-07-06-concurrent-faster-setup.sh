#!/usr/bin/env bash
# asciinema rec -i2 -c THIS_FILE

DEMO_PROMPT='\[$(tput bold)$(tput setaf 2)\]$\[$(tput sgr0)\] '
DBDUMP_DIR='/tmp/benchdbdump/'

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
    chafa --symbols solid+space -s 115 --stretch /Users/brasmith/Desktop/misc/Cloudigrade\ Mascot/cheers1.png
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

function reinit_db() {
    pe 'dropdb -U postgres postgres && createdb -U postgres postgres && \
./cloudigrade/manage.py migrate && \
./cloudigrade/manage.py seed_review_data && \
time ./cloudigrade/manage.py spawndata --confirm \
--account_count=1 --image_count=140 --instance_count=90200 \
--mean_run_count=2 --mean_run_hours=0.45 \
1 "${DATE_30_DAYS_AGO}" && \
pg_dump -U postgres postgres > '"${DBDUMP_DIR}"'initial-db.sql'
    pe 'ls -l '"${DBDUMP_DIR}"'initial-db.sql'
    pe 'head '"${DBDUMP_DIR}"'initial-db.sql'
    pe 'wc '"${DBDUMP_DIR}"'initial-db.sql'
}

clear
####

title "dbdump for benchmarks"
header "
This demo creates a new database and populates it using the spawndata command.
It then simply dumps the database for reuse in later benchmarking runs.

This is an important prerequisite because generating this much data is slow,
and I don't want to waste time rebuilding it for every benchmark run.
"

screen_break

##############################################

header "First, set up the environment..."

export DATE_30_DAYS_AGO=$(gdate --date="30 day ago" "+%Y-%m-%d")
p 'DATE_30_DAYS_AGO=$(date --date="30 day ago" "+%Y-%m-%d") && echo $DATE_30_DAYS_AGO'
echo $DATE_30_DAYS_AGO
# export DATE_15_DAYS_AGO=$(gdate --date="15 day ago" "+%Y-%m-%d")
# p 'DATE_15_DAYS_AGO=$(date --date="15 day ago" "+%Y-%m-%d") && echo $DATE_15_DAYS_AGO'
# echo $DATE_15_DAYS_AGO
# export DATE_1_DAY_AGO=$(gdate --date="1 day ago" "+%Y-%m-%d")
# p 'DATE_1_DAY_AGO=$(date --date="1 day ago" "+%Y-%m-%d") && echo $DATE_1_DAY_AGO'
# echo $DATE_1_DAY_AGO

pe "rm -rf $DBDUMP_DIR && mkdir -p $DBDUMP_DIR"

pe 'git checkout master'

screen_break

##############################################

header "Reset the database and generate data roughly on the scale of the pilot
version's laska account which on 2019-03-08 saw in the preceding month
70 rhel images having 45108 instances with 40303 hours of runtime activity.
We did not track concurrency then, and we must make some guesses here.

By default, spawndata will generate roughly half of the images with RHEL and
half without. So, we use about twice the number of images and instances to
approximate the numbers we saw from the laska pilot account.

(90200 instances * ~0.5 rhel * ~2 runs * ~0.45 hours/run = ~40590 total hours)"

reinit_db
screen_break

####

dunzo
