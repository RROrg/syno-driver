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
    grep -qw "${ETHX}" /usr/syno/etc/synoovs/ovs_ignore.conf 2>/dev/null && sed -i "/^${ETHX}$/d" /usr/syno/etc/synoovs/ovs_ignore.conf
    grep -qw "${ETHX}" /usr/syno/etc/synoovs/ovs_interface.conf 2>/dev/null || echo "${ETHX}" >>/usr/syno/etc/synoovs/ovs_interface.conf
    if [ ! -f "/etc/sysconfig/network-scripts/ifcfg-${ETHX}" ]; then
      echo -e "DEVICE=${ETHX}\nONBOOT=yes\nBOOTPROTO=dhcp\nIPV6INIT=auto_dhcp\nIPV6_ACCEPT_RA=1\nBRIDGE=ovs_${ETHX}" >"/etc/sysconfig/network-scripts/ifcfg-${ETHX}"
    else
      if ! grep -qw "BRIDGE=ovs_${ETHX}" "/etc/sysconfig/network-scripts/ifcfg-${ETHX}"; then
        sed -i "/^BRIDGE=/d" "/etc/sysconfig/network-scripts/ifcfg-${ETHX}"
        echo "BRIDGE=ovs_${ETHX}" >>"/etc/sysconfig/network-scripts/ifcfg-${ETHX}"
      fi
    fi
    if [ ! -f "/etc/sysconfig/network-scripts/ifcfg-ovs_${ETHX}" ]; then
      echo -e "DEVICE=ovs_${ETHX}\nONBOOT=yes\nBOOTPROTO=dhcp\nIPV6INIT=auto_dhcp\nIPV6_ACCEPT_RA=1\nPRIMARY=${ETHX}\nTYPE=OVS" >"/etc/sysconfig/network-scripts/ifcfg-ovs_${ETHX}"
    else
      if ! grep -qw "PRIMARY=${ETHX}" "/etc/sysconfig/network-scripts/ifcfg-ovs_${ETHX}"; then
        sed -i "/^PRIMARY=/d" "/etc/sysconfig/network-scripts/ifcfg-ovs_${ETHX}"
        echo "PRIMARY=${ETHX}" >>"/etc/sysconfig/network-scripts/ifcfg-ovs_${ETHX}"
      fi
    fi
    for F in /etc/sysconfig/network-scripts/ifcfg-ovs_bond*; do
      [ -e "${F}" ] || continue
      if echo "$(get_key_value "${F}" "SLAVE_LIST" 2>/dev/null)" | grep -qw "${ETHX}"; then
        BONDN="$(echo "$(basename "${F}" 2>/dev/null)" | cut -d'-' -f2)"
        if ! grep -qw "BSLAVE=yes" "/etc/sysconfig/network-scripts/ifcfg-ovs_${ETHX}"; then
          sed -i "/^BSLAVE=/d" "/etc/sysconfig/network-scripts/ifcfg-ovs_${ETHX}"
          echo "BSLAVE=yes" >>"/etc/sysconfig/network-scripts/ifcfg-ovs_${ETHX}"
        fi
        if ! grep -qw "BSLAVE=yes" "/etc/sysconfig/network-scripts/ifcfg-${ETHX}"; then
          sed -i "/^BSLAVE=/d" "/etc/sysconfig/network-scripts/ifcfg-${ETHX}"
          echo "BSLAVE=yes" >>"/etc/sysconfig/network-scripts/ifcfg-${ETHX}"
        fi
        if ! grep -qw "MASTER=${BONDN}" "/etc/sysconfig/network-scripts/ifcfg-${ETHX}"; then
          sed -i "/^MASTER=/d" "/etc/sysconfig/network-scripts/ifcfg-${ETHX}"
          echo "MASTER=${BONDN}" >>"/etc/sysconfig/network-scripts/ifcfg-${ETHX}"
        fi
      fi
    done
  else
    if [ ! -f "/etc/sysconfig/network-scripts/ifcfg-${ETHX}" ]; then
      echo -e "DEVICE=${ETHX}\nONBOOT=yes\nBOOTPROTO=dhcp\nIPV6INIT=auto_dhcp\nIPV6_ACCEPT_RA=1" >"/etc/sysconfig/network-scripts/ifcfg-${ETHX}"
    else
      for F in /etc/sysconfig/network-scripts/ifcfg-bond*; do
        [ -e "${F}" ] || continue
        if echo "$(get_key_value "${F}" "SLAVE_LIST" 2>/dev/null)" | grep -qw "${ETHX}"; then
          BONDN="$(echo "$(basename "${F}" 2>/dev/null)" | cut -d'-' -f2)"
          if ! grep -qw "BSLAVE=yes" "/etc/sysconfig/network-scripts/ifcfg-${ETHX}"; then
            sed -i "/^BSLAVE=/d" "/etc/sysconfig/network-scripts/ifcfg-${ETHX}"
            echo "BSLAVE=yes" >>"/etc/sysconfig/network-scripts/ifcfg-${ETHX}"
          fi
          if ! grep -qw "MASTER=${BONDN}" "/etc/sysconfig/network-scripts/ifcfg-${ETHX}"; then
            sed -i "/^MASTER=/d" "/etc/sysconfig/network-scripts/ifcfg-${ETHX}"
            echo "MASTER=${BONDN}" >>"/etc/sysconfig/network-scripts/ifcfg-${ETHX}"
          fi
        fi
      done
    fi
  fi
}

