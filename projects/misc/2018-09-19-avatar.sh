#!/usr/bin/env bash
#
# asciinema rec -c THIS_FILE

clear
source ~/projects/personal/demo-magic/demo-magic.sh -d -n
# source ~/projects/personal/demo-magic/demo-magic.sh -d -w1

TDIR=$(python -c "import tempfile;print(tempfile.TemporaryDirectory().name)")
p 'TDIR=$(python -c "import tempfile;print(tempfile.TemporaryDirectory().name)")'

mkdir -p $TDIR && cd $TDIR || exit
p 'mkdir -p $TDIR && cd $TDIR'

pe 'youtube-dl https://youtu.be/_t0nx1ECgcI'
pe 'for F in *.mp4; do ffmpeg -i "${F}" -vf select="eq(n\,184)" -vsync 0 frame.png; done'
pe 'convert frame.png -crop 60x60+640+180 cropped.png'
pe 'npm install image-to-ascii-cli'
pe './node_modules/.bin/image-to-ascii -i cropped.png'
