#!/bin/bash
su -l postgres -c /usr/pgsql-15/bin/initdb
su -l postgres -c "/usr/pgsql-15/bin/pg_ctl -D /var/lib/pgsql/15/data -l /tmp/pg_logfile start"

sleep 5

# Create a PostgreSQL user and database
su -l postgres -c "psql -c 'CREATE USER repmgr WITH PASSWORD '\''repmgr'\'';'"
su -l postgres -c "psql -c 'CREATE DATABASE repmgrdb;'"
su -l postgres -c "psql -c 'GRANT ALL PRIVILEGES ON DATABASE repmgrdb TO repmgr;'"


tail -f /dev/null
