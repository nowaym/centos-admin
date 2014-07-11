#!/bin/sh

PATH="/sbin:/usr/sbin:/usr/local/sbin:/bin:/usr/bin:/usr/local/bin"

RRUN=`ps ax | grep highload-report.sh | grep -v grep | wc -l`
RRUN=0$RRUN
if [ $RRUN -gt 2 ]; then
  echo "Highload Report alredy running"
  exit
fi

STAMP=`date +%H%M%S`
FLAGD=`date +%s`
REPORT=""


if [ -f /tmp/highload-report.flag ]; then
  FLAGL=`cat /tmp/highload-report.flag | head -1`
  CNTL=`cat /tmp/highload-report.flag | tail -1`
  DELTA=$((FLAGD-FLAGL))
  if [ $DELTA -gt 280 -a $CNTL -eq 1 ]; then
    echo $FLAGD > /tmp/highload-report.flag
    echo 5 >> /tmp/highload-report.flag
    REPORT="5"
    DELTA=0
  fi
  if [ $DELTA -gt 280 -a $CNTL -ne 10 ]; then
    echo $FLAGD > /tmp/highload-report.flag
    echo 10 >> /tmp/highload-report.flag
    REPORT="10"
    DELTA=0
  fi
  if [ $DELTA -gt 1180 ]; then
    echo $FLAGD > /tmp/highload-report.flag
    echo 1 >> /tmp/highload-report.flag
    REPORT="100"
  fi
else
  echo $FLAGD > /tmp/highload-report.flag
  echo 1 >> /tmp/highload-report.flag
  REPORT="1"
fi

echo "<html><body>" >> /tmp/$STAMP.tmp
echo "<h3>load average</h3>" >> /tmp/$STAMP.tmp
echo "<p><pre>" >> /tmp/$STAMP.tmp
echo >> /tmp/$STAMP.tmp
top -b | head -5 >> /tmp/$STAMP.tmp 2>&1
echo >> /tmp/$STAMP.tmp
echo "</pre></p>" >> /tmp/$STAMP.tmp

if [ -f "/root/.mysql" ]; then
    echo "<h3>mysql processes</h3>" >> /tmp/$STAMP.tmp
    echo "<p><pre>" >> /tmp/$STAMP.tmp
    echo >> /tmp/$STAMP.tmp
    mysql -u root -p`cat /root/.mysql` -e "SHOW FULL PROCESSLIST" | sort -n -k 6 >> /tmp/$STAMP.tmp 2>&1
    echo >> /tmp/$STAMP.tmp
    echo "</pre></p>" >> /tmp/$STAMP.tmp
fi

if [ -f "/root/.postgresql" ]; then
    echo "<h3>postgresql processes</h3>" >> /tmp/$STAMP.tmp
    echo "<p><pre>" >> /tmp/$STAMP.tmp
    echo >> /tmp/$STAMP.tmp

    if [ -f "/etc/init.d/pgbouncer" ]; then
        PORT="5454"
    else
        PORT="5432"
    fi

    echo "SELECT datname,procpid,current_query FROM pg_stat_activity;" | psql -U postgres --port=$PORT >> /tmp/$STAMP.tmp 2>&1
    echo >> /tmp/$STAMP.tmp
    echo "</pre></p>" >> /tmp/$STAMP.tmp
fi

echo "<h3>memory process list (top100)</h3>" >> /tmp/$STAMP.tmp
echo "<p><pre>" >> /tmp/$STAMP.tmp
echo >> /tmp/$STAMP.tmp
#ps -ewwwo size,command --sort -size | head -100 | awk '{ hr=$1/1024 ; printf("%13.2f Mb ",hr) } { for ( x=2 ; x<=NF ; x++ ) { printf("%s ",$x) } print "" }' >> /tmp/$STAMP.tmp 2>&1
ps -ewwwo pid,size,command --sort -size | head -100 | awk '{ pid=$1 ; printf("%7s ", pid) }{ hr=$2/1024 ; printf("%8.2f Mb ", hr) } { for ( x=3 ; x<=NF ; x++ ) { printf("%s ",$x) } print "" }' >> /tmp/$STAMP.tmp 2>&1
echo >> /tmp/$STAMP.tmp
echo "</pre></p>" >> /tmp/$STAMP.tmp

echo "<h3>process list (sort by cpu)</h3>" >> /tmp/$STAMP.tmp
echo "<p><pre>" >> /tmp/$STAMP.tmp
echo >> /tmp/$STAMP.tmp
ps -ewwwo pcpu,pid,user,command --sort -pcpu >> /tmp/$STAMP.tmp 2>&1
echo >> /tmp/$STAMP.tmp
echo "</pre></p>" >> /tmp/$STAMP.tmp

