#!/usr/bin/env bash
#
# asciinema rec -c THIS_FILE

clear

<<PREREQ
cloudigrade
cd ../shiftigrade/
make oc-clean
make oc-up-all
make oc-forward-ports
PREREQ

export DJANGO_SETTINGS_MODULE=config.settings.local
source "$(which virtualenvwrapper.sh)"
# source ~/projects/personal/demo-magic/demo-magic.sh -d -n
source ~/projects/personal/demo-magic/demo-magic.sh -d -w1


function screenBreak() {
    p
    sleep 2
    clear
}

function dunzo() {
    sleep 1
    echo
    echo "🎉 🏆 🥇"
    echo
    sleep 5
    clear
}


toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'Generate API examples docs'
echo '### https://gitlab.com/cloudigrade/cloudigrade/issues/501'
echo '### https://gitlab.com/cloudigrade/cloudigrade/merge_requests/544'
echo
echo '### Generate API examples in RST documentation automatically so '
echo "### developers don't have to keep updating them manually."

screenBreak
###############

p 'cloudigrade'
source ~/bin/cloudigrade.sh

pe 'rm docs/rest-api-examples.rst'
pe 'make docs-api-examples'
pe 'pygmentize ./docs/rest-api-examples.rst | less -R'
dunzo
