#!/bin/bash

# Check if this is the primary node or standby node

if [ "$POD_NAME" == "postgresdb-stateful-0" ]; then
    echo "Within primary node *****************"



    # Initialize the database if it's the primary node
    su -l postgres -c "/usr/pgsql-15/bin/initdb"
    su -l postgres -c "/usr/pgsql-15/bin/pg_ctl -D /var/lib/pgsql/15/data -l /tmp/pg_logfile start"

    #Modify pg_hba.conf file

      PG_HBA_CONF_CONTENTS=$(cat <<EOF
       # TYPE  DATABASE        USER            ADDRESS                 METHOD
       # "local" is for Unix domain socket connections only
       local   all             all                                     peer
       # IPv4 local connections:
       host    all             all             127.0.0.1/32            scram-sha-256
       # IPv6 local connections:
       host    all             all             ::1/128                 scram-sha-256
       # Allow replication connections from localhost, by a user with the
       # replication privilege.
       local   replication     all                                     peer
       host    replication     all             127.0.0.1/32            scram-sha-256
       host    replication     all             ::1/128                 scram-sha-256
       host    replication     repmgr          0.0.0.0/0               trust
       #repmgr
       local   repmgr          repmgr                                  trust
       host    repmgr          repmgr          127.0.0.1/32            trust
       host    repmgr          repmgr          0.0.0.0/0               trust
EOF
)


# Write the contents to pg_hba.conf
echo "$PG_HBA_CONF_CONTENTS" > /var/lib/pgsql/15/data/pg_hba.conf

#Modify postgresql.conf file

     POSTGRE_SQL_CONF_CONTENTS=$(cat <<EOF
     max_wal_senders = 10
     max_replication_slots = 10
     wal_level = replica
     hot_standby = on
     archive_command = '/bin/true'
     listen_address = '*'
     shared_preload_libraries = 'repmgr'
     wal_log_hints = on
EOF
)
# Write the contents to postgresql.conf
echo "$POSTGRE_SQL_CONF_CONTENTS" > /var/lib/pgsql/15/data/postgresql.conf

    sleep 5

    # Modify repmgr.conf and start repmgr
    #sed -i "s/\$REPMGR_DB_HOST/$REPMGR_DB_HOST/g" /repmgr.conf
   # /repmgr start

    # Create necessary PostgreSQL users and databases
    su -l postgres -c "psql -c 'CREATE USER repmgr WITH PASSWORD '\''repmgr'\'';'"
    su -l postgres -c "psql -c 'CREATE DATABASE repmgrdb;'"
    su -l postgres -c "psql -c 'GRANT ALL PRIVILEGES ON DATABASE repmgrdb TO repmgr;'"
    ip_address=$PEER_POD_IP
    sed -i "s/REPMGR_DB_HOST/$ip_address/g" /repmgr.conf
    tail -f /dev/null
 elif [ "$POD_NAME" == "postgresdb-stateful-1" ]; then
         new_node_name=standby
         new_node_id=2
         node_ip=postgresdb-stateful-1.postgres-headless-svc.default.svc.cluster.local
         #primary_pod_ip=nslookup postgresdb-stateful-0.postgres-headless-svc.default.svc.cluster.local
         result=$(nslookup postgresdb-stateful-0.postgres-headless-svc.default.svc.cluster.local | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
         primary_pod_ip=$(echo "$result" | awk 'END {print}')

         #echo "$primary_pod_ip"
         echo "$primary_pod_ip"
         echo "Within secondary node *****************"
         #dns_name="postgresdb-stateful-1.postgres-headless-svc.default.svc.cluster.local"
         ip_address=$PEER_POD_IP
         echo "ip address resolved"
         echo "$ip_address"
         if [ -n "$ip_address" ]; then
                 echo "The IP address of $dns_name is $ip_address"
         fi
         echo "Node name replaced *******************"
         sed -i "s/^node_name=primary/node_name=$new_node_name/" /repmgr.conf
         echo "Node id replacing ***************************"
         sed -i "s/^node_id=1/node_id=$new_node_id/" /repmgr.conf
         echo "$node_ip"
         sed -i "s/REPMGR_DB_HOST/$ip_address/g" /repmgr.conf

         echo "Cloning start ******************************"
         su -l postgres -c "/usr/pgsql-15/bin/repmgr -h postgresdb-stateful-0.postgres-headless-svc.default.svc.cluster.local -U repmgr -f /repmgr.conf standby clone"
         su -l postgres -c "/usr/pgsql-15/bin/pg_ctl -D /var/lib/pgsql/15/data -l /tmp/pg_logfile start"
    # Tail the log to keep the container running
    tail -f /dev/null

fi
