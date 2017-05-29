#!/bin/bash
BLACKBOX_BASEDIR=/root/neurones/monitoring/prometheus/blackbox
MYSQL_BASEDIR=/root/neurones/monitoring/prometheus/mysql
RULES_BASEDIR=/root/neurones/monitoring/prometheus/alerts
export CHANGES=0

for service in $(docker service ls --format --format='{{.Name}}' --filter label=service-type=mysql-db|cut -d'=' -f2);
do

cp -f ${BLACKBOX_BASEDIR}/${service}.yml ${BLACKBOX_BASEDIR}/${service}.yml.old
cat <<EOF > ${BLACKBOX_BASEDIR}/${service}.yml
- targets: ['$service:3306']
  labels:
    job: 'blackbox_$service'
EOF
diff ${BLACKBOX_BASEDIR}/${service}.yml ${BLACKBOX_BASEDIR}/${service}.yml.old >/dev/null 2>&1 || export CHANGES=1

ALERT_NAME="$(echo $service|tr "-" "_")_status"
cp -f ${RULES_BASEDIR}/${ALERT_NAME}.rules ${RULES_BASEDIR}/${ALERT_NAME}.rules.old
cat <<EOF > ${RULES_BASEDIR}/${ALERT_NAME}.rules
ALERT $ALERT_NAME
IF probe_success{instance="$service:3306",job="blackbox_$service"} == 0
FOR 1m
EOF
diff ${RULES_BASEDIR}/${ALERT_NAME}.rules ${RULES_BASEDIR}/${ALERT_NAME}.rules.old >/dev/null 2>&1 || export CHANGES=1

ALERT_NAME="$(echo $service|tr "-" "_")_replication_delay"
cp -f ${RULES_BASEDIR}/${ALERT_NAME}.rules ${RULES_BASEDIR}/${ALERT_NAME}.rules.old
cat <<EOF > ${RULES_BASEDIR}/${ALERT_NAME}.rules
ALERT $ALERT_NAME
IF mysql_global_variables_innodb_replication_delay{instance="${service}-monitoring:9104",job="${service}-monitoring"} != 0
FOR 1m
EOF
diff ${RULES_BASEDIR}/${ALERT_NAME}.rules ${RULES_BASEDIR}/${ALERT_NAME}.rules.old >/dev/null 2>&1 || export CHANGES=1

[[ $(echo "${service}"|grep "\-slave$") ]] && {
ALERT_NAME="$(echo $service|tr "-" "_")_sql_running"
cp -f ${RULES_BASEDIR}/${ALERT_NAME}.rules ${RULES_BASEDIR}/${ALERT_NAME}.rules.old
cat <<EOF > ${RULES_BASEDIR}/${ALERT_NAME}.rules
ALERT $ALERT_NAME
IF mysql_slave_status_slave_sql_running{instance="${service}-monitoring:9104",job="${service}"} != 1
FOR 1m
EOF
diff ${RULES_BASEDIR}/${ALERT_NAME}.rules ${RULES_BASEDIR}/${ALERT_NAME}.rules.old >/dev/null 2>&1 || export CHANGES=1

ALERT_NAME="$(echo $service|tr "-" "_")_io_running"
cp -f ${RULES_BASEDIR}/${ALERT_NAME}.rules ${RULES_BASEDIR}/${ALERT_NAME}.rules.old
cat <<EOF > ${RULES_BASEDIR}/${ALERT_NAME}.rules
ALERT $ALERT_NAME
IF mysql_slave_status_slave_io_running{instance="${service}-monitoring:9104",job="${service}"} != 1
FOR 1m
EOF
diff ${RULES_BASEDIR}/${ALERT_NAME}.rules ${RULES_BASEDIR}/${ALERT_NAME}.rules.old >/dev/null 2>&1 || export CHANGES=1

ALERT_NAME="$(echo $service|tr "-" "_")_running"
cp -f ${RULES_BASEDIR}/${ALERT_NAME}.rules ${RULES_BASEDIR}/${ALERT_NAME}.rules.old
cat <<EOF > ${RULES_BASEDIR}/${ALERT_NAME}.rules
ALERT $ALERT_NAME
IF mysql_global_status_slave_running{instance="${service}-monitoring:9104",job="${service}"} != 1
FOR 1m
EOF
diff ${RULES_BASEDIR}/${ALERT_NAME}.rules ${RULES_BASEDIR}/${ALERT_NAME}.rules.old >/dev/null 2>&1 || export CHANGES=1

}

ALERT_NAME="$(echo $service|tr "-" "_")_backup_status"
cp -f ${RULES_BASEDIR}/${ALERT_NAME}.rules ${RULES_BASEDIR}/${ALERT_NAME}.rules.old
cat <<EOF > ${RULES_BASEDIR}/${ALERT_NAME}.rules
ALERT $ALERT_NAME
IF mysql_backup_status{service="${service}-backup"} != 0
FOR 1m
EOF
diff ${RULES_BASEDIR}/${ALERT_NAME}.rules ${RULES_BASEDIR}/${ALERT_NAME}.rules.old >/dev/null 2>&1 || export CHANGES=1

cp -f ${MYSQL_BASEDIR}/${service}.yml ${MYSQL_BASEDIR}/${service}.yml.old
cat <<EOF > ${MYSQL_BASEDIR}/${service}.yml
- targets: ['${service}-monitoring:9104']
  labels:
    job: '${service}'
EOF
diff ${MYSQL_BASEDIR}/${service}.yml ${MYSQL_BASEDIR}/${service}.yml.old >/dev/null 2>&1 || export CHANGES=1


done

[[ "$CHANGES" == "1" ]] && docker service update monitoring_prometheus --force