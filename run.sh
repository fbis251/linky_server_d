#!/bin/bash

NAME=link_saver

while true ;
do
    clear
    dub build
    if [ "$?" == "0" ] ; then
        clear
        ./$NAME &
    fi
    inotifywait -e modify ./source/*.d ./views/*.dt
    killall $NAME
done
