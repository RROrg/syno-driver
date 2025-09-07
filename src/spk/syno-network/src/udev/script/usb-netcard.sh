#!/bin/sh
#
# Copyright (C) 2022 Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

ACTION=$([ "${1}" = "add" ] && echo "start" || echo "stop")
NAME=${2}

createifcfg() {
  ETHX=${1}
  if [ -n "$(cat /usr/syno/etc/synoovs/ovs_reg.conf 2>/dev/null)" ]; then
    grep -q ${ETHX} /usr/syno/etc/synoovs/ovs_ignore.conf 2>/dev/null && sed -i "/${ETHX}/d" /usr/syno/etc/synoovs/ovs_ignore.conf
    grep -q ${ETHX} /usr/syno/etc/synoovs/ovs_interface.conf 2>/dev/null || echo ${ETHX} >>/usr/syno/etc/synoovs/ovs_interface.conf
    if [ ! -f "/etc/sysconfig/network-scripts/ifcfg-${ETHX}" ]; then
      echo -e "DEVICE=${ETHX}\nONBOOT=yes\nBOOTPROTO=dhcp\nIPV6INIT=auto_dhcp\nIPV6_ACCEPT_RA=1\nBRIDGE=ovs_${ETHX}" >"/etc/sysconfig/network-scripts/ifcfg-${ETHX}"
    fi
    if [ ! -f "/etc/sysconfig/network-scripts/ifcfg-ovs_${ETHX}" ]; then
      echo -e "DEVICE=ovs_${ETHX}\nONBOOT=yes\nBOOTPROTO=dhcp\nIPV6INIT=auto_dhcp\nIPV6_ACCEPT_RA=1\nPRIMARY=${ETHX}\nTYPE=OVS" >"/etc/sysconfig/network-scripts/ifcfg-ovs_${ETHX}"
    fi
    if [ ! "$(ovs-vsctl iface-to-br ${ETHX})" = "ovs_${ETHX}" ]; then
      ovs-vsctl br-exists ovs_${ETHX}
      [ $? -ne 2 ] && ovs-vsctl del-br ovs_${ETHX}
      ovs-vsctl add-br ovs_${ETHX}
      ovs-vsctl add-port ovs_${ETHX} ${ETHX}
    fi
    ip link set ovs_${ETHX} up
  else
    if [ ! -f "/etc/sysconfig/network-scripts/ifcfg-${ETHX}" ]; then
      echo -e "DEVICE=${ETHX}\nONBOOT=yes\nBOOTPROTO=dhcp\nIPV6INIT=auto_dhcp\nIPV6_ACCEPT_RA=1" >"/etc/sysconfig/network-scripts/ifcfg-${ETHX}"
    fi
  fi
}

deleteifcfg() {
  ETHX=${1}
  if [ -n "$(cat /usr/syno/etc/synoovs/ovs_reg.conf 2>/dev/null)" ]; then
    ovs-vsctl del-br ovs_${ETHX}
    rm -f "/etc/sysconfig/network-scripts/ifcfg-ovs_${ETHX}"
    rm -f "/etc/sysconfig/network-scripts/ifcfg-${ETHX}"
  else
    rm -f "/etc/sysconfig/network-scripts/ifcfg-${ETHX}"
  fi
}

case "${NAME}" in
eth*)
  ETHX=${NAME}
  if [ "${ACTION}" = "start" ]; then
    ip link set "${ETHX}" up
    createifcfg "${ETHX}"
  else
    ip link set "${ETHX}" down
    # deleteifcfg "${ETHX}"
  fi
  ovs-vsctl br-exists "ovs_${ETHX}" && /etc/rc.network "${ACTION}" "ovs_${ETHX}" || /etc/rc.network "${ACTION}" "${ETHX}"
  ;;
usb*)
  ETHX=$(echo "${NAME}" | sed 's/usb/eth7/')
  if [ "${ACTION}" = "start" ]; then
    ip link set "${NAME}" down
    ip link set dev "${NAME}" name "${ETHX}"
    ip link set "${ETHX}" up
    createifcfg "${ETHX}"
    if [ -x /usr/syno/sbin/synonet ]; then # DSM
      /usr/syno/sbin/synonet --dhcp ${ETHX} || true
    fi
    if [ -x /sbin/udhcpc ]; then # junior
      if [ -f "/etc/dhcpc/dhcpcd-${ETHX}.pid" ]; then
        kill -9 "$(cat /etc/dhcpc/dhcpcd-${ETHX}.pid 2>/dev/null)" || true
        rm -f /etc/dhcpc/dhcpcd-${ETHX}.pid
      fi
      /sbin/udhcpc -i "${ETHX}" -p "/etc/dhcpc/dhcpcd-${ETHX}.pid" -b -x "hostname:$(hostname)" || true
    fi
  else
    ip link set "${ETHX}" down
    # deleteifcfg "${ETHX}"
  fi
  ;;
wlan*)
  ETHX=$(echo "${NAME}" | sed 's/wlan/eth8/')
  if [ "${ACTION}" = "start" ]; then
    ip link set "${NAME}" down
    ip link set dev "${NAME}" name "${ETHX}"
    ip link set "${ETHX}" up
    createifcfg "${ETHX}"
  else
    ip link set "${ETHX}" down
    # deleteifcfg "${ETHX}"
  fi
  ;;
*)
  echo "Unknown interface ${NAME}" >&2
  ;;
esac

exit 0
