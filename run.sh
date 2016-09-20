#!/bin/bash
set -x
NAME="link_saver"
DUB_BUILD="time dub build"
DEBUG_LEVEL=""

clear;
./bin/$NAME $DEBUG_LEVEL &
when-changed -r ./source ./views -1 -c "clear; $DUB_BUILD && ( killall $NAME; clear; ./bin/$NAME $DEBUG_LEVEL ) &"
