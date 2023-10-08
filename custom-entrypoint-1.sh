#!/bin/bash

# Check if this is the primary node or standby node

arrIN=(${POD_NAME//-/ })

last_part="${arrIN[-1]}"

echo "************** POD IDENTIFICATION ID: $last_part *****************************"

if [ "$last_part" -gt 0 ]; then
    if [[ $last_part =~ ^[0-9]+$ ]]; then
    new_node_name="standby-$last_part"
    new_node_id=$((last_part + 1))

    su -l postgres -c "cp /repmgr.conf /var/lib/pgsql"
    su -l postgres -c "sed -i "s/^node_name=primary/node_name=$new_node_name/" /var/lib/pgsql/repmgr.conf"
    su -l postgres -c "sed -i "s/^node_id=1/node_id=$new_node_id/" /var/lib/pgsql/repmgr.conf"
    su -l postgres -c "sed -i "s/REPMGR_DB_HOST/$PEER_POD_IP/g" /var/lib/pgsql/repmgr.conf"

    upstream="postgresdb-stateful-$((last_part - 1)).postgres-headless-svc.default.svc.cluster.local"
    echo "the upstream url ==> $upstream"
    result=$(nslookup "$upstream" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')

    echo "the result for nslookup $result"
    upstream_pod_ip=$(echo "$result" | awk 'END {print}')
    echo "he upstream pod ip ==> $upstream_pod_ip"
    sleep 10
    su -l postgres -c "/usr/pgsql-15/bin/repmgr -h $upstream_pod_ip -U repmgr -f /var/lib/pgsql/repmgr.conf standby clone --dry-run" &
    bg_command_pid=$!
    #echo "And the wait begins*******************"
    wait $bg_command_pid
    echo "The wait ends **************************"

    su -l postgres -c "/usr/pgsql-15/bin/repmgr -h $upstream_pod_ip -U repmgr -f /var/lib/pgsql/repmgr.conf standby clone" &
    clone_command_pid=$!

    wait $clone_command_pid

    su -l postgres -c "/usr/pgsql-15/bin/pg_ctl -D /var/lib/pgsql/15/data -l /tmp/pg_logfile start"

    su -l postgres -c "/usr/pgsql-15/bin/repmgr -f /var/lib/pgsql/repmgr.conf standby register"


    tail -f /dev/null
fi



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