# shellcheck disable=SC2329
deleteifcfg() {
  ETHX=${1}
  if [ -n "$(cat /usr/syno/etc/synoovs/ovs_reg.conf 2>/dev/null)" ]; then
    rm -f "/etc/sysconfig/network-scripts/ifcfg-ovs_${ETHX}"
    rm -f "/etc/sysconfig/network-scripts/ifcfg-${ETHX}"
  else
    rm -f "/etc/sysconfig/network-scripts/ifcfg-${ETHX}"
  fi
}

case "${NAME}" in
eth*)
  ETHX=${NAME}
  [ "${ACTION}" = "start" ] && createifcfg "${ETHX}" # || deleteifcfg "${ETHX}"

  BRIDGE=$(get_key_value "/etc/sysconfig/network-scripts/ifcfg-${ETHX}" "BRIDGE" 2>/dev/null)
  MASTER=$(get_key_value "/etc/sysconfig/network-scripts/ifcfg-${ETHX}" "MASTER" 2>/dev/null)
  if [ -n "${MASTER}" ]; then
    ip link set "${MASTER}" "$([ "${ACTION}" = "start" ] && echo "up" || echo "down")"
    /etc/rc.network "${ACTION}" "${MASTER}"
  elif [ -n "${BRIDGE}" ]; then
    ip link set "${BRIDGE}" "$([ "${ACTION}" = "start" ] && echo "up" || echo "down")"
    /etc/rc.network "${ACTION}" "${BRIDGE}"
  else
    ip link set "${ETHX}" "$([ "${ACTION}" = "start" ] && echo "up" || echo "down")"
    /etc/rc.network "${ACTION}" "${ETHX}"
  fi
  ;;
usb*)
  ETHX=$(echo "${NAME}" | sed 's/usb/eth7/')
  if [ "${ACTION}" = "start" ]; then
    ip link set "${NAME}" down
    ip link set dev "${NAME}" name "${ETHX}"
    ip link set "${ETHX}" up
    createifcfg "${ETHX}"
    if [ -x /usr/syno/sbin/synonet ]; then # DSM
      /usr/syno/sbin/synonet --dhcp "${ETHX}" || true
    fi
    if [ -x /sbin/udhcpc ]; then # junior
      if [ -f "/etc/dhcpc/dhcpcd-${ETHX}.pid" ]; then
        kill -9 "$(cat "/etc/dhcpc/dhcpcd-${ETHX}.pid" 2>/dev/null)" || true
        rm -f "/etc/dhcpc/dhcpcd-${ETHX}.pid"
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
