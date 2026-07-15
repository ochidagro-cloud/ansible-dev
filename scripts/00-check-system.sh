#!/usr/bin/env bash
#
# ============================================================================
# Debian KVM Lab
# Script : 00-check-system.sh
# Version: 1.0.0
# Author : Ochi Da
# License: MIT
#
# Description:
# Melakukan pemeriksaan awal sistem Debian sebelum proses instalasi
# dan konfigurasi server.
#
# ============================================================================

set -Eeuo pipefail

##############################################################################
# GLOBAL CONFIG
##############################################################################

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

LOG_DIR="${PROJECT_ROOT}/logs"
LOG_FILE="${LOG_DIR}/check-system.log"

DATE_NOW="$(date '+%Y-%m-%d %H:%M:%S')"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

##############################################################################
# COLOR
##############################################################################

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
WHITE="\033[1;37m"
NC="\033[0m"

##############################################################################
# LOGGING
##############################################################################

mkdir -p "${LOG_DIR}"
touch "${LOG_FILE}"

log() {
    echo "[$(date '+%F %T')] $*" >> "${LOG_FILE}"
}

##############################################################################
# OUTPUT
##############################################################################

title() {
    echo
    echo -e "${BLUE}====================================================${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${BLUE}====================================================${NC}"
}

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    log "[PASS] $1"
    ((PASS_COUNT++))
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    log "[WARN] $1"
    ((WARN_COUNT++))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    log "[FAIL] $1"
    ((FAIL_COUNT++))
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
    log "[INFO] $1"
}

##############################################################################
# ROOT CHECK
##############################################################################

check_root() {

    title "CHECK ROOT"

    if [[ $EUID -eq 0 ]]; then
        pass "Running as root"
    else
        fail "Script harus dijalankan sebagai root"

        echo
        echo "Gunakan:"
        echo
        echo "sudo ./scripts/00-check-system.sh"
        echo

        exit 1
    fi
}

##############################################################################
# OS INFORMATION
##############################################################################

check_os() {

    title "OPERATING SYSTEM"

    if [[ -f /etc/os-release ]]; then
        source /etc/os-release

        info "Distribution : ${PRETTY_NAME}"
        info "ID           : ${ID}"
        info "Version      : ${VERSION_ID}"

        if [[ "${ID}" == "debian" ]]; then
            pass "Debian detected"
        else
            warn "Distribusi bukan Debian"
        fi

    else
        fail "/etc/os-release tidak ditemukan"
    fi
}

##############################################################################
# KERNEL
##############################################################################

check_kernel() {

    title "KERNEL"

    KERNEL="$(uname -r)"
    ARCH="$(uname -m)"

    info "Kernel : ${KERNEL}"
    info "Arch   : ${ARCH}"

    pass "Kernel information collected"
}

##############################################################################
# HOSTNAME
##############################################################################

check_hostname() {

    title "HOSTNAME"

    HOST="$(hostname)"

    info "Hostname : ${HOST}"

    if [[ -n "${HOST}" ]]; then
        pass "Hostname OK"
    else
        fail "Hostname kosong"
    fi
}

##############################################################################
# CPU
##############################################################################

check_cpu() {

    title "CPU"

    CPU_MODEL=$(lscpu | awk -F: '/Model name/{print $2}' | xargs)
    CPU_CORE=$(nproc)
    CPU_ARCH=$(uname -m)

    info "Model : ${CPU_MODEL}"
    info "Core  : ${CPU_CORE}"
    info "Arch  : ${CPU_ARCH}"

    if [[ "${CPU_CORE}" -ge 2 ]]; then
        pass "CPU memenuhi syarat minimum"
    else
        warn "CPU hanya memiliki ${CPU_CORE} core"
    fi
}

##############################################################################
# MEMORY
##############################################################################

check_memory() {

    title "MEMORY"

    TOTAL=$(free -m | awk '/Mem:/ {print $2}')
    USED=$(free -m | awk '/Mem:/ {print $3}')
    FREE=$(free -m | awk '/Mem:/ {print $4}')

    info "Total : ${TOTAL} MB"
    info "Used  : ${USED} MB"
    info "Free  : ${FREE} MB"

    if [[ "${TOTAL}" -ge 4096 ]]; then
        pass "RAM mencukupi"
    else
        warn "RAM kurang dari 4GB"
    fi
}

##############################################################################
# HEADER
##############################################################################

