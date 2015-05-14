#!/bin/bash
#nc -dl 5001 | mplayer -fps 31 -cache 1024 - 
# ssh pi@$1 "raspivid -t 999999 -o -" | mplayer -fps 30 -cache 1024 -
ssh pi@$1 "raspivid -w 1296 -h 972 -t 999999 -o -" | mplayer -fps 30 -cache 1024 -
#ssh pi@192.168.2.146 'raspivid -w 1296 -h 972 -t 999999 -o - | nc 192.168.2.31 5001'
#ssh pi@$1 "raspivid -w 1296 -h 972 -t 999999 -o -" | mplayer -fps 30 -cache 1024 -
# ssh pi@$1 "raspivid -w 640 -h 480 -t 999999 -o -" | mplayer -fps 30 -cache 1024 -
# ssh pi@$1 "raspivid -rot 180 -t 999999 ${*:2} -o -" | mplayer -fps 30 -cache 1024 -

