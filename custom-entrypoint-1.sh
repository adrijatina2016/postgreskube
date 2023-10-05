#!/bin/bash

# Check if this is the primary node or standby node

arrIN=(${POD_NAME//-/ })

last_part="${arrIN[-1]}"

echo "************** POD IDENTIFICATION ID: $last_part *****************************"

if [ "$last_part" -gt 0 ]; then
        new_node_name=standby
        new_node_id=$last_part
        #node_ip=postgresdb-stateful-1.postgres-headless-svc.default.svc.cluster.local

        result=$(nslookup postgresdb-stateful-0.postgres-headless-svc.default.svc.cluster.local | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
        primary_pod_ip=$(echo "$result" | awk 'END {print}')

        #echo "$primary_pod_ip"
        #echo "$primary_pod_ip"
        echo "Within secondary node *****************"
        #dns_name="postgresdb-stateful-1.postgres-headless-svc.default.svc.cluster.local"
        ip_address=$PEER_POD_IP
        #echo "ip address resolved"
        #echo "$ip_address"
        if [ -n "$ip_address" ]; then
                 echo "The IP address of $dns_name is $ip_address"
        fi
        #echo "Node name replaced *******************"
        su -l postgres -c "cp /repmgr.conf /var/lib/pgsql"
        su -l postgres -c "sed -i "s/^node_name=primary/node_name=$new_node_name/" /var/lib/pgsql/repmgr.conf"
        #echo "Node id replacing ***************************"
        su -l postgres -c "sed -i "s/^node_id=1/node_id=$new_node_id/" /var/lib/pgsql/repmgr.conf"
        #echo "$node_ip"
        su -l postgres -c "sed -i "s/REPMGR_DB_HOST/$ip_address/g" /var/lib/pgsql/repmgr.conf"
        sleep 10
        #echo "Cloning start ******************************"
        su -l postgres -c "/usr/pgsql-15/bin/repmgr -h $primary_pod_ip -U repmgr -f /var/lib/pgsql/repmgr.conf standby clone --dry-run"
        sleep 20
        su -l postgres -c "/usr/pgsql-15/bin/repmgr -h $primary_pod_ip -U repmgr -f /var/lib/pgsql/repmgr.conf standby clone"
        #echo "Cloning done....Now starting the server ********"
        su -l postgres -c "/usr/pgsql-15/bin/pg_ctl -D /var/lib/pgsql/15/data -l /tmp/pg_logfile start"
        #echo "server started**** now registering the server to cluster"
        su -l postgres -c "/usr/pgsql-15/bin/repmgr -f /var/lib/pgsql/repmgr.conf standby register"
    tail -f /dev/null


else
         echo "Within primary node *****************"

        su -l postgres -c "/usr/pgsql-15/bin/initdb"
        su -l postgres -c "mv  /var/lib/pgsql/15/data/postgresql.conf /var/lib/pgsql/15/data/postgresql.conf.bkp"
        su -l postgres -c "cp /postgresql.conf /var/lib/pgsql/15/data/postgresql.conf"
        su -l postgres -c "mv  /var/lib/pgsql/15/data/pg_hba.conf /var/lib/pgsql/15/data/pg_hba.conf.bkp"
        su -l postgres -c "cp /pg_hba.conf /var/lib/pgsql/15/data/pg_hba.conf"
        su -l postgres -c "cp /repmgr.conf /var/lib/pgsql"
        ip_address=$PEER_POD_IP
        su -l postgres -c "sed -i "s/REPMGR_DB_HOST/$ip_address/g" /var/lib/pgsql/repmgr.conf"
        su -l postgres -c "/usr/pgsql-15/bin/pg_ctl -D /var/lib/pgsql/15/data -l /tmp/pg_logfile start"

        sleep 5

        su -l postgres -c "createuser -s repmgr"
        su -l postgres -c "createdb repmgr -O repmgr"

        su -l postgres -c "/usr/pgsql-15/bin/repmgr -f /var/lib/pgsql/repmgr.conf primary register"
        tail -f /dev/null
fi