clear

echo
echo "===================================================="
echo " Debian KVM Lab"
echo " Pre-flight System Check"
echo "===================================================="
echo

log "==============================================="
log "CHECK START : ${DATE_NOW}"
log "==============================================="

##############################################################################
# DISK
##############################################################################

check_disk() {

    title "DISK"

    ROOT_DISK=$(df -h / | awk 'NR==2 {print $1}')
    ROOT_SIZE=$(df -h / | awk 'NR==2 {print $2}')
    ROOT_USED=$(df -h / | awk 'NR==2 {print $3}')
    ROOT_AVAIL=$(df -h / | awk 'NR==2 {print $4}')
    ROOT_PERCENT=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')

    info "Device    : ${ROOT_DISK}"
    info "Size      : ${ROOT_SIZE}"
    info "Used      : ${ROOT_USED}"
    info "Available : ${ROOT_AVAIL}"

    if [[ ${ROOT_PERCENT} -lt 80 ]]; then
        pass "Disk usage ${ROOT_PERCENT}%"
    elif [[ ${ROOT_PERCENT} -lt 90 ]]; then
        warn "Disk usage ${ROOT_PERCENT}%"
    else
        fail "Disk hampir penuh (${ROOT_PERCENT}%)"
    fi
}

##############################################################################
# FILESYSTEM
##############################################################################

check_filesystem() {

    title "FILESYSTEM"

    findmnt -o TARGET,FSTYPE,SIZE,USED,AVAIL

    ROOT_FS=$(findmnt -n -o FSTYPE /)

    info "Root Filesystem : ${ROOT_FS}"

    case "${ROOT_FS}" in
        ext4|xfs|btrfs)
            pass "Filesystem didukung"
            ;;
        *)
            warn "Filesystem ${ROOT_FS} belum diuji"
            ;;
    esac
}

##############################################################################
# SWAP
##############################################################################

check_swap() {

    title "SWAP"

    if swapon --show | grep -q .; then

        swapon --show

        TOTAL_SWAP=$(free -m | awk '/Swap:/ {print $2}')

        info "Swap : ${TOTAL_SWAP} MB"

        pass "Swap aktif"

    else

        warn "Swap tidak aktif"

    fi
}

##############################################################################
# VIRTUALIZATION SUPPORT
##############################################################################

check_virtualization() {

    title "CPU VIRTUALIZATION"

    if grep -E '(vmx|svm)' /proc/cpuinfo >/dev/null; then

        pass "CPU mendukung Virtualization"

    else

        fail "CPU tidak mendukung VT-x / AMD-V"

    fi
}

##############################################################################
# BIOS / UEFI VIRTUALIZATION
##############################################################################

check_bios_virtualization() {

    title "BIOS VIRTUALIZATION"

    if dmesg | grep -Ei "kvm|vmx|svm" >/dev/null 2>&1; then

        pass "Virtualization aktif di BIOS"

    else

        warn "Belum terdeteksi aktif"

        echo
        echo "Kemungkinan:"
        echo " - Intel VT-x masih OFF"
        echo " - AMD-V masih OFF"
        echo " - Nested Virtualization"
        echo
    fi
}

##############################################################################
# /dev/kvm
##############################################################################

check_dev_kvm() {

    title "/DEV/KVM"

    if [[ -e /dev/kvm ]]; then

        ls -l /dev/kvm

        pass "/dev/kvm tersedia"

    else

        warn "/dev/kvm belum tersedia"

    fi
}

##############################################################################
# KVM MODULE
##############################################################################

check_kvm_modules() {

    title "KVM MODULE"

    MODULES=(
        kvm
        kvm_intel
        kvm_amd
    )

    FOUND=0

    for module in "${MODULES[@]}"
    do
        if lsmod | grep -q "^${module}"; then
            pass "Module ${module} loaded"
            FOUND=1
        fi
    done

    if [[ ${FOUND} -eq 0 ]]; then
        warn "Belum ada module KVM yang aktif"
    fi
}

##############################################################################
# QEMU CHECK
##############################################################################

check_qemu() {

    title "QEMU"

    if command -v qemu-system-x86_64 >/dev/null 2>&1; then

        VERSION=$(qemu-system-x86_64 --version | head -1)

        info "${VERSION}"

        pass "QEMU terinstall"

    else

        warn "QEMU belum terinstall"
    fi
}

