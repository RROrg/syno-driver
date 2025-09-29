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

MODS_DIR=$(basename "${1}" .zip 2>/dev/null)

rm -rf "${WORK_PATH}/${MODS_DIR}"
mkdir -p "${WORK_PATH}/${MODS_DIR}"
unzip -oq "${1}" -d "${WORK_PATH}/${MODS_DIR}"

for F in "${WORK_PATH}/${MODS_DIR}"/*.tgz; do
    mkdir -p "${F%.tgz}"
    tar -zxf "${F}" -C "${F%.tgz}" && rm -f "${F}"
done

for D in "${WORK_PATH}/${MODS_DIR}"/*-*; do
    for i in aqc111.ko libphy.ko asix.ko crc-itu-t.ko atlantic.ko ax88179_178a.ko r8152.ko r8125.ko r8126.ko r8127.ko igc.ko; do
        [ -f "${D}/${i}" ] && { DEST_DIR="$(echo "${D}" | sed "s|${MODS_DIR}|src/spk/syno-network/src/modules|")"; mkdir -p "${DEST_DIR}"; cp -f "${D}/${i}" "${DEST_DIR}/"; }
    done
done

for D in "${WORK_PATH}/${MODS_DIR}"/*-*; do
    for i in ashmem_linux.ko binder_linux.ko; do
        [ -f "${D}/${i}" ] && { DEST_DIR="$(echo "${D}" | sed "s|${MODS_DIR}|src/spk/syno-binder/src/modules|")"; mkdir -p "${DEST_DIR}"; cp -f "${D}/${i}" "${DEST_DIR}/"; }
    done
done
