#!/bin/bash
NAME=bin/link_saver

dub build -b release --compiler=ldc2 || exit 1
strip $NAME || exit 2
tar czvf saver.tgz $NAME public || exit 3

