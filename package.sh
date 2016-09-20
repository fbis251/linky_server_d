#!/bin/bash
NAME=bin/link_saver

set -x

dub build -b release || exit 1
strip $NAME || exit 2
tar czvf saver.tgz $NAME public || exit 3
