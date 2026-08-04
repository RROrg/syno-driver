#!/usr/bin/env bash
#
# Copyright (C) 2022 Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

[ -z "${WORK_PATH}" ] && WORK_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

if [ -z "${1}" ]; then
  echo "Usage: ${0} <file>"
  exit 1
fi

# Check prerequisites
if ! command -v modinfo &>/dev/null; then
  echo "Error: modinfo not found. This script requires modinfo (part of kmod) to resolve module dependencies."
  exit 1
fi

if [ -f "${1}" ]; then
  MODS_DIR=$(basename "${1}" .zip 2>/dev/null)
  rm -rf "${WORK_PATH:-}/${MODS_DIR}"
  mkdir -p "${WORK_PATH:-}/${MODS_DIR}"
  unzip -oq "${1}" -d "${WORK_PATH:-}/${MODS_DIR}"
else
  MODS_DIR="${1}"
fi

for F in "${WORK_PATH}/${MODS_DIR}"/*.tgz; do
  [ ! -f "${F}" ] && continue
  mkdir -p "${F%.tgz}"
  tar -zxf "${F}" -C "${F%.tgz}" && rm -f "${F}"
done

# ============================================================
# MODINFO - recursively copy module, its dependencies, and firmware
# ============================================================
_COPIED_MODULES=()

# Simplified _copymod: copy .ko + recursive depends only (firmware handled separately)
_copymod() {
  local mod="$1"    # "module.ko"
  local src="$2"    # source platform directory
  local ko_dst="$3" # destination modules directory

  [ ! -f "${src}/${mod}" ] && return 1

  # Skip already copied
  for _c in "${_COPIED_MODULES[@]}"; do [ "${_c}" = "${ko_dst}/${mod}" ] && return 0; done
  cp -f "${src}/${mod}" "${ko_dst}/"
  _COPIED_MODULES+=("${ko_dst}/${mod}")

  # -- depends (modinfo -F depends) --
  local depends
  depends=$(modinfo -F depends "${src}/${mod}" 2>/dev/null | sed 's/,/ /g')
  for dep in ${depends}; do
    _copymod "${dep}.ko" "${src}" "${ko_dst}"
  done
}

# Copy firmware for all copied .ko files, deduplicated
_copyfw() {
  local pkg="$1"
  local fw_src="${WORK_PATH}/${MODS_DIR}/firmware"
  local fw_dst="${WORK_PATH}/src/spk/${pkg}/src/firmware"
  local -a fw_copied=()

  rm -rf "${fw_dst}"
  mkdir -p "${fw_dst}"

  [ ! -d "${fw_src}" ] && { rmdir "${fw_dst}" 2>/dev/null || true; return 0; }

  # Scan all copied .ko files (recursively) and collect firmware
  while IFS= read -r mod_path; do
    while IFS= read -r fw; do
      [ -z "${fw}" ] && continue
      if [ -f "${fw_src}/${fw}" ]; then
        mkdir -p "${fw_dst}/$(dirname "${fw}" 2>/dev/null)"
        for _c in "${fw_copied[@]}"; do [ "${_c}" = "${fw_dst}/${fw}" ] && continue 2; done
        cp -f "${fw_src}/${fw}" "${fw_dst}/${fw}"
        fw_copied+=("${fw_dst}/${fw}")
      fi
    done < <(modinfo -F firmware "${mod_path}" 2>/dev/null)
  done < <(find "${WORK_PATH}/src/spk/${pkg}/src/modules" -name '*.ko' 2>/dev/null)

  echo "  -> firmware: $(for _c in "${fw_copied[@]}"; do echo -n "${_c/*\/firmware\//} "; done)"

  # Remove empty firmware directory
  rmdir "${fw_dst}" 2>/dev/null || true
}

# ============================================================
# Process a single package
# ============================================================
_copy_pkg() {
  local pkg="$1"
  shift 1
  local targets=("$@")

  echo ""
  echo "=== ${pkg} ==="

  for D in "${WORK_PATH}/${MODS_DIR}"/*-*; do
    [ ! -d "${D}" ] && continue
    local platform ko_dst
    platform=$(basename "${D}" 2>/dev/null)
    ko_dst="${WORK_PATH}/src/spk/${pkg}/src/modules/${platform}"

    # Clean old modules for this platform
    rm -rf "${ko_dst}"
    mkdir -p "${ko_dst}"

    _COPIED_MODULES=()
    for mod in "${targets[@]}"; do
      _copymod "${mod}" "${D}" "${ko_dst}"
    done

    # Copy update modules if present (alternative/newer versions, e.g. i915)
    if [ -d "${D}/update" ]; then
      local upd_dst="${ko_dst}/update"
      mkdir -p "${upd_dst}"
      for mod in "${targets[@]}"; do
        _copymod "${mod}" "${D}/update" "${upd_dst}"
      done
    fi

    echo "  -> $(basename "${D}" 2>/dev/null): $(for _c in "${_COPIED_MODULES[@]}"; do echo -n "$(basename "${_c}" 2>/dev/null) "; done)"
  done

  # Copy firmware for all modules (from fixed source, deduplicated)
  _copyfw "${pkg}"

  # Remove empty module directories
  find "${WORK_PATH}/src/spk/${pkg}/src/modules" -depth -type d -exec rmdir {} \; 2>/dev/null || true
}

# ============================================================
# Define target modules per package
# Only specify the "leaf" modules; _copymod recursively resolves
# their dependencies via modinfo -F depends.
# ============================================================

# syno-network - USB/PCIe netcard drivers
_copy_pkg "syno-network" \
  aqc111.ko asix.ko atlantic.ko ax88179_178a.ko igc.ko r8152.ko r8125.ko r8126.ko r8127.ko

# syno-binder - Android IPC drivers
_copy_pkg "syno-binder" \
  ashmem_linux.ko binder_linux.ko

# syno-gpu - GPU drivers (Intel, AMD, virtio, Bochs, etc.)
_copy_pkg "syno-gpu" \
  i915.ko amdgpu.ko virtio-gpu.ko bochs-drm.ko

# syno-iptables - Netfilter/iptables
# Leaf modules from defines: iptable_filter, iptable_nat, iptable_mangle
# plus xtables matches/targets and IPv6 NAT/raw/masquerade.
# _copymod will skip modules not present in a given platform.
_copy_pkg "syno-iptables" \
  iptable_filter.ko iptable_nat.ko iptable_mangle.ko \
  ip6table_nat.ko ip6table_raw.ko \
  nf_nat_ipv6.ko nf_nat_masquerade_ipv6.ko \
  xt_connmark.ko xt_comment.ko xt_socket.ko xt_string.ko \
  xt_TPROXY.ko xt_owner.ko \
  xt_MASQUERADE.ko ipt_MASQUERADE.ko ip6t_MASQUERADE.ko

# syno-snd - ALSA sound driver
# Leaf modules from defines (4.x/5.x): HDA Intel, USB audio, codecs, EMU10K1, AC97, SOC.
# _copymod will skip modules not present in a given platform.
_copy_pkg "syno-snd" \
  snd_hda_intel.ko snd_usb_audio.ko \
  snd-hda-codec-generic.ko snd-hda-codec-realtek.ko snd-hda-codec-cmedia.ko \
  snd-hda-codec-analog.ko snd-hda-codec-idt.ko snd-hda-codec-si3054.ko \
  snd-hda-codec-cirrus.ko snd-hda-codec-ca0110.ko snd-hda-codec-ca0132.ko \
  snd-hda-codec-conexant.ko snd-hda-codec-via.ko snd-hda-codec-hdmi.ko \
  snd-hda-ext-core.ko snd-intel-dspcfg.ko \
  snd-emu10k1.ko snd-emu10k1-synth.ko snd-emu10k1x.ko snd-emux-synth.ko \
  snd-seq.ko snd-seq-virmidi.ko \
  snd-compress.ko snd-pcm-dmaengine.ko \
  snd-ac97-codec.ko ac97_bus.ko \
  snd-mixer-oss.ko snd-pcm-oss.ko \
  snd-soc-core.ko snd-soc-acpi.ko snd-soc-ac97.ko