##############################################################################
# LIBVIRT CHECK
##############################################################################

check_libvirt() {

    title "LIBVIRT"

    if command -v virsh >/dev/null 2>&1; then

        VERSION=$(virsh --version)

        info "Virsh ${VERSION}"

        pass "Libvirt tersedia"

    else

        warn "Libvirt belum terinstall"

    fi
}

##############################################################################
# NETWORK INTERFACE
##############################################################################

check_network_interface() {

    title "NETWORK INTERFACE"

    DEFAULT_IFACE=$(ip route | awk '/default/ {print $5}' | head -1)

    if [[ -n "${DEFAULT_IFACE}" ]]; then
        info "Interface : ${DEFAULT_IFACE}"
        pass "Network interface ditemukan"
    else
        fail "Tidak ada interface aktif"
    fi
}

##############################################################################
# IP ADDRESS
##############################################################################

check_ip_address() {

    title "IP ADDRESS"

    IP_ADDR=$(ip -4 addr show "${DEFAULT_IFACE}" \
        | awk '/inet / {print $2}' \
        | head -1)

    if [[ -n "${IP_ADDR}" ]]; then
        info "IPv4 : ${IP_ADDR}"
        pass "IP Address tersedia"
    else
        warn "Belum memperoleh IP Address"
    fi
}

##############################################################################
# DEFAULT GATEWAY
##############################################################################

check_gateway() {

    title "DEFAULT GATEWAY"

    GATEWAY=$(ip route | awk '/default/ {print $3}' | head -1)

    if [[ -n "${GATEWAY}" ]]; then
        info "Gateway : ${GATEWAY}"
        pass "Gateway tersedia"
    else
        fail "Gateway tidak ditemukan"
    fi
}

##############################################################################
# DNS
##############################################################################

check_dns() {

    title "DNS"

    if [[ -f /etc/resolv.conf ]]; then

        grep nameserver /etc/resolv.conf

        if grep -q nameserver /etc/resolv.conf; then
            pass "DNS Resolver tersedia"
        else
            warn "DNS Resolver kosong"
        fi

    else
        fail "/etc/resolv.conf tidak ditemukan"
    fi
}

##############################################################################
# INTERNET CONNECTIVITY
##############################################################################

check_internet() {

    title "INTERNET"

    if ping -c2 -W2 1.1.1.1 >/dev/null 2>&1; then
        pass "Internet (IP) OK"
    else
        fail "Tidak dapat menghubungi Internet"
    fi

    if ping -c2 -W2 deb.debian.org >/dev/null 2>&1; then
        pass "DNS Resolution OK"
    else
        warn "DNS Resolution gagal"
    fi
}

##############################################################################
# APT REPOSITORY
##############################################################################

check_apt() {

    title "APT"

    if command -v apt >/dev/null 2>&1; then
        pass "APT tersedia"
    else
        fail "APT tidak tersedia"
    fi

    if [[ -f /etc/apt/sources.list ]]; then
        pass "sources.list ditemukan"
    else
        warn "sources.list tidak ditemukan"
    fi
}

##############################################################################
# SSH
##############################################################################

check_ssh() {

    title "SSH"

    if command -v ssh >/dev/null 2>&1; then
        pass "SSH Client tersedia"
    else
        warn "SSH Client belum terinstall"
    fi

    if systemctl is-enabled ssh >/dev/null 2>&1; then
        pass "SSH Service Enabled"
    else
        warn "SSH belum Enable"
    fi

    if systemctl is-active ssh >/dev/null 2>&1; then
        pass "SSH Service Running"
    else
        warn "SSH belum berjalan"
    fi
}

##############################################################################
# FIREWALL
##############################################################################

check_firewall() {

    title "FIREWALL"

    if command -v nft >/dev/null 2>&1; then

        pass "nftables tersedia"

        if systemctl is-active nftables >/dev/null 2>&1; then
            pass "nftables aktif"
        else
            warn "nftables belum aktif"
        fi

    elif command -v ufw >/dev/null 2>&1; then

        pass "UFW tersedia"

    else

        warn "Firewall belum terinstall"

    fi
}

##############################################################################
# SYSTEMD
##############################################################################

check_systemd() {

    title "SYSTEMD"

    if pidof systemd >/dev/null 2>&1; then
        pass "systemd aktif"
    else
        fail "systemd tidak berjalan"
    fi
}

