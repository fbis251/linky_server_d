#!/bin/bash
set -x
NAME="link_saver"
DUB_BUILD="time dub build --compiler=ldc2"

clear;
when-changed ./source/*/*.d ./source/*/*/*.d ./source/*.d ./views/*.dt -c "clear; $DUB_BUILD && killall $NAME;"
