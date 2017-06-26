#!/bin/bash

function finish {
    echo "im done here"
}

trap finish EXIT

if [ ! -f "/var/lib/mysql/ibdata1" ]; then
    echo "$(date +%H:%M:%S)  Initializing MySQL system database"
    /usr/bin/mysql_install_db
    echo "$(date +%H:%M:%S)  MySQL system database initialized"
    chown -R mysql:mysql /var/lib/mysql
    chown -R mysql:mysql /var/run/mysqld
fi

if [ ! -d "/var/lib/mysql/slurm_acct_db" ]; then
    /usr/bin/mysqld_safe --datadir='/var/lib/mysql' &

    for i in {30..0}; do
        if echo "SELECT 1" | mysql &> /dev/null; then
            break
        fi
        echo "$(date +%H:%M:%S)  Starting MySQL temporarily"
        sleep 1
    done

    if [ "$i" = 0 ]; then
        echo >&2 "$(date +%H:%M:%S)  MySQL did not start"
        exit 1
    fi

    echo "$(date +%H:%M:%S)  Creating Slurm acct database"
    mysql -NBe "CREATE DATABASE slurm_acct_db"
    mysql -NBe "CREATE USER 'slurm'@'localhost'"
    mysql -NBe "SET PASSWORD for 'slurm'@'localhost' = password('password')"
    mysql -NBe "GRANT USAGE ON *.* to 'slurm'@'localhost'"
    mysql -NBe "GRANT ALL PRIVILEGES on slurm_acct_db.* to 'slurm'@'localhost'"
    mysql -NBe "FLUSH PRIVILEGES"
    echo "Slurm acct database created"
    echo "Stopping MySQL after creating Slurm acct database"
    killall mysqld

    for i in {30..0}; do
        if echo "SELECT 1" | mysql &> /dev/null; then
            sleep 1
        else
            break
        fi
    done
    if [ "$i" = 0 ]; then
        echo >&2 "$(date +%H:%M:%S)  MySQL did not stop"
        exit 1
    fi
fi

chown slurm:slurm /var/spool/slurmd /var/run/slurmd /var/lib/slurmd /var/log/slurm

echo "$(date +%H:%M:%S)  Starting all processes via supervisord"
/usr/bin/supervisord -c /etc/supervisord.conf

exec "$@"
