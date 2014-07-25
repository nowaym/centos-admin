#!/bin/bash

HN=`uname -n`

echo "server {
listen 80;
server_name php-fpm.$HN;
access_log off;
error_log off;

    allow 127.0.0.1;
    allow 1.2.3.4;
    deny all;

" >/tmp/php-fpm.cacti.conf

rm /tmp/list_socket
touch /tmp/list_socket

LLL=`/bin/ls -1 /etc/nginx/vhosts.d | grep -v php-fpm.cacti.conf`;

for FN in $LLL ; do
  SOCK=`grep -m 1 "fastcgi_pass unix:" /etc/nginx/vhosts.d/$FN`
  if [ -n "$SOCK" ]; then
    echo ${FN%.conf} >> /tmp/list_socket
    echo "location = /phpfpm-status/${FN%.conf}  {
       include fastcgi_params;
       fastcgi_split_path_info ^(.*)/(.*)$;
       fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
$SOCK
}
    " >>/tmp/php-fpm.cacti.conf
  fi
done

echo "
location = /phpfpm-list {
  alias /tmp/list_socket;
}
}"  >>/tmp/php-fpm.cacti.conf

touch /etc/nginx/vhosts.d/php-fpm.cacti.conf
DDD=`diff /tmp/php-fpm.cacti.conf /etc/nginx/vhosts.d/php-fpm.cacti.conf`

if [ -n "$DDD" ]; then
  echo "php-fpm.cacti: Nginx config changed, reload"
  cp /tmp/php-fpm.cacti.conf /etc/nginx/vhosts.d/php-fpm.cacti.conf
  /sbin/service nginx reload
fi