##############################################################################
# JOURNALD
##############################################################################

check_journald() {

    title "JOURNALD"

    if systemctl is-active systemd-journald >/dev/null 2>&1; then
        pass "systemd-journald aktif"
    else
        warn "journald tidak aktif"
    fi
}

##############################################################################
# BASIC COMMANDS
##############################################################################

check_basic_commands() {

    title "BASIC COMMANDS"

    PACKAGES=(
        git
        curl
        wget
        jq
        vim
        nano
        rsync
        tar
        gzip
        unzip
        tree
        openssl
        systemctl
    )

    for cmd in "${PACKAGES[@]}"
    do
        if command -v "$cmd" >/dev/null 2>&1; then
            pass "$cmd"
        else
            warn "$cmd belum terinstall"
        fi
    done
}

##############################################################################
# IMPORTANT FILES
##############################################################################

check_system_files() {

    title "SYSTEM FILES"

    FILES=(
        /etc/hosts
        /etc/hostname
        /etc/fstab
        /etc/os-release
        /etc/resolv.conf
    )

    for f in "${FILES[@]}"
    do
        if [[ -f "$f" ]]; then
            pass "$f"
        else
            fail "$f tidak ditemukan"
        fi
    done
}

##############################################################################
# SECURE BOOT
##############################################################################

check_secure_boot() {

    title "SECURE BOOT"

    if command -v mokutil >/dev/null 2>&1; then

        STATUS=$(mokutil --sb-state 2>/dev/null || true)

        info "${STATUS}"

        if echo "${STATUS}" | grep -qi enabled; then
            warn "Secure Boot Enabled"
        else
            pass "Secure Boot Disabled"
        fi

    else

        warn "mokutil belum terinstall"

    fi
}

##############################################################################
# TIME
##############################################################################

check_time() {

    title "TIME"

    timedatectl

    if timedatectl show -p NTPSynchronized --value | grep -q yes; then

        pass "NTP synchronized"

    else

        warn "NTP belum sinkron"

    fi
}

##############################################################################
# INODE
##############################################################################

check_inode() {

    title "INODE"

    df -i /

    USED=$(df -i / | awk 'NR==2{print $5}' | tr -d '%')

    if [[ "${USED}" -lt 80 ]]; then

        pass "Inode usage ${USED}%"

    elif [[ "${USED}" -lt 90 ]]; then

        warn "Inode usage ${USED}%"

    else

        fail "Inode hampir habis (${USED}%)"

    fi
}

##############################################################################
# VIRTUAL MACHINE DETECTION
##############################################################################

check_platform() {

    title "PLATFORM"

    if command -v systemd-detect-virt >/dev/null; then

        TYPE=$(systemd-detect-virt)

        if [[ "${TYPE}" == "none" ]]; then

            pass "Bare Metal"

        else

            warn "Running on ${TYPE}"

        fi

    else

        warn "systemd-detect-virt tidak tersedia"

    fi
}

##############################################################################
# SUMMARY
##############################################################################

summary() {

    title "SUMMARY"

    echo
    echo "PASS : ${PASS_COUNT}"
    echo "WARN : ${WARN_COUNT}"
    echo "FAIL : ${FAIL_COUNT}"
    echo

    echo "Log File:"
    echo "${LOG_FILE}"
    echo

    if [[ ${FAIL_COUNT} -eq 0 ]]; then

        echo "Overall Status : PASS"

    else

        echo "Overall Status : FAIL"

    fi

}

##############################################################################
# MAIN
##############################################################################

main() {

    check_root

    check_os

    check_kernel

    check_hostname

    check_cpu

    check_memory

    check_disk

    check_filesystem

    check_swap

    check_virtualization

    check_bios_virtualization

    check_dev_kvm

    check_kvm_modules

    check_qemu

    check_libvirt

    check_network_interface

    check_ip_address

    check_gateway

    check_dns

    check_internet

    check_apt

    check_ssh

    check_firewall

    check_systemd

    check_journald

    check_basic_commands

    check_system_files

    check_secure_boot

    check_time

    check_inode

    check_platform

    summary
}

##############################################################################
# START
##############################################################################

main "$@"

##############################################################################
# EXIT CODE
##############################################################################

if [[ ${FAIL_COUNT} -gt 0 ]]; then

    exit 1

fi

if [[ ${WARN_COUNT} -gt 0 ]]; then

    exit 2

fi

exit 0