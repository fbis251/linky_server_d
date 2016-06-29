#!/bin/bash
set -x
NAME="link_saver"
DUB_BUILD="time dub build --compiler=ldc"
DEBUG_LEVEL=""

clear;
./bin/$NAME $DEBUG_LEVEL &
when-changed ./source/*/*.d ./source/*/*/*.d ./source/*.d ./views/*.dt -c "clear; $DUB_BUILD && ( killall $NAME; clear; ./bin/$NAME $DEBUG_LEVEL ) &"
