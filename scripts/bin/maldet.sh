#!/bin/bash

# clear quarantine/session/tmp data every 14 days
/usr/sbin/tmpwatch 336 /usr/local/maldetect/tmp >> /dev/null 2>&1
/usr/sbin/tmpwatch 336 /usr/local/maldetect/sess >> /dev/null 2>&1
/usr/sbin/tmpwatch 336 /usr/local/maldetect/quarantine >> /dev/null 2>&1
/usr/sbin/tmpwatch 336 /usr/local/maldetect/pub/*/ >> /dev/null 2>&1

# check for new release version
#/usr/local/maldetect/maldet -d >> /dev/null 2>&1

# check for new definition set
/usr/local/maldetect/maldet -u >> /dev/null 2>&1

# if were running inotify monitoring, send daily hit summary
if [ "$(ps -A --user root -o "comm" | grep inotifywait)" ]; then
        /usr/local/maldetect/maldet --alert-daily >> /dev/null 2>&1
else
	# scan default apache docroot paths
	if [ -d "/var/www/html" ]; then
		/usr/local/maldetect/maldet -b -r /var/www/html 2 >> /dev/null 2>&1
	fi
	# scan default apache docroot paths
	if [ -d "/srv/www" ]; then
		/usr/local/maldetect/maldet -b -r /srv/www/?/htdocs 2 >> /dev/null 2>&1
	fi
fi
