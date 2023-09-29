#!/bin/bash

# Check if this is the primary node or standby node
if [ "$POD_NAME" == "postgresdb-stateful-0" ]; then
    echo "Within primary node *****************"



    # Initialize the database if it's the primary node
    su -l postgres -c "/usr/pgsql-15/bin/initdb"
    su -l postgres -c "/usr/pgsql-15/bin/pg_ctl -D /var/lib/pgsql/15/data -l /tmp/pg_logfile start"

    sleep 5

    # Modify repmgr.conf and start repmgr
    sed -i "s/\$REPMGR_DB_HOST/$REPMGR_DB_HOST/g" /repmgr.conf
   # /repmgr start

    # Create necessary PostgreSQL users and databases
    su -l postgres -c "psql -c 'CREATE USER repmgr WITH PASSWORD '\''repmgr'\'';'"
    su -l postgres -c "psql -c 'CREATE DATABASE repmgrdb;'"
    su -l postgres -c "psql -c 'GRANT ALL PRIVILEGES ON DATABASE repmgrdb TO repmgr;'"
 elif [ "$POD_NAME" == "postgresdb-stateful-1" ]; then
         echo "Within secondary node *****************"
    # Tail the log to keep the container running
    tail -f /dev/null

fi
