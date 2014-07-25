#!/bin/sh

if [ "$1" == "start" ]; then
  /etc/init.d/postfix start
fi


if [ "$1" == "stop" ]; then
  /etc/init.d/postfix stop
  sleep 1
  PIDP=`cat /var/spool/postfix/pid/master.pid`
  ps ax | grep $PIDP | grep "/usr/libexec/postfix/master"
  if [ $? -eq 0 ]; then
    kill -9 $PIDP
  fi
  rm -f /var/spool/postfix/pid/master.pid
  sleep 1
fi
