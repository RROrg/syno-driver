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

  # ashmem_linux.ko
  if [ -f "${LMK_PATH}/ashmem_linux.ko" ]; then
    /sbin/lsmod | grep -wq "^ashmem_linux" && /sbin/rmmod -f ashmem_linux
    /sbin/insmod "${LMK_PATH}/ashmem_linux.ko"
  fi

  # binder_linux.ko
  if [ -f "${LMK_PATH}/binder_linux.ko" ]; then
    /sbin/lsmod | grep -wq "^binder_linux" && /sbin/rmmod -f binder_linux
    /sbin/insmod "${LMK_PATH}/binder_linux.ko"
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

  /sbin/lsmod | grep -wq "^ashmem_linux" && /sbin/rmmod -f ashmem_linux || true

  /sbin/lsmod | grep -wq "^binder_linux" && /sbin/rmmod -f binder_linux || true

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
