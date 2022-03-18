#!/bin/sh
box=$1
echo $box
owner=`stat -f "%u" $box`
group=`stat -f "%g" $box`
mode=`stat -f "%p" $box | sed 's/..//'`
tail -22480b $box > $box.truncate.tmp

ed $box.truncate.tmp << EOF
/^From .* Apr 17 ..:..:.. 2006$
1,.-1d
.
w
q
EOF

#touch -r $box $box.truncate.tmp
install -p -o $owner -g $group -m $mode $box.truncate.tmp $box
rm -f $box.truncate.tmp
