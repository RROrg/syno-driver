validate_preinst() {
  # use install_log to write to installer log file.
  install_log "validate_preinst ${SYNOPKG_PKG_STATUS}"
}

validate_preuninst() {
  # use install_log to write to installer log file.
  install_log "validate_preuninst ${SYNOPKG_PKG_STATUS}"
}

validate_preupgrade() {
  # use install_log to write to installer log file.
  install_log "validate_preupgrade ${SYNOPKG_PKG_STATUS}"
}

service_preinst() {
  # use echo to write to the installer log file.
  echo "service_preinst ${SYNOPKG_PKG_STATUS}"
}

service_postinst() {
  # use echo to write to the installer log file.
  echo "service_postinst ${SYNOPKG_PKG_STATUS}"
}

service_preuninst() {
  # use echo to write to the installer log file.
  echo "service_preuninst ${SYNOPKG_PKG_STATUS}"
}

service_postuninst() {
  # use echo to write to the installer log file.
  echo "service_postuninst ${SYNOPKG_PKG_STATUS}"
}

service_preupgrade() {
  # use echo to write to the installer log file.
  echo "service_preupgrade ${SYNOPKG_PKG_STATUS}"
}

service_postupgrade() {
  # use echo to write to the installer log file.
  echo "service_postupgrade ${SYNOPKG_PKG_STATUS}"
}

# REMARKS:
# installer variables are not available in the context of service start/stop
# The regular solution is to use configuration files for services

