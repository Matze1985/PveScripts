#!/usr/bin/env bash

set -e

# ===== COLORS =====
YW=$(echo "\033[33m")
GN=$(echo "\033[1;92m")
RD=$(echo "\033[01;31m")
BL=$(echo "\033[36m")
CL=$(echo "\033[m")

echo -e "${GN}CachyOS LXC Container Installer${CL}"
echo -e "${BL}Proxmox Helper Script Style (tteck-inspired)${CL}\n"

# ===== CHECK ROOT =====
if [[ $EUID -ne 0 ]]; then
  echo -e "${RD}❌ Please run as root${CL}"
  exit 1
fi

# ===== CHECK PVE =====
if ! command -v pct &>/dev/null; then
  echo -e "${RD}❌ This is not a Proxmox system${CL}"
  exit 1
fi

# ===== DEFAULTS =====
CTID=$(pvesh get /cluster/nextid)
HOSTNAME="cachyos"
MEMORY=2048
CORES=2
ROOTFS_SIZE=8
STORAGE=$(pvesm status | awk 'NR>1 {print $1}' | head -n1)
BRIDGE="vmbr0"
ARCH="amd64"

ROOTFS_URL="https://mirror.cachyos.org/containers/cachyos-container.tar.zst"
CACHE="/var/lib/vz/template/cache"
ROOTFS="${CACHE}/cachyos-container.tar.zst"

# ===== PROMPTS =====
read -rp "Container ID [$CTID]: " input && CTID=${input:-$CTID}
read -rp "Hostname [$HOSTNAME]: " input && HOSTNAME=${input:-$HOSTNAME}
read -rp "Memory (MB) [$MEMORY]: " input && MEMORY=${input:-$MEMORY}
read -rp "CPU Cores [$CORES]: " input && CORES=${input:-$CORES}
read -rp "Disk Size (GB) [$ROOTFS_SIZE]: " input && ROOTFS_SIZE=${input:-$ROOTFS_SIZE}

echo -e "\n${YW}Using storage:${CL} $STORAGE"
echo -e "${YW}Using network bridge:${CL} $BRIDGE\n"

# ===== DOWNLOAD =====
mkdir -p "$CACHE"

if [[ ! -f $ROOTFS ]]; then
  echo -e "${YW}⬇️ Downloading CachyOS rootfs...${CL}"
  wget -q --show-progress -O "$ROOTFS" "$ROOTFS_URL"
else
  echo -e "${GN}✔ Rootfs already exists${CL}"
fi

# ===== CREATE =====
echo -e "${YW}📦 Creating LXC container...${CL}"

pct create "$CTID" "$ROOTFS" \
  --arch "$ARCH" \
  --hostname "$HOSTNAME" \
  --cores "$CORES" \
  --memory "$MEMORY" \
  --swap 512 \
  --rootfs "$STORAGE:${ROOTFS_SIZE}" \
  --net0 name=eth0,bridge="$BRIDGE",ip=dhcp \
  --unprivileged 1 \
  --features nesting=1,keyctl=1 \
  --ostype archlinux

# ===== START =====
pct start "$CTID"

echo -e "\n${GN}✅ CachyOS LXC Successfully Created!${CL}"
echo -e "${BL}CTID:${CL} $CTID"
echo -e "${BL}Login:${CL} pct enter $CTID\n"
