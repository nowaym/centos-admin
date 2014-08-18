## ReadMe for scripts v. 1.0 ##

1. admin.sh

use ./admin.sh <create|remove> <fqdn> [ip]

Создает площадку под сайт по шаблону. То есть конфиги nginx apache, делает релоад сервисов и создает БД mysql и/или postgresql. В зависимости от наличия файла /root/.mysql /root/.postgresql.
Так же создает FTP аккаунт на базе pure-ftpdю
Информацию по доступам выводит в STDOUT.

use ./admin.sh <createdb> <mysql|postgresql> <dbname>

Создает БД. Информацию по доступам выводит в STDOUT.

use ./admin.sh <change_root_pass> <mysql|postgresql>

Меняет пароль суперпользователя.

2.  apache-top.py
    apachetop.sh

Скрипт показывающий запросы apache в реальном времени.
настройки nginx:
    location /apache-status {                                                                                                                                                                                
        roxy_pass http://127.0.0.1:8080;                                                                                                                                                                            
	proxy_redirect off;                                                                                                                                                                                          
	proxy_set_header Host $host;                                                                                                                                                                                 
	proxy_set_header X-Real-IP $remote_addr;                                                                                                                                                                     
	proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;                                                                                                                                                 
                                                                                                                                                                                                             
	proxy_read_timeout 300;                                                                                                                                                                                      
	client_max_body_size 256m;                                                                                                                                                                                   
                                                                                                                                                                                                             
	proxy_buffer_size 16k;                                                                                                                                                                                       
	proxy_buffers 32 16k;  
    }  
настройки apache:
    ServerName localhost                                                                                                                                                                                     
                                                                                                                                                                                                             
    <Location /apache-status>                                                                                                                                                                                
        SetHandler server-status                                                                                                                                                                             
    </Location>   


3. cacti-php-fpm.sh

Скрипт настройки web сервисов для монитронга php-fpm в cacti

4. highload-report.sh

Скрипт собирающий полную информацию о системе в конкретный момент времени и отсылающий информацию на почту:
*) список процессов , сортировка по CPU
*) список процессов , сортировка по MEM
*) список запросов mysql
*) список запросов apache
*) список запросов nginx
*) список конектов netstat с сортировкой по ip
*) всего TCP/UDP сессий
*) mysql status

Скрипт запускает monit при la > X

5. httpd-restart.sh

Просто рестарт apache, нужен для monit

6. maldet.sh

Скрипт для проверки сайтов на наличие вирусов, использует maldet

7. mongodb-backup.sh

Скрипт бэкапа mongoDB. Сделан на основе mysql-backup.sh

8. mysql-backup.sh

Бэкап mysql. Подробное описание в статье: http://habrahabr.ru/company/centosadmin/blog/227533/

9. mysql-slave-check.sh

Скрипт проверки состояние mysql slave с уведомлением.

10. mysql-table-check.sh

Скрипт проверки таблиц

11. php-cron.sh

Скрипт для добавления php cron задач

12. postfix.sh

Остановка / запуск postfix, нужно для monit.

13. postgresql-backup.sh

Скрипт бэкапа postgresql. Работает аналогично mysql-backup.sh за исключением характерных особенностей.

14. redis-backup.sh

Скрипт бэкапа redis. Работает аналогично mysql-backup.sh за исключением характерных особенностей.

15. redis-ping.sh

Скрипт проверки redis.

16. rstr-xtra-mysql.sh

Скрипт восстановления xtrabackup

17. 	unicornstat.pl
	unicornstat.sh

Скрипт для получении статистики по работе unicorn

18. vz-exec.pl

управление контейнерами openvz через ssh


