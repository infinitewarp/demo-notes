#!/usr/bin/env bash
# asciinema rec -i2 -c THIS_FILE

DEMO_PROMPT='\[$(tput bold)$(tput setaf 2)\]$\[$(tput sgr0)\] '
DBDUMP_DIR='/tmp/benchdbdump/'
BENCH_DIR='/tmp/benchresults/'

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

function reload_db() {
    GIT_CHECKOUT_REF=$1

    pe "git checkout ${GIT_CHECKOUT_REF}"
    pe 'dropdb -U postgres postgres && createdb -U postgres postgres && \
psql -U postgres postgres < '"${DBDUMP_DIR}"'initial-db.sql'
    pe './cloudigrade/manage.py migrate'
}

function start_server() {
    header "starting cloudigrade server"
    ./cloudigrade/manage.py runserver &> /dev/null &
    p './cloudigrade/manage.py runserver &> /dev/null &'
    pe "sleep 2  # give the server a moment to start"
}

function kill_server() {
    header "stopping cloudigrade server"
    pe "ps auxww | grep -v grep | grep 'manage.py runserver' | awk '{print \$2}' | xargs -n1 kill"
}

function run_single_benchmark(){
    NAME=$1
    NAME_DESCRIPTION=$2
    REQUEST_PARAMS=$3

    pe 'ab -c1 -s600 -n10 '"$REQUEST_PARAMS"' | \
    tee /tmp/benchresults/'$NAME'-'$NAME_DESCRIPTION'-ab.txt | \
    tail -n 22'
    pe 'curl -s -m600 '"$REQUEST_PARAMS"' | \
    tee /tmp/benchresults/'$NAME'-'$NAME_DESCRIPTION'-response.json | \
    jq -C "[.data[] | [.date, .maximum_counts[0]]]"'
}

function run_all_benchmarks() {
    NAME=$1

    start_server
    screen_break

    REQUEST_PARAMS_TODAY='-H "X-RH-IDENTITY:${HTTP_X_RH_IDENTITY}" \
    http://127.0.0.1:8000/api/cloudigrade/v2/concurrent/'
    REQUEST_PARAMS_1_DAY_AGO='-H "X-RH-IDENTITY:${HTTP_X_RH_IDENTITY}" \
    http://127.0.0.1:8000/api/cloudigrade/v2/concurrent/?start_date="${DATE_1_DAY_AGO}"'
    REQUEST_PARAMS_15_DAYS_AGO='-H "X-RH-IDENTITY:${HTTP_X_RH_IDENTITY}" \
    http://127.0.0.1:8000/api/cloudigrade/v2/concurrent/?start_date="${DATE_15_DAYS_AGO}"'

    header "Requesting concurrent usage for '$NAME' with no specified date range.
Note: this gets only the latest day's data."
    run_single_benchmark "$NAME" 'default' "$REQUEST_PARAMS_TODAY"
    screen_break

    header "Requesting concurrent usage for '$NAME' starting 1 day ago.
Note: this gets 10 days of data starting from 1 day ago."
    run_single_benchmark "$NAME" '1dayago' "$REQUEST_PARAMS_1_DAY_AGO"
    screen_break

    header "Requesting concurrent usage for '$NAME' starting 15 days ago.
Note: this gets 10 days of data starting from 15 days ago."
    run_single_benchmark "$NAME" '15daysago' "$REQUEST_PARAMS_15_DAYS_AGO"
    screen_break

    kill_server
}

clear
####

title "concurrent speedup v1"
header "
This demo loads a saved database dump that was populated with spawndata,
starts a local cloudigrade server using that database, and makes API requests
to benchmark how the old and new code perform with the same initial data.

That saved database dump was already created for reuse by a previous script.
Please see the description of this recording for more details.

We perform the DB reload once with the old code and once with the new code.

In both setups, we query the API many times to benchmark its performance.
"

screen_break

##############################################

header "First, set up the environment..."

export ACCOUNT=100001
p "ACCOUNT=100001"
export HTTP_X_RH_IDENTITY=`echo '{
    "identity": {
        "account_number": "'"$ACCOUNT"'",
        "user": {
            "is_org_admin": true
        }
    }
}' | base64`
p 'HTTP_X_RH_IDENTITY=`echo '"'"'{
    "identity": {
        "account_number": "'"'"'"$ACCOUNT"'"'"'",
        "user": {
            "is_org_admin": true
        }
    }
}'"'"' | base64` && echo $HTTP_X_RH_IDENTITY'
echo $HTTP_X_RH_IDENTITY
export DATE_30_DAYS_AGO=$(gdate --date="30 day ago" "+%Y-%m-%d")
p 'DATE_30_DAYS_AGO=$(date --date="30 day ago" "+%Y-%m-%d") && echo $DATE_30_DAYS_AGO'
echo $DATE_30_DAYS_AGO
export DATE_15_DAYS_AGO=$(gdate --date="15 day ago" "+%Y-%m-%d")
p 'DATE_15_DAYS_AGO=$(date --date="15 day ago" "+%Y-%m-%d") && echo $DATE_15_DAYS_AGO'
echo $DATE_15_DAYS_AGO
export DATE_1_DAY_AGO=$(gdate --date="1 day ago" "+%Y-%m-%d")
p 'DATE_1_DAY_AGO=$(date --date="1 day ago" "+%Y-%m-%d") && echo $DATE_1_DAY_AGO'
echo $DATE_1_DAY_AGO

pe "rm -rf $BENCH_DIR && mkdir -p $BENCH_DIR"
pe 'ls -l '"${DBDUMP_DIR}"'initial-db.sql'

screen_break

##############################################

header "Reload the database with generated data roughly on the scale of the pilot
version's laska account which on 2019-03-08 saw in the preceding month
70 rhel images having 45108 instances with 40303 hours of runtime activity."

reload_db master
screen_break

####

header "Run the benchmarks for this initial laska-like data using old code."
run_all_benchmarks 'laska_old'
screen_break

####

header "Reload the database, update to new code, and apply migrations."

reload_db 700-concurrent
screen_break

####

header "Run the benchmarks for this initial laska-like data using old code."
run_all_benchmarks 'laska_new'
screen_break

######################

header "All 'ab' and 'curl' outputs were saved in ${BENCH_DIR} for review."
pe 'ls -lh "${BENCH_DIR}"*.{txt,json}'
screen_break

####

dunzo