service_prestart() {
  # use echo to write to the service log file.
  echo "service_prestart: Before service start"

  LUR_PATH="${SYNOPKG_PKGDEST}/udev"
  LFW_PATH="${SYNOPKG_PKGDEST}/firmware"

  _release=$(/bin/uname -r)
  KVER="$(/bin/echo ${_release%%[-+]*} | /usr/bin/cut -d'.' -f1-3)"
  PLATFORM=$(get_key_value /etc/synoinfo.conf platform_name)
  if [ "$(echo "${KVER:-4}" | cut -d'.' -f1)" -lt 5 ]; then
    KPRE=""
  else
    majorversion="$(/bin/get_key_value /etc/VERSION majorversion)"
    minorversion="$(/bin/get_key_value /etc/VERSION minorversion)"
    KPRE="${majorversion}.${minorversion}"
  fi
  LMK_PATH="${SYNOPKG_PKGDEST}/modules/${PLATFORM}-${KPRE:+${KPRE}-}${KVER}"

  # Add udev rules to system
  HAS_RULES=false
  for R in ${LUR_PATH}/rules.d/*.rules; do
    [ -e "${R}" ] || continue
    RN="$(basename "${R}")"
    [ -e "/usr/lib/udev/rules.d/${RN}" ] && continue
    ln -s "${LUR_PATH}/rules.d/${RN}" "/usr/lib/udev/rules.d/${RN}"
    HAS_RULES=true
  done
  if [ "${HAS_RULES}" = true ]; then
    for S in ${LUR_PATH}/script/*.sh; do
      [ -e "${S}" ] || continue
      SN="$(basename "${S}")"
      [ -e "/usr/lib/udev/script/${SN}" ] && continue
      ln -s "${LUR_PATH}/script/${SN}" "/usr/lib/udev/script/${SN}"
    done
    echo "Reloading udev rules..."
    udevadm control --reload-rules
    udevadm trigger
  fi

  # Add firmware path to running kernel
  SYS_LFW_PATH="/sys/module/firmware_class/parameters/path" # System module firmware path file index
  grep -q "${LFW_PATH}" "${SYS_LFW_PATH}" || echo "${LFW_PATH}" >>"${SYS_LFW_PATH}"

  # install kernel modules
  for M in mii.ko usbnet.ko usbcore.ko; do
    for P in "${LMK_PATH}" "/usr/lib/modules"; do
      /sbin/lsmod | grep -wq "^$(echo "${M}" | sed 's/-/_/')" && break || /sbin/insmod "${P}/${M}.ko" 2>/dev/null
    done
  done

  # aqc111
  if [ -f "${LMK_PATH}/aqc111.ko" ]; then
    /sbin/lsmod | grep -wq "^aqc111" && /sbin/rmmod -f aqc111
    /sbin/insmod "${LMK_PATH}/aqc111.ko"
  fi
  # asix
  if [ -f "${LMK_PATH}/asix.ko" ]; then
    /sbin/insmod "${LMK_PATH}/libphy.ko" || true
    /sbin/lsmod | grep -wq "^asix" && /sbin/rmmod -f asix
    /sbin/insmod "${LMK_PATH}/asix.ko"
  fi

  # atlantic
  if [ -f "${LMK_PATH}/atlantic.ko" ]; then
    /sbin/insmod "${LMK_PATH}/crc-itu-t.ko" || true
    /sbin/lsmod | grep -wq "^atlantic" && /sbin/rmmod -f atlantic
    /sbin/insmod "${LMK_PATH}/atlantic.ko"
  fi

  # ax88179_178a
  if [ -f "${LMK_PATH}/ax88179_178a.ko" ]; then
    /sbin/lsmod | grep -wq "^ax88179_178a" && /sbin/rmmod -f ax88179_178a
    /sbin/insmod "${LMK_PATH}/ax88179_178a.ko"
  fi

  # r8152
  if [ -f "${LMK_PATH}/r8152.ko" ]; then
    /sbin/lsmod | grep -wq "^r8152" && /sbin/rmmod -f r8152
    /sbin/insmod "${LMK_PATH}/r8152.ko"
  fi

  # r8125
  if [ -f "${LMK_PATH}/r8125.ko" ]; then
    for I in $(/sbin/lsmod | grep -q "^r8125"); do /sbin/rmmod -f "${I}"; done
    /sbin/insmod "${LMK_PATH}/r8125.ko"
  fi

  # r8126
  if [ -f "${LMK_PATH}/r8126.ko" ]; then
    for I in $(/sbin/lsmod | grep -q "^r8126"); do /sbin/rmmod -f "${I}"; done
    /sbin/insmod "${LMK_PATH}/r8126.ko"
  fi

  # r8127
  if [ -f "${LMK_PATH}/r8127.ko" ]; then
    for I in $(/sbin/lsmod | grep -q "^r8127"); do /sbin/rmmod -f "${I}"; done
    /sbin/insmod "${LMK_PATH}/r8127.ko"
  fi

  # igc
  if [ -f "${LMK_PATH}/igc.ko" ]; then
    /sbin/lsmod | grep -wq "^igc" && /sbin/rmmod -f igc
    /sbin/insmod "${LMK_PATH}/igc.ko"
  fi

}

service_poststop() {
  # use echo to write to the service log file.
  echo "service_poststop: After service stop"

  LUR_PATH="${SYNOPKG_PKGDEST}/udev"
  LFW_PATH="${SYNOPKG_PKGDEST}/firmware"

  _release=$(/bin/uname -r)
  KVER="$(/bin/echo ${_release%%[-+]*} | /usr/bin/cut -d'.' -f1-3)"
  PLATFORM=$(get_key_value /etc/synoinfo.conf platform_name)
  if [ "$(echo "${KVER:-4}" | cut -d'.' -f1)" -lt 5 ]; then
    KPRE=""
  else
    majorversion="$(/bin/get_key_value /etc/VERSION majorversion)"
    minorversion="$(/bin/get_key_value /etc/VERSION minorversion)"
    KPRE="${majorversion}.${minorversion}"
  fi
  LMK_PATH="${SYNOPKG_PKGDEST}/modules/${PLATFORM}-${KPRE:+${KPRE}-}${KVER}"

  /sbin/lsmod | grep -wq "^r8127" && /sbin/rmmod -f r8127 || true

  /sbin/lsmod | grep -wq "^r8126" && /sbin/rmmod -f r8126 || true

  /sbin/lsmod | grep -wq "^r8125" && /sbin/rmmod -f r8125 || true

  /sbin/lsmod | grep -wq "^r8152" && /sbin/rmmod -f r8152 || true

  /sbin/lsmod | grep -wq "^ax88179_178a" && /sbin/rmmod -f ax88179_178a || true

  /sbin/lsmod | grep -wq "^atlantic" && /sbin/rmmod -f atlantic || true

  /sbin/lsmod | grep -wq "^ax88179_178a" && /sbin/rmmod -f ax88179_178a || true

  /sbin/lsmod | grep -wq "^asix" && /sbin/rmmod -f asix || true

  /sbin/lsmod | grep -wq "^aqc111" && /sbin/rmmod -f aqc111 || true

  /sbin/lsmod | grep -wq "^igc" && /sbin/rmmod -f igc || true

  # Remove kernel modules
  for M in usbcore.ko usbnet.ko mii.ko; do
    /sbin/lsmod | grep -wq "^$(echo "${M}" | sed 's/-/_/')" && /sbin/rmmod "${M}" || true
  done

  # Remove firmware path from running kernel
  SYS_LFW_PATH="/sys/module/firmware_class/parameters/path" # System module
  echo "$(grep -v "${LFW_PATH}" "${SYS_LFW_PATH}")" >"${SYS_LFW_PATH}"

  # Remove udev rules from system
  HAS_RULES=false
  for R in ${LUR_PATH}/rules.d/*.rules; do
    [ -e "${R}" ] || continue
    RN="$(basename "${R}")"
    [ -L "/usr/lib/udev/rules.d/${RN}" ] || continue
    rm -f "/usr/lib/udev/rules.d/${RN}"
    HAS_RULES=true
  done
  if [ "${HAS_RULES}" = true ]; then
    if [ ! -L "/usr/lib/udev/rules.d/99-usb-netcard.rules" ] && [ -L "/usr/lib/udev/script/usb-netcard.sh" ]; then
      rm -f "/usr/lib/udev/script/usb-netcard.sh"
    fi
    echo "Reloading udev rules..."
    udevadm control --reload-rules
    udevadm trigger
  fi
}
