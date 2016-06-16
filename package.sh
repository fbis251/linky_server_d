#!/bin/bash
NAME=link_saver

dub build -b release --compiler=ldc2 || exit 1
strip $NAME || exit 2
tar czvf saver.tgz $NAME public || exit 3

