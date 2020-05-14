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
pg_dump -U postgres postgres > '"${BENCH_DIR}"'initial-db.sql'
}

function reload_db() {
    pe 'dropdb -U postgres postgres && createdb -U postgres postgres && \
psql -U postgres postgres < '"${BENCH_DIR}"'initial-db.sql'
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

    pe 'ab -c1 -s600 -n50 '"$REQUEST_PARAMS"' | \
    tee /tmp/benchresults/'$NAME'-'$NAME_DESCRIPTION'-ab.txt | \
    tail -n 22'
    pe 'curl -s -m600 '"$REQUEST_PARAMS"' | \
    tee /tmp/benchresults/'$NAME'-'$NAME_DESCRIPTION'-response.json | \
    jq -C ".data[] | {date:.date,instances:.instances,vcpu:.vcpu,memory:.memory}" | \
    head -n 18'
}

function run_all_benchmarks() {
    NAME=$1

    start_server
    screen_break

    REQUEST_PARAMS_TODAY='-H "X-RH-IDENTITY:${HTTP_X_RH_IDENTITY}" \
    http://127.0.0.1:8000/api/cloudigrade/v2/concurrent/'
    REQUEST_PARAMS_15_DAYS_AGO='-H "X-RH-IDENTITY:${HTTP_X_RH_IDENTITY}" \
    http://127.0.0.1:8000/api/cloudigrade/v2/concurrent/?start_date="${DATE_15_DAYS_AGO}"'
    REQUEST_PARAMS_30_DAYS_AGO='-H "X-RH-IDENTITY:${HTTP_X_RH_IDENTITY}" \
    http://127.0.0.1:8000/api/cloudigrade/v2/concurrent/?start_date="${DATE_30_DAYS_AGO}"'

    header "Requesting concurrent usage for '$NAME' with no specified date range.
Note: this gets only the latest day's data."
    run_single_benchmark "$NAME" 'default' "$REQUEST_PARAMS_TODAY"
    screen_break

    header "Requesting concurrent usage for '$NAME' starting 15 days ago.
Note: this gets 10 days of data starting from 15 days ago."
    run_single_benchmark "$NAME" '15daysago' "$REQUEST_PARAMS_15_DAYS_AGO"
    screen_break

    header "Requesting concurrent usage for '$NAME' starting 30 days ago.
Note: this gets 10 days of data starting from 30 days ago."
    run_single_benchmark "$NAME" '30daysago' "$REQUEST_PARAMS_30_DAYS_AGO"
    screen_break

    kill_server
}

clear
####

title "spawndata benchy"
header "
The spawndata management commmand exists to help developers generate large
sets of pseudorandom data including accounts, images, instances, and events.
This data may be used as a base for running performance and scale tests.

This demo runs spawndata various ways and then makes requests to the API for
a locally running cloudigrade server with a local postgresql database. This
makes it a very unscientific performance test, but it's better than nothing
and may give us some initial benchmark ideas.

But first set up some common variables and a clean DB dump for reuse...
"

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

pe "rm -rf $BENCH_DIR && mkdir -p $BENCH_DIR"
reinit_db

screen_break

##############################################

header "Reset the database and generate data roughly on the scale of the pilot
version's jnewton account which on 2019-03-08 saw in the preceding month
22 rhel images having 565 instances with 2405 hours of runtime activity.
We did not track concurrency then, and we must make some guesses here.

By default, spawndata will generate roughly half of the images with RHEL and
half without. So, we use about twice the number of images and instances to
approximate the numbers we saw from the jnewton pilot account.

(1200 instances * ~0.5 rhel * ~2 runs * ~2 hours/run = ~2400 total hours)"

# reload_db  # FIRST TIME NOT NEEDED
pe 'time ./cloudigrade/manage.py spawndata --confirm \
--account_count=1 --image_count=45 --instance_count=1200 \
--mean_run_count=2 --mean_run_hours=2 \
1 "${DATE_30_DAYS_AGO}"'
screen_break

header "Run the benchmarks for this initial jnewton-like data.
Note: the first concurrent usage API request is always slower because
it calculates and saves results for subsequent calls to reuse."
run_all_benchmarks 'jnewton_base'
screen_break

####

header "Reset the database, and generate a greater number of shorter runs.
(1200 instances * ~0.5 rhel * ~4 runs * ~1 hours/run = ~2400 total hours)"
reload_db
pe 'time ./cloudigrade/manage.py spawndata --confirm \
--account_count=1 --image_count=45 --instance_count=1200 \
--mean_run_count=4 --mean_run_hours=1 \
1 "${DATE_30_DAYS_AGO}"'
screen_break

header "Run the benchmarks for this 'more but shorter runs' jnewton-like data."
run_all_benchmarks 'jnewton_more'
screen_break

####

header "Reset the database, and generate a smaller number of longer runs.
(1200 instances * ~0.5 rhel * ~1 runs * ~4 hours/run = ~2400 total hours)"
reload_db
pe 'time ./cloudigrade/manage.py spawndata --confirm \
--account_count=1 --image_count=45 --instance_count=1200 \
--mean_run_count=1 --mean_run_hours=4 \
1 "${DATE_30_DAYS_AGO}"'
screen_break

header "Run the benchmarks for this 'fewer but longer runs' jnewton-like data."
run_all_benchmarks 'jnewton_fewer'
screen_break

######################

header "Reset the database and generate data roughly on the scale of the pilot
version's laska account which on 2019-03-08 saw in the preceding month
70 rhel images having 45108 instances with 40303 hours of runtime activity.
Yes, laska's account activity was *much larger* than jnewton's activity.

