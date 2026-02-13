#!/bin/bash
 
IFS=" "
PIDFILE=/tmp/script.pid
ACCESSLOG=/var/log/nginx/access.log
ERRORLOG=/var/log/nginx/error.log
EMAIL="$USER@localhost"
EMAIL_CLIENT=/usr/sbin/sendmail
COUNT=10
HOURS=1
ACCDATE="`date --date="$HOURS hours ago" +"%d/%b/%Y:%H"`"
ERRDATE="`date --date="$HOURS hours ago" +"%Y/%m/%d %H"`"

send_mail()
{
        (
cat - <<END
Subject: Last $HOURS hours nginx report.

IP:
 ${IP[@]}

URL:
 ${URL[@]}

STATUS:
 ${STATUS[@]}

ERRORS:
${ERRORS[@]}

END
) | $EMAIL_CLIENT $1
}

if [ -e $PIDFILE ]
then
    exit 1
else
        echo "$$" > $PIDFILE
        trap 'rm -f $PIDFILE; exit $?' INT TERM EXIT
        IP+=(`cat $ACCESSLOG | grep "$ACCDATE" | awk '{print $1}' | sort | uniq -c | sort -nr | head -$COUNT`)
        URL+=(`cat $ACCESSLOG | grep "$ACCDATE" | awk '{print $7}' | sort | uniq -c | sort -nr | head -$COUNT`)
        STATUS+=(`cat $ACCESSLOG | grep "$ACCDATE" | awk '{print $9}' | sort | uniq -c | sort -nr`)
        ERRORS+=(`cat $ERRORLOG | grep "$ERRDATE"`)
        if [ -e $EMAIL_CLIENT ]
        then
            send_mail $EMAIL
        fi
        rm -r $PIDFILE
        trap - INT TERM EXIT
fi