LINKSVER=`links -version | grep "2.2" | wc -l`
if [ $LINKSVER -gt 0 ]; then
    echo "<h3>apache</h3>" >> /tmp/$STAMP.tmp
    echo "<p><pre>" >> /tmp/$STAMP.tmp
    echo >> /tmp/$STAMP.tmp
    links -dump -retries 1 -receive-timeout 30 http://localhost:8080/apache-status | grep -v "OPTIONS \* HTTP/1.0" >> /tmp/$STAMP.tmp 2>&1
    echo >> /tmp/$STAMP.tmp
    echo "</pre></p>" >> /tmp/$STAMP.tmp

    echo "<h3>nginx</h3>" >> /tmp/$STAMP.tmp
    echo "<p><pre>" >> /tmp/$STAMP.tmp
    echo >> /tmp/$STAMP.tmp
    links -dump -retries 1 -receive-timeout 30 http://localhost/nginx-status >> /tmp/$STAMP.tmp 2>&1
    echo >> /tmp/$STAMP.tmp
    echo "<p><pre>" >> /tmp/$STAMP.tmp
else
    echo "<h3>apache</h3>" >> /tmp/$STAMP.tmp
    echo "<p><pre>" >> /tmp/$STAMP.tmp
    echo >> /tmp/$STAMP.tmp
    links -dump -eval 'set connection.retries = 1' -eval 'set connection.receive_timeout = 30' http://localhost:8080/apache-status >> /tmp/$STAMP.tmp 2>&1
    echo >> /tmp/$STAMP.tmp
    echo "</pre></p>" >> /tmp/$STAMP.tmp

    echo "<h3>nginx</h3>" >> /tmp/$STAMP.tmp
    echo "<p><pre>" >> /tmp/$STAMP.tmp
    echo >> /tmp/$STAMP.tmp
    links -dump -eval 'set connection.retries = 1' -eval 'set connection.receive_timeout = 30' http://localhost/nginx-status >> /tmp/$STAMP.tmp 2>&1
    echo >> /tmp/$STAMP.tmp
    echo "</pre></p>" >> /tmp/$STAMP.tmp
fi

echo "<h3>connections report</h3>" >> /tmp/$STAMP.tmp
echo "<p><pre>" >> /tmp/$STAMP.tmp
echo >> /tmp/$STAMP.tmp
netstat -plan | grep :80 | awk {'print $5'} | cut -d: -f 1 | sort | uniq -c | sort -n >> /tmp/$STAMP.tmp 2>&1
echo >> /tmp/$STAMP.tmp
echo "</pre></p>" >> /tmp/$STAMP.tmp

echo "<h3>syn tcp/udp session</h3>" >> /tmp/$STAMP.tmp
echo "<p><pre>" >> /tmp/$STAMP.tmp
echo >> /tmp/$STAMP.tmp
netstat -n | egrep '(tcp|udp)' | grep SYN | wc -l >> /tmp/$STAMP.tmp 2>&1
echo >> /tmp/$STAMP.tmp
echo "</pre></p>" >> /tmp/$STAMP.tmp

if [ -f "/root/.mysql" ]; then
    echo "<h3>mysql status</h3>" >> /tmp/$STAMP.tmp
    echo "<p><pre>" >> /tmp/$STAMP.tmp
    echo >> /tmp/$STAMP.tmp
    mysql -u root -p`cat /root/.mysql` -e "SHOW STATUS where value !=0" >> /tmp/$STAMP.tmp 2>&1
    echo >> /tmp/$STAMP.tmp
    echo "</pre></p>" >> /tmp/$STAMP.tmp
fi

SUBJECT="`hostname` HighLoad report"

echo "</body></html>" >> /tmp/$STAMP.tmp

if [ -n "$REPORT" ]; then
cat - /tmp/$STAMP.tmp <<EOF | sendmail -oi -t
To: root
Subject: $SUBJECT
Content-Type: text/html; charset=utf8
Content-Transfer-Encoding: 8bit
MIME-Version: 1.0

EOF

fi

rm /tmp/$STAMP.tmp

if [ "$1" = "apache-start" ]; then
    sems=$(ipcs -s | grep apache | awk --source '/0x0*.*[0-9]* .*/ {print $2}')
    for sem in $sems
    do
      ipcrm sem $sem
    done
    /etc/init.d/httpd start
fi

if [ "$1" = "apache-stop" ]; then
    killall -9 httpd
fi

if [ "$1" = "force-restart" ]; then
    killall -9 httpd
    sleep 2
    sems=$(ipcs -s | grep apache | awk --source '/0x0*.*[0-9]* .*/ {print $2}')
    for sem in $sems
    do
      ipcrm sem $sem
    done
    /etc/init.d/httpd start
fi

exit 1
