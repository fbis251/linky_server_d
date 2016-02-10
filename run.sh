#!/bin/bash
set -x
NAME="link_saver"
#DEBUG="--vv"
DEBUG="--verbose"

clear;
./"$NAME" "$DEBUG" &
when-changed ./source/*.d ./views/*.dt -c "killall $NAME; clear; dub build && ./$NAME $DEBUG &"

# ./"$NAME" &
# when-changed ./source/*.d ./views/*.dt -c "killall $NAME; clear; dub build && ./$NAME &"
