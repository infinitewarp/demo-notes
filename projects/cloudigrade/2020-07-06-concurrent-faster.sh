#!/usr/bin/env bash
# asciinema rec -i2 -c THIS_FILE

DEMO_PROMPT='\[$(tput bold)$(tput setaf 2)\]$\[$(tput sgr0)\] '
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

function reinit_db() {
    pe 'dropdb -U postgres postgres && createdb -U postgres postgres && \
./cloudigrade/manage.py migrate && \
./cloudigrade/manage.py seed_review_data && \
time ./cloudigrade/manage.py spawndata --confirm \
--account_count=1 --image_count=140 --instance_count=90200 \
--mean_run_count=2 --mean_run_hours=0.45 \
1 "${DATE_30_DAYS_AGO}"'
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

    kill_server
}

clear
####

title "concurrent speedup v1"
header "
This demo generates data with spawndata and then makes requests to the API for
a locally running cloudigrade server with a local postgresql database.

We perform the DB reload once with the old code and once with the new code.

In both setups, we query the API several times to gauge its performance.
"

screen_break

##############################################

header "First, set some common variables..."

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

header "Run the benchmarks for this initial laska-like data using old code."
run_all_benchmarks 'laska_old'
screen_break

####

header "Reset the database, update to new code, and apply migrations."
pe "git checkout 700-concurrent"

reinit_db
screen_break

header "Run the benchmarks for this initial laska-like data using old code."
run_all_benchmarks 'laska_new'
screen_break

######################

header "All 'ab' and 'curl' outputs were saved in ${BENCH_DIR} for review."
pe 'ls -lh "${BENCH_DIR}"*.{txt,json}'
screen_break

####

dunzo
