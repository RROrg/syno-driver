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
        [ -f "${dep_path}" ] && {
          _insmod_depends "${dep_path}"
          break
        }
      done
    done

    # Now load the module itself
    /sbin/insmod "${mod_path}"
  }

  # use echo to write to the service log file.
  echo "service_prestart: Before service start"

  LFW_PATH="${SYNOPKG_PKGDEST}/firmware"

  _release=$(/bin/uname -r)
  KVER="$(/bin/echo ${_release%%[-+]*} | /usr/bin/cut -d'.' -f1-3)"
  PLATFORM=$(get_key_value /etc/synoinfo.conf platform_name)

  majorversion="$(/bin/get_key_value /etc/VERSION majorversion)"
  minorversion="$(/bin/get_key_value /etc/VERSION minorversion)"
  KPRE="${majorversion}.${minorversion}"

  LMK_PATH="${SYNOPKG_PKGDEST}/modules/${PLATFORM}-${KPRE:+${KPRE}-}${KVER}"

  # Add firmware path to running kernel
  SYS_LFW_PATH="/sys/module/firmware_class/parameters/path"
  grep -q "${LFW_PATH}" "${SYS_LFW_PATH}" || echo "${LFW_PATH}" >>"${SYS_LFW_PATH}"

  # ----- GPU detection & driver loading -----
  # i915 (Intel) - support base + update two versions
  GPU="$(lspci -nd ::300 2>/dev/null | grep -Eo '8086:[0-9a-fA-F]{4}' | head -n1 | sed 's/://')"
  if [ -n "${GPU}" ]; then
    PCI="pci:v0000$(echo "${GPU:-}" | cut -c1-4)d0000$(echo "${GPU:-}" | cut -c5-8)"
    if [ -f "${LMK_PATH}/i915.ko" ] && modinfo -F alias "${LMK_PATH}/i915.ko" 2>/dev/null | grep -iq "${PCI}"; then
      echo "i915.ko supports ${GPU}"
      /sbin/lsmod | grep -wq "^i915" && /sbin/rmmod -f i915
      _insmod_depends "${LMK_PATH}/i915.ko"
      echo "i915 module loaded successfully"
    elif [ -f "${LMK_PATH}/update/i915.ko" ] && modinfo -F alias "${LMK_PATH}/update/i915.ko" 2>/dev/null | grep -iq "${PCI}"; then
      echo "update i915.ko supports ${GPU}"
      /sbin/lsmod | grep -wq "^i915" && /sbin/rmmod -f i915
      _insmod_depends "${LMK_PATH}/update/i915.ko"
      echo "i915 (update) module loaded successfully"
    fi
  fi

  # amdgpu (AMD)
  if lspci -nd ::300 2>/dev/null | grep -Eq '1002:[0-9a-fA-F]{4}'; then
    if [ -f "${LMK_PATH}/amdgpu.ko" ]; then
      echo "AMD GPU detected, loading amdgpu"
      /sbin/lsmod | grep -wq "^amdgpu" && /sbin/rmmod -f amdgpu
      _insmod_depends "${LMK_PATH}/amdgpu.ko"
      echo "amdgpu module loaded successfully"
    fi
  fi

  # virtio-gpu (QEMU/KVM virtio)
  if lspci -d ::300 2>/dev/null | grep -qi '1af4'; then
    if [ -f "${LMK_PATH}/virtio-gpu.ko" ]; then
      echo "virtio GPU detected, loading virtio-gpu"
      /sbin/lsmod | grep -wq "^virtio_gpu" && /sbin/rmmod -f virtio_gpu
      _insmod_depends "${LMK_PATH}/virtio-gpu.ko"
      echo "virtio-gpu module loaded successfully"
    fi
  fi

  # bochs-drm (QEMU VGA)
  if lspci -d ::300 2>/dev/null | grep -qi '1234'; then
    if [ -f "${LMK_PATH}/bochs-drm.ko" ]; then
      echo "Bochs VGA detected, loading bochs-drm"
      /sbin/lsmod | grep -wq "^bochs_drm" && /sbin/rmmod -f bochs_drm
      _insmod_depends "${LMK_PATH}/bochs-drm.ko"
      echo "bochs-drm module loaded successfully"
    fi
  fi
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

  LFW_PATH="${SYNOPKG_PKGDEST}/firmware"

  _release=$(/bin/uname -r)
  KVER="$(/bin/echo ${_release%%[-+]*} | /usr/bin/cut -d'.' -f1-3)"
  PLATFORM=$(get_key_value /etc/synoinfo.conf platform_name)

  majorversion="$(/bin/get_key_value /etc/VERSION majorversion)"
  minorversion="$(/bin/get_key_value /etc/VERSION minorversion)"
  KPRE="${majorversion}.${minorversion}"

  LMK_PATH="${SYNOPKG_PKGDEST}/modules/${PLATFORM}-${KPRE:+${KPRE}-}${KVER}"

  # Unload GPU modules (outermost first)
  _rmmod_depends "bochs_drm"
  _rmmod_depends "virtio_gpu"
  _rmmod_depends "amdgpu"
  _rmmod_depends "i915"

  # Remove firmware path from running kernel
  SYS_LFW_PATH="/sys/module/firmware_class/parameters/path"
  echo "$(grep -v "${LFW_PATH}" "${SYS_LFW_PATH}")" >"${SYS_LFW_PATH}"
}