Using math similar to the jnewton experiment, laska would have:

(90200 instances * ~0.5 rhel * ~2 runs * ~0.45 hours/run = ~40590 total hours)"
reload_db
pe 'time ./cloudigrade/manage.py spawndata --confirm \
--account_count=1 --image_count=140 --instance_count=90200 \
--mean_run_count=2 --mean_run_hours=0.45 \
1 "${DATE_30_DAYS_AGO}"'

screen_break

header "Run the benchmarks for this initial laska-like data."
run_all_benchmarks 'laska_base'
screen_break

####

header "Reset the database, and generate a greater number of shorter runs.
(90200 instances * ~0.5 rhel * ~4 runs * ~0.225 hours/run = ~40590 total hours)"
reload_db
pe 'time ./cloudigrade/manage.py spawndata --confirm \
--account_count=1 --image_count=140 --instance_count=90200 \
--mean_run_count=4 --mean_run_hours=0.225 \
1 "${DATE_30_DAYS_AGO}"'
screen_break

header "Run the benchmarks for this 'more but shorter runs' laska-like data."
run_all_benchmarks 'laska_more'
screen_break

####

header "Reset the database, and generate a smaller number of longer runs.
(90200 instances * ~0.5 rhel * ~1 runs * ~0.9 hours/run = ~40590 total hours)"
reload_db
pe 'time ./cloudigrade/manage.py spawndata --confirm \
--account_count=1 --image_count=140 --instance_count=90200 \
--mean_run_count=1 --mean_run_hours=0.9 \
1 "${DATE_30_DAYS_AGO}"'
screen_break

header "Run the benchmarks for this 'fewer but longer runs' laska-like data."
run_all_benchmarks 'laska_fewer'
screen_break

##############################################

header "Reset the database and generate data roughly half the scale of the pilot
version's jnewton account so we can have a 'small' reference example.
(600 instances * ~0.5 rhel * ~2 runs * ~2 hours/run = ~1200 total hours)"

reload_db
pe 'time ./cloudigrade/manage.py spawndata --confirm \
--account_count=1 --image_count=45 --instance_count=600 \
--mean_run_count=2 --mean_run_hours=2 \
1 "${DATE_30_DAYS_AGO}"'
screen_break

header "Run the benchmarks for this initial half-jnewton-like data."
run_all_benchmarks 'half_jnewton_base'
screen_break

####

header "Reset the database, and generate a greater number of shorter runs.
(600 instances * ~0.5 rhel * ~4 runs * ~1 hours/run = ~1200 total hours)"
reload_db
pe 'time ./cloudigrade/manage.py spawndata --confirm \
--account_count=1 --image_count=45 --instance_count=600 \
--mean_run_count=4 --mean_run_hours=1 \
1 "${DATE_30_DAYS_AGO}"'
screen_break

header "Run the benchmarks for this 'more but shorter runs' half-jnewton-like data."
run_all_benchmarks 'half_jnewton_more'
screen_break

####

header "Reset the database, and generate a smaller number of longer runs.
(600 instances * ~0.5 rhel * ~1 runs * ~4 hours/run = ~1200 total hours)"
reload_db
pe 'time ./cloudigrade/manage.py spawndata --confirm \
--account_count=1 --image_count=45 --instance_count=600 \
--mean_run_count=1 --mean_run_hours=4 \
1 "${DATE_30_DAYS_AGO}"'
screen_break

header "Run the benchmarks for this 'fewer but longer runs' half-jnewton-like data."
run_all_benchmarks 'half_jnewton_fewer'
screen_break

##############################################

header "Reset the database and generate data roughly half the scale of the pilot
version's laska account so we can have a 'medium-large' reference example.
(45100 instances * ~0.5 rhel * ~2 runs * ~0.45 hours/run = ~20295 total hours)"
reload_db
pe 'time ./cloudigrade/manage.py spawndata --confirm \
--account_count=1 --image_count=140 --instance_count=45100 \
--mean_run_count=2 --mean_run_hours=0.45 \
1 "${DATE_30_DAYS_AGO}"'

screen_break

header "Run the benchmarks for this initial half-laska-like data."
run_all_benchmarks 'half_laska_base'
screen_break

####

header "Reset the database, and generate a greater number of shorter runs.
(45100 instances * ~0.5 rhel * ~4 runs * ~0.225 hours/run = ~20295 total hours)"
reload_db
pe 'time ./cloudigrade/manage.py spawndata --confirm \
--account_count=1 --image_count=140 --instance_count=45100 \
--mean_run_count=4 --mean_run_hours=0.225 \
1 "${DATE_30_DAYS_AGO}"'
screen_break

header "Run the benchmarks for this 'more but shorter runs' half-laska-like data."
run_all_benchmarks 'half_laska_more'
screen_break

####

header "Reset the database, and generate a smaller number of longer runs.
(45100 instances * ~0.5 rhel * ~1 runs * ~0.9 hours/run = ~20295 total hours)"
reload_db
pe 'time ./cloudigrade/manage.py spawndata --confirm \
--account_count=1 --image_count=140 --instance_count=45100 \
--mean_run_count=1 --mean_run_hours=0.9 \
1 "${DATE_30_DAYS_AGO}"'
screen_break

header "Run the benchmarks for this 'fewer but longer runs' half-laska-like data."
run_all_benchmarks 'half_laska_fewer'
screen_break

######################

header "All 'ab' and 'curl' outputs were saved in ${BENCH_DIR} for review."
pe 'ls -lh "${BENCH_DIR}"*.{txt,json}'
screen_break

####

dunzo
