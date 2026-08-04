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
  [ -L "/usr/sbin/modinfo" ] || ln -vsf /usr/bin/kmod /usr/sbin/modinfo
  _insmod_depends() {
    local mod_path="$1"
    local mod_name
    mod_name="$(basename "${mod_path}" .ko | sed 's/-/_/g')"

    # Already loaded?
    /sbin/lsmod | grep -wq "^${mod_name}" && return 0

    # File exists?
    [ ! -f "${mod_path}" ] && return 1

    # Resolve and load dependencies
    local depends
    depends=$(/sbin/modinfo -F depends "${mod_path}" 2>/dev/null | sed 's/,/ /g')
    for dep in ${depends}; do
        local dep_path
        for P in "$(dirname "${mod_path}")" "/usr/lib/modules"; do
            dep_path="${P}/${dep}.ko"
            [ -f "${dep_path}" ] && { _insmod_depends "${dep_path}"; break; }
        done
    done

    # Now load the module itself
    /sbin/insmod "${mod_path}"
  }

  # use echo to write to the service log file.
  echo "service_prestart: Before service start"

  LUR_PATH="${SYNOPKG_PKGDEST}/udev"
  LFW_PATH="${SYNOPKG_PKGDEST}/firmware"

  _release=$(/bin/uname -r)
  KVER="$(/bin/echo ${_release%%[-+]*} | /usr/bin/cut -d'.' -f1-3)"
  PLATFORM=$(get_key_value /etc/synoinfo.conf platform_name)

  majorversion="$(/bin/get_key_value /etc/VERSION majorversion)"
  minorversion="$(/bin/get_key_value /etc/VERSION minorversion)"
  KPRE="${majorversion}.${minorversion}"

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

  # Load modules with dependency resolution
  for M in ashmem_linux.ko binder_linux.ko; do
    if [ -f "${LMK_PATH}/${M}" ]; then
      MN="$(echo "${M}" | sed 's/\.ko//')"
      /sbin/lsmod | grep -wq "^$(echo "${MN}" | sed 's/-/_/g')" && /sbin/rmmod -f "${MN}"
      _insmod_depends "${LMK_PATH}/${M}"
    fi
  done

}

service_poststop() {
  _rmmod_depends() {
    local mod_name="$1"
    local mod_name_safe
    mod_name_safe="$(echo "${mod_name}" | sed 's/-/_/g')"

    # Not loaded? Skip
    /sbin/lsmod | grep -wq "^${mod_name_safe}" || return 0

    # Find modules that depend on this one (from /proc/modules)
    local dependents
    dependents=$(/bin/awk -v target="${mod_name_safe}" '
    {
        if ($1 == target) next
        if ($3 == "0" || $4 == "-" || $4 == "") next
        split($4, deps, ",")
        for (i in deps) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", deps[i])
            if (deps[i] == target) print $1
        }
    }
    ' /proc/modules 2>/dev/null)

    for dep in ${dependents}; do
        _rmmod_depends "${dep}"
    done

    /sbin/rmmod "${mod_name_safe}" 2>/dev/null || true
  }

  # use echo to write to the service log file.
  echo "service_poststop: After service stop"

  LUR_PATH="${SYNOPKG_PKGDEST}/udev"
  LFW_PATH="${SYNOPKG_PKGDEST}/firmware"

  _release=$(/bin/uname -r)
  KVER="$(/bin/echo ${_release%%[-+]*} | /usr/bin/cut -d'.' -f1-3)"
  PLATFORM=$(get_key_value /etc/synoinfo.conf platform_name)

  majorversion="$(/bin/get_key_value /etc/VERSION majorversion)"
  minorversion="$(/bin/get_key_value /etc/VERSION minorversion)"
  KPRE="${majorversion}.${minorversion}"

  LMK_PATH="${SYNOPKG_PKGDEST}/modules/${PLATFORM}-${KPRE:+${KPRE}-}${KVER}"

  for M in ashmem_linux.ko binder_linux.ko; do
    MN="$(echo "${M}" | sed 's/\.ko//')"
    _rmmod_depends "${MN}"
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
