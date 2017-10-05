#!/bin/bash

HOSTS_ALLOW=/etc/ufw-dynamic-hosts.allow
HOSTS_DISALLOW=/etc/ufw-dynamic-hosts.disallow
IPS_BLOCKED=/etc/ufw-dynamic-hosts.blocked
IPS_UNBLOCKED=/etc/ufw-dynamic-hosts.unblocked
IPS_ALLOW=/var/tmp/ufw-dynamic-ips.allow
IP_HOLDER=/var/tmp/ufw-dynamic-holder.allow

touch $HOSTS_ALLOW
touch $HOSTS_DISALLOW
touch $IPS_BLOCKED
touch $IPS_UNBLOCKED

add_rule() {
  local proto=$1
  local port=$2
  local ip=$3
  local regex="${port}\/${proto}.*ALLOW.*IN.*${ip}"
  local rule=$(/usr/sbin/ufw status numbered | grep $regex)
  if [ -z "$rule" ]; then
      /usr/sbin/ufw insert 1 allow proto ${proto} from ${ip} to any port ${port}
  else
      echo "rule already exists. nothing to do."
  fi
}

delete_rule() {
  local proto=$1
  local port=$2
  local ip=$3
  local regex="${port}\/${proto}.*ALLOW.*IN.*${ip}"
  local rule=$(/usr/sbin/ufw status numbered | grep $regex)
  if [ -n "$rule" ]; then
      /usr/sbin/ufw delete allow proto ${proto} from ${ip} to any port ${port}
  else
      echo "rule does not exist. nothing to do."
  fi
}

add_block() {
  local proto=$1
  local port=$2
  local ip=$3
  local regex="${port}\/${proto}.*ALLOW.*IN.*${ip}"
  local rule=$(/usr/sbin/ufw status numbered | grep $regex)
  if [ -z "$rule" ]; then
      /usr/sbin/ufw deny proto ${proto} from ${ip} to any port ${port}
  else
      echo "rule already exists. nothing to do."
  fi
}

delete_block() {
  local proto=$1
  local port=$2
  local ip=$3
  local regex="${port}\/${proto}.*ALLOW.*IN.*${ip}"
  local rule=$(/usr/sbin/ufw status numbered | grep $regex)
  if [ -n "$rule" ]; then
      /usr/sbin/ufw delete deny proto ${proto} from ${ip} to any port ${port}
  else
      echo "rule does not exist. nothing to do."
  fi
}

#allow
sed '/^[[:space:]]*$/d' ${HOSTS_ALLOW} | sed '/^[[:space:]]*#/d' | while read line
do
    proto=$(echo ${line} | cut -d: -f1)
    port=$(echo ${line} | cut -d: -f2)
    host=$(echo ${line} | cut -d: -f3)
    dnsserver=$(echo ${line} | cut -d: -f4)
        
    dig +short @$dnsserver $host > $IP_HOLDER
    while IFS='' read -r ip || [[ -n "$ip" ]]; do
        add_rule $proto $port $ip        
    done < "$IP_HOLDER"
done

sed '/^[[:space:]]*$/d' ${HOSTS_DISALLOW} | sed '/^[[:space:]]*#/d' | while read line
do
    proto=$(echo ${line} | cut -d: -f1)
    port=$(echo ${line} | cut -d: -f2)
    host=$(echo ${line} | cut -d: -f3)
    dnsserver=$(echo ${line} | cut -d: -f4)
    
    dig +short @$dnsserver $host > $IP_HOLDER
    while IFS='' read -r ip || [[ -n "$ip" ]]; do
        delete_rule $proto $port $ip        
    done < "$IP_HOLDER"
done


#deny
sed '/^[[:space:]]*$/d' ${IPS_BLOCKED} | sed '/^[[:space:]]*#/d' | while read line
do
    proto=$(echo ${line} | cut -d: -f1)
    port=$(echo ${line} | cut -d: -f2)
    ip=$(echo ${line} | cut -d: -f3)
        
    add_block $proto $port $ip        
done

sed '/^[[:space:]]*$/d' ${IPS_UNBLOCKED} | sed '/^[[:space:]]*#/d' | while read line
do
    proto=$(echo ${line} | cut -d: -f1)
    port=$(echo ${line} | cut -d: -f2)
    ip=$(echo ${line} | cut -d: -f3)
    
    
    delete_block $proto $port $ip        
done