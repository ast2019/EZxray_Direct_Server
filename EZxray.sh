#!/bin/bash
# ============================================
# EZxray - STEALTH EDITION (DEBUGGED + REALITY)
# 12 Protocols | VLESS-REALITY-Vision Anti-DPI
# ============================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# ============================================
# FUNCTIONS
# ============================================

loading_animation() {
    local chars="|/-\\"
    local delay=0.05
    local message="$1"
    echo -ne "${CYAN}${message} "
    for i in {1..20}; do
        echo -ne "\r${CYAN}${message} ${chars:$((i%4)):1}${NC}"
        sleep "$delay"
    done
    echo -e "\r${GREEN}${message} OK${NC}                    "
}

matrix_effect() {
    echo -e "${GREEN}"
    for i in {1..3}; do
        for j in {1..40}; do
            echo -ne "$((RANDOM % 2))"
            sleep 0.002
        done
        echo ""
    done
    echo -e "${NC}"
}

generate_fancy_name() {
    local prefixes=("NEO" "QUANTUM" "STELLAR" "COSMIC" "PHOENIX" "NEBULA" "ZEN" "FUSION" "OMEGA" "INFINITY" "ATOM" "CYBER" "NOVA" "SOLAR" "GALAXY" "HYPER" "MEGA" "ULTRA" "PLATINUM" "DIAMOND")
    local suffixes=("X" "PRO" "MAX" "ULTRA" "ELITE" "PRIME" "GOLD" "BLACK" "TI" "NX" "GT" "SS" "PLUS" "LITE" "TURBO" "VIP" "PREMIUM" "SUPREME" "LEGEND" "MYTHIC")
    echo "${prefixes[$((RANDOM % 20))]}-${suffixes[$((RANDOM % 20))]}-$((RANDOM % 999 + 100))"
}

copy_to_clipboard() {
    local config="$1"
    local name="$2"
    if [ "$CLIP_CMD" = "cat" ]; then
        echo -e "${YELLOW}(No clipboard tool found - showing config for manual copy)${NC}"
        echo -e "${WHITE}${config}${NC}"
    else
        echo -n "$config" | $CLIP_CMD 2>/dev/null \
            && echo -e "${GREEN}Copied ${name} config to clipboard!${NC}" \
            || { echo -e "${YELLOW}Clipboard copy failed - config below:${NC}"; echo -e "${WHITE}${config}${NC}"; }
    fi
}

port_in_use() {
    local p="$1"
    if command -v ss &>/dev/null; then
        ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${p}\$" && return 0
    elif command -v netstat &>/dev/null; then
        netstat -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${p}\$" && return 0
    fi
    return 1
}

# ============================================
# SNI AUTO-SELECTION (best disguise domain)
# ============================================
# A REALITY "borrow" target must, when reached FROM THIS SERVER:
#   - be reachable on :443
#   - negotiate TLS 1.3
#   - use the X25519 key-exchange group (hard REALITY requirement)
#   - ideally support HTTP/2 (ALPN h2)
# We test a pool of widely-used domains live and keep the ones that actually
# work from this server's network, so we never hardcode a domain the censor
# may have already tampered with.
SNI_CANDIDATES=(
    "www.microsoft.com"
    "www.cloudflare.com"
    "www.apple.com"
    "dl.google.com"
    "www.bing.com"
    "aws.amazon.com"
    "cdn.jsdelivr.net"
    "www.samsung.com"
    "www.icloud.com"
    "swcdn.apple.com"
    "www.tesla.com"
    "www.lovelive-anime.jp"
)

# test_sni <domain> <strict>  -> returns 0 if usable for REALITY
# strict=1 also requires ALPN h2; strict=0 only requires TLS1.3 + X25519
test_sni() {
    local domain="$1"
    local strict="$2"
    local out
    out=$(timeout 6 openssl s_client -connect "${domain}:443" -servername "$domain" \
        -tls1_3 -alpn h2 </dev/null 2>/dev/null)
    [ -z "$out" ] && return 1
    echo "$out" | grep -q "TLSv1.3"                  || return 1
    echo "$out" | grep -qi "Server Temp Key: *X25519" || return 1
    if [ "$strict" = "1" ]; then
        echo "$out" | grep -q "ALPN protocol: h2"     || return 1
    fi
    return 0
}

# Echo up to 3 best SNIs (space separated). Strict pass first, then relaxed.
pick_best_snis() {
    local found=()
    local d
    for d in "${SNI_CANDIDATES[@]}"; do
        if test_sni "$d" 1; then
            found+=("$d")
            [ "${#found[@]}" -ge 3 ] && break
        fi
    done
    if [ "${#found[@]}" -lt 3 ]; then
        for d in "${SNI_CANDIDATES[@]}"; do
            [[ " ${found[*]} " == *" $d "* ]] && continue
            if test_sni "$d" 0; then
                found+=("$d")
                [ "${#found[@]}" -ge 3 ] && break
            fi
        done
    fi
    echo "${found[@]}"
}

# ============================================
# MAIN SCRIPT
# ============================================

clear

echo -e "${PURPLE}${BOLD}"
echo "==============================================================="
echo "                                                               "
echo "     X   X  RRRR    AAA   Y   Y                                "
echo "      X X   R   R  A   A   Y Y                                 "
echo "       X    RRRR   AAAAA    Y                                  "
echo "      X X   R  R   A   A    Y                                  "
echo "     X   X  R   R  A   A    Y                                  "
echo "                                                               "
echo "             EZxray - STEALTH EDITION (REALITY)                "
echo "      12 PROTOCOLS | Anti-DPI VLESS-REALITY-Vision             "
echo "        Version 2.1.0 - STEALTH ULTRA + BBR + SUB/QR           "
echo "                                                               "
echo "==============================================================="
echo -e "${NC}"

matrix_effect

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[X] Run as root!${NC}"
    exit 1
fi

echo -e "${CYAN}Installing required tools...${NC}"
apt-get update -qq 2>/dev/null
apt-get install -y xclip xsel net-tools iproute2 netcat-openbsd curl uuid-runtime openssl qrencode python3 2>/dev/null

# Detect clipboard
if command -v xclip &> /dev/null; then
    CLIP_CMD="xclip -selection clipboard"
elif command -v xsel &> /dev/null; then
    CLIP_CMD="xsel --clipboard"
elif command -v pbcopy &> /dev/null; then
    CLIP_CMD="pbcopy"
else
    CLIP_CMD="cat"
fi

echo -e "${CYAN}${BOLD}EZxray STEALTH FEATURES ACTIVATED:${NC}"
echo -e "${GREEN}  + VLESS-REALITY-Vision (Anti-DPI, no domain needed)"
echo -e "${GREEN}  + Borrows real TLS handshake (looks like normal HTTPS)"
echo -e "${GREEN}  + Resistant to active probing"
echo -e "${GREEN}  + 12 Protocols total (3 Reality + WS fallbacks)"
echo -e "${GREEN}  + systemd Service (auto-restart, reboot-safe)"
echo -e "${GREEN}  + BBR + TCP FastOpen (top connection performance)"
echo -e "${GREEN}  + Subscription URL + QR codes (one-tap import)"
echo -e ""

# Public IP (best for share links)
SERVER_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null)
[ -z "$SERVER_IP" ] && SERVER_IP=$(hostname -I | awk '{print $1}')
[ -z "$SERVER_IP" ] && SERVER_IP="127.0.0.1"

echo -e "${PURPLE}${BOLD}SYSTEM INFORMATION${NC}"
echo -e "${GREEN}---------------------------------------------${NC}"
echo -e "${GREEN}IP: ${BOLD}${SERVER_IP}${NC}"

CPU=$(nproc)
RAM=$(free -m | awk '/^Mem:/{print $2}')
if [ "$CPU" -gt 8 ] && [ "$RAM" -gt 8192 ]; then
    OPTIMIZATION="GOD MODE - Maximum Performance"
elif [ "$CPU" -gt 4 ] && [ "$RAM" -gt 4096 ]; then
    OPTIMIZATION="ULTRA MODE - High Performance"
elif [ "$CPU" -gt 2 ] && [ "$RAM" -gt 2048 ]; then
    OPTIMIZATION="BALANCED MODE - Optimal"
else
    OPTIMIZATION="LIGHTWEIGHT MODE - Efficient"
fi
echo -e "${GREEN}AI Mode: ${BOLD}${OPTIMIZATION}${NC}"
echo -e "${GREEN}${BOLD}---------------------------------------------${NC}"

# ============================================
# PORTS SELECTION
# ============================================
echo -e "\n${PURPLE}${BOLD}SELECTING PORTS${NC}"
ALL_PORTS=(443 8443 8080 2096 2053 2083 2087 2095 8444 8445 8446 8447 8448 8449 8450 8081 8082 8083 8084 8085)

AVAILABLE_PORTS=()
for port in "${ALL_PORTS[@]}"; do
    if ! port_in_use "$port"; then
        AVAILABLE_PORTS+=("$port")
    fi
done

if [ ${#AVAILABLE_PORTS[@]} -lt 12 ]; then
    echo -e "${YELLOW}[!] Not enough free ports. Using full list...${NC}"
    AVAILABLE_PORTS=("${ALL_PORTS[@]}")
fi

# Ensure port 443 (best disguise for REALITY) is first if available
if [[ " ${AVAILABLE_PORTS[*]} " == *" 443 "* ]]; then
    AVAILABLE_PORTS=(443 $(printf '%s\n' "${AVAILABLE_PORTS[@]}" | grep -vx 443))
fi

SELECTED_PORTS=()
for i in {0..11}; do
    if [ "$i" -lt ${#AVAILABLE_PORTS[@]} ]; then
        SELECTED_PORTS+=("${AVAILABLE_PORTS[$i]}")
    else
        SELECTED_PORTS+=($((8000 + i)))
    fi
done

# Reality on the first 3 VLESS slots (443 + 2 others)
PORT_REALITY=${SELECTED_PORTS[0]}
PORT_VMESS=${SELECTED_PORTS[1]}
PORT_TROJAN=${SELECTED_PORTS[2]}
PORT_SS=${SELECTED_PORTS[3]}
PORT_REALITY2=${SELECTED_PORTS[4]}
PORT_VMESS2=${SELECTED_PORTS[5]}
PORT_TROJAN2=${SELECTED_PORTS[6]}
PORT_SS2=${SELECTED_PORTS[7]}
PORT_REALITY3=${SELECTED_PORTS[8]}
PORT_VMESS3=${SELECTED_PORTS[9]}
PORT_TROJAN3=${SELECTED_PORTS[10]}
PORT_SS3=${SELECTED_PORTS[11]}

echo -e "${GREEN}[OK] Ports selected (Reality first): ${SELECTED_PORTS[*]}${NC}"

# ============================================
# GENERATE KEYS
# ============================================
echo -e "\n${PURPLE}${BOLD}GENERATING KEYS${NC}"
loading_animation "Generating UUIDs and passwords"

VLESS_UUID=$(uuidgen)
VLESS_UUID2=$(uuidgen)
VLESS_UUID3=$(uuidgen)
VMESS_UUID=$(uuidgen)
VMESS_UUID2=$(uuidgen)
VMESS_UUID3=$(uuidgen)

gen_pass() { tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32; }
TROJAN_PASS=$(gen_pass)
SS_PASS=$(gen_pass | head -c 24)
TROJAN_PASS2=$(gen_pass)
SS_PASS2=$(gen_pass | head -c 24)
TROJAN_PASS3=$(gen_pass)
SS_PASS3=$(gen_pass | head -c 24)

PATH_TROJAN=$(gen_pass | head -c 12)
PATH_TROJAN2=$(gen_pass | head -c 12)
PATH_TROJAN3=$(gen_pass | head -c 12)

# REALITY shortIds (1-16 hex chars). Use random 8-byte hex.
SHORTID=$(openssl rand -hex 8)
SHORTID2=$(openssl rand -hex 8)
SHORTID3=$(openssl rand -hex 8)

# STEALTH: pick the best "borrow" domains live (see SNI_CANDIDATES above).
# This avoids hardcoding microsoft/google/apple, which a censor may have
# already poisoned for this route. We test reachability + TLS1.3 + X25519.
echo -e "${CYAN}Auto-selecting best SNI domains (live test from this server)...${NC}"
BEST_SNIS=$(pick_best_snis)
read -r SNI_TARGET SNI_TARGET2 SNI_TARGET3 <<< "$BEST_SNIS"

# Safe fallbacks if live testing found nothing (e.g. openssl missing / no net yet)
[ -z "$SNI_TARGET" ]  && SNI_TARGET="www.microsoft.com"
[ -z "$SNI_TARGET2" ] && SNI_TARGET2="$SNI_TARGET"
[ -z "$SNI_TARGET3" ] && SNI_TARGET3="$SNI_TARGET"
echo -e "${GREEN}[OK] Selected SNIs: ${SNI_TARGET}, ${SNI_TARGET2}, ${SNI_TARGET3}${NC}"

echo -e "${GREEN}[OK] Keys generated!${NC}"

# ============================================
# CLEAN & INSTALL
# ============================================
loading_animation "Cleaning old services"
systemctl stop xray 2>/dev/null
pkill -f "xray run" 2>/dev/null
for port in "${SELECTED_PORTS[@]}"; do
    fuser -k "${port}/tcp" 2>/dev/null
done
sleep 2

loading_animation "Installing Xray Core"
if ! command -v xray &> /dev/null; then
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install > /dev/null 2>&1
fi

XRAY_BIN=$(command -v xray || echo /usr/local/bin/xray)
if [ ! -x "$XRAY_BIN" ]; then
    echo -e "${RED}[X] Xray installation failed. Check your network/connection.${NC}"
    exit 1
fi

# ============================================
# REALITY KEY PAIR (generated by Xray itself)
# ============================================
loading_animation "Generating REALITY x25519 key pair"
REALITY_KEYS=$("$XRAY_BIN" x25519 2>/dev/null)
# Xray prints "Private key:"/"PrivateKey:" and "Public key:"/"Password:" depending on version.
REALITY_PRIVATE=$(echo "$REALITY_KEYS" | grep -iE 'private' | awk -F: '{print $2}' | tr -d ' ')
REALITY_PUBLIC=$(echo "$REALITY_KEYS" | grep -iE 'public|password' | awk -F: '{print $2}' | tr -d ' ')

if [ -z "$REALITY_PRIVATE" ] || [ -z "$REALITY_PUBLIC" ]; then
    echo -e "${RED}[X] Failed to generate REALITY keys. Xray output was:${NC}"
    echo "$REALITY_KEYS"
    exit 1
fi
echo -e "${GREEN}[OK] REALITY key pair ready!${NC}"

# ============================================
# GENERATE CONFIG
# ============================================
loading_animation "Generating STEALTH configuration"
mkdir -p /usr/local/xray
mkdir -p /var/log/xray
touch /var/log/xray/access.log /var/log/xray/error.log

cat > /usr/local/xray/config.json <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": ${PORT_REALITY},
      "protocol": "vless",
      "settings": {
        "clients": [{"id": "${VLESS_UUID}", "flow": "xtls-rprx-vision", "email": "reality1@${SERVER_IP}"}],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${SNI_TARGET}:443",
          "xver": 0,
          "serverNames": ["${SNI_TARGET}"],
          "privateKey": "${REALITY_PRIVATE}",
          "shortIds": ["", "${SHORTID}"]
        }
      },
      "sniffing": {"enabled": true, "destOverride": ["http", "tls", "quic"]}
    },
    {
      "listen": "0.0.0.0",
      "port": ${PORT_VMESS},
      "protocol": "vmess",
      "settings": {"clients": [{"id": "${VMESS_UUID}", "alterId": 0, "email": "vmess1@${SERVER_IP}"}]},
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/${VMESS_UUID}/vmess1"}, "security": "none"},
      "sniffing": {"enabled": true, "destOverride": ["http", "tls", "quic"]}
    },
    {
      "listen": "0.0.0.0",
      "port": ${PORT_TROJAN},
      "protocol": "trojan",
      "settings": {"clients": [{"password": "${TROJAN_PASS}", "email": "trojan1@${SERVER_IP}"}]},
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/${PATH_TROJAN}/trojan1"}, "security": "none"},
      "sniffing": {"enabled": true, "destOverride": ["http", "tls", "quic"]}
    },
    {
      "listen": "0.0.0.0",
      "port": ${PORT_SS},
      "protocol": "shadowsocks",
      "settings": {"clients": [{"password": "${SS_PASS}", "method": "chacha20-ietf-poly1305", "email": "ss1@${SERVER_IP}"}], "network": "tcp,udp"}
    },
    {
      "listen": "0.0.0.0",
      "port": ${PORT_REALITY2},
      "protocol": "vless",
      "settings": {
        "clients": [{"id": "${VLESS_UUID2}", "flow": "xtls-rprx-vision", "email": "reality2@${SERVER_IP}"}],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${SNI_TARGET2}:443",
          "xver": 0,
          "serverNames": ["${SNI_TARGET2}"],
          "privateKey": "${REALITY_PRIVATE}",
          "shortIds": ["", "${SHORTID2}"]
        }
      },
      "sniffing": {"enabled": true, "destOverride": ["http", "tls", "quic"]}
    },
    {
      "listen": "0.0.0.0",
      "port": ${PORT_VMESS2},
      "protocol": "vmess",
      "settings": {"clients": [{"id": "${VMESS_UUID2}", "alterId": 0, "email": "vmess2@${SERVER_IP}"}]},
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/${VMESS_UUID2}/vmess2"}, "security": "none"},
      "sniffing": {"enabled": true, "destOverride": ["http", "tls", "quic"]}
    },
    {
      "listen": "0.0.0.0",
      "port": ${PORT_TROJAN2},
      "protocol": "trojan",
      "settings": {"clients": [{"password": "${TROJAN_PASS2}", "email": "trojan2@${SERVER_IP}"}]},
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/${PATH_TROJAN2}/trojan2"}, "security": "none"},
      "sniffing": {"enabled": true, "destOverride": ["http", "tls", "quic"]}
    },
    {
      "listen": "0.0.0.0",
      "port": ${PORT_SS2},
      "protocol": "shadowsocks",
      "settings": {"clients": [{"password": "${SS_PASS2}", "method": "chacha20-ietf-poly1305", "email": "ss2@${SERVER_IP}"}], "network": "tcp,udp"}
    },
    {
      "listen": "0.0.0.0",
      "port": ${PORT_REALITY3},
      "protocol": "vless",
      "settings": {
        "clients": [{"id": "${VLESS_UUID3}", "flow": "xtls-rprx-vision", "email": "reality3@${SERVER_IP}"}],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${SNI_TARGET3}:443",
          "xver": 0,
          "serverNames": ["${SNI_TARGET3}"],
          "privateKey": "${REALITY_PRIVATE}",
          "shortIds": ["", "${SHORTID3}"]
        }
      },
      "sniffing": {"enabled": true, "destOverride": ["http", "tls", "quic"]}
    },
    {
      "listen": "0.0.0.0",
      "port": ${PORT_VMESS3},
      "protocol": "vmess",
      "settings": {"clients": [{"id": "${VMESS_UUID3}", "alterId": 0, "email": "vmess3@${SERVER_IP}"}]},
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/${VMESS_UUID3}/vmess3"}, "security": "none"},
      "sniffing": {"enabled": true, "destOverride": ["http", "tls", "quic"]}
    },
    {
      "listen": "0.0.0.0",
      "port": ${PORT_TROJAN3},
      "protocol": "trojan",
      "settings": {"clients": [{"password": "${TROJAN_PASS3}", "email": "trojan3@${SERVER_IP}"}]},
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/${PATH_TROJAN3}/trojan3"}, "security": "none"},
      "sniffing": {"enabled": true, "destOverride": ["http", "tls", "quic"]}
    },
    {
      "listen": "0.0.0.0",
      "port": ${PORT_SS3},
      "protocol": "shadowsocks",
      "settings": {"clients": [{"password": "${SS_PASS3}", "method": "chacha20-ietf-poly1305", "email": "ss3@${SERVER_IP}"}], "network": "tcp,udp"}
    }
  ],
  "outbounds": [
    {"protocol": "freedom", "tag": "direct"},
    {"protocol": "blackhole", "tag": "block"}
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {"type": "field", "ip": ["geoip:private"], "outboundTag": "block"},
      {"type": "field", "protocol": ["bittorrent"], "outboundTag": "block"},
      {"type": "field", "domain": ["geosite:category-ads-all"], "outboundTag": "block"}
    ]
  }
}
EOF

# Validate before launching
if ! "$XRAY_BIN" run -test -config /usr/local/xray/config.json > /tmp/xray-test.log 2>&1; then
    echo -e "${RED}[X] Generated config failed validation:${NC}"
    cat /tmp/xray-test.log
    exit 1
fi
echo -e "${GREEN}[OK] Configuration validated successfully!${NC}"

# ============================================
# SYSTEMD SERVICE
# ============================================
loading_animation "Installing systemd service"
cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=EZxray STEALTH Service
After=network.target nss-lookup.target

[Service]
Type=simple
ExecStart=${XRAY_BIN} run -config /usr/local/xray/config.json
Restart=on-failure
RestartSec=3
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xray > /dev/null 2>&1
systemctl restart xray
sleep 3

if systemctl is-active --quiet xray; then
    echo -e "${GREEN}[OK] Xray STEALTH is running!${NC}"
else
    echo -e "${RED}[X] Xray failed to start. Check: journalctl -u xray -n 50${NC}"
    journalctl -u xray -n 20 --no-pager 2>/dev/null
    exit 1
fi

# ============================================
# FIREWALL
# ============================================
loading_animation "Configuring Firewall"
for port in "${SELECTED_PORTS[@]}"; do
    ufw allow "${port}/tcp" 2>/dev/null
    iptables -I INPUT -p tcp --dport "${port}" -j ACCEPT 2>/dev/null
done

# ============================================
# NETWORK PERFORMANCE TUNING (BBR + buffers + TFO)
# ============================================
# Applied system-wide so EVERY protocol/connection benefits, not just one.
loading_animation "Optimizing network (BBR + TCP tuning)"
modprobe tcp_bbr 2>/dev/null
echo "tcp_bbr" > /etc/modules-load.d/bbr.conf 2>/dev/null

cat > /etc/sysctl.d/99-xray-performance.conf <<'SYSCTL'
# --- Congestion control: Google BBR + fair queue (lower latency, higher throughput) ---
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
# --- TCP Fast Open for both client and server (faster connection setup) ---
net.ipv4.tcp_fastopen = 3
# --- Larger socket buffers for high throughput / high-latency links ---
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.rmem_default = 1048576
net.core.wmem_default = 1048576
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 65535
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
# --- Connection handling / latency ---
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_keepalive_time = 600
net.ipv4.ip_local_port_range = 1024 65535
# --- File handles ---
fs.file-max = 1000000
SYSCTL

sysctl --system >/dev/null 2>&1
ACTIVE_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
if [ "$ACTIVE_CC" = "bbr" ]; then
    echo -e "${GREEN}[OK] BBR active. Connection performance optimized.${NC}"
else
    echo -e "${YELLOW}[!] BBR not active yet (current: ${ACTIVE_CC}). A reboot may be needed to load tcp_bbr.${NC}"
fi

# ============================================
# GENERATE SHARE LINKS
# ============================================
FANCY_NAME=$(generate_fancy_name)

# REALITY links (the stealthy ones) - fp=chrome fingerprint mimics a real browser
REALITY_CONFIG="vless://${VLESS_UUID}@${SERVER_IP}:${PORT_REALITY}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SNI_TARGET}&fp=chrome&pbk=${REALITY_PUBLIC}&sid=${SHORTID}&type=tcp&headerType=none#${FANCY_NAME}-REALITY-1"
REALITY_CONFIG2="vless://${VLESS_UUID2}@${SERVER_IP}:${PORT_REALITY2}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SNI_TARGET2}&fp=chrome&pbk=${REALITY_PUBLIC}&sid=${SHORTID2}&type=tcp&headerType=none#${FANCY_NAME}-REALITY-2"
REALITY_CONFIG3="vless://${VLESS_UUID3}@${SERVER_IP}:${PORT_REALITY3}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SNI_TARGET3}&fp=chrome&pbk=${REALITY_PUBLIC}&sid=${SHORTID3}&type=tcp&headerType=none#${FANCY_NAME}-REALITY-3"

# VMESS
VMESS_JSON="{\"v\":\"2\",\"ps\":\"${FANCY_NAME}-VMESS-1\",\"add\":\"${SERVER_IP}\",\"port\":\"${PORT_VMESS}\",\"id\":\"${VMESS_UUID}\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/${VMESS_UUID}/vmess1\",\"type\":\"none\",\"host\":\"${SERVER_IP}\",\"tls\":\"none\"}"
VMESS_CONFIG="vmess://$(echo -n "$VMESS_JSON" | base64 -w 0)"
VMESS_JSON2="{\"v\":\"2\",\"ps\":\"${FANCY_NAME}-VMESS-2\",\"add\":\"${SERVER_IP}\",\"port\":\"${PORT_VMESS2}\",\"id\":\"${VMESS_UUID2}\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/${VMESS_UUID2}/vmess2\",\"type\":\"none\",\"host\":\"${SERVER_IP}\",\"tls\":\"none\"}"
VMESS_CONFIG2="vmess://$(echo -n "$VMESS_JSON2" | base64 -w 0)"
VMESS_JSON3="{\"v\":\"2\",\"ps\":\"${FANCY_NAME}-VMESS-3\",\"add\":\"${SERVER_IP}\",\"port\":\"${PORT_VMESS3}\",\"id\":\"${VMESS_UUID3}\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/${VMESS_UUID3}/vmess3\",\"type\":\"none\",\"host\":\"${SERVER_IP}\",\"tls\":\"none\"}"
VMESS_CONFIG3="vmess://$(echo -n "$VMESS_JSON3" | base64 -w 0)"

# Trojan
TROJAN_CONFIG="trojan://${TROJAN_PASS}@${SERVER_IP}:${PORT_TROJAN}?path=%2F${PATH_TROJAN}%2Ftrojan1&type=ws&security=none&host=${SERVER_IP}#${FANCY_NAME}-TROJAN-1"
TROJAN_CONFIG2="trojan://${TROJAN_PASS2}@${SERVER_IP}:${PORT_TROJAN2}?path=%2F${PATH_TROJAN2}%2Ftrojan2&type=ws&security=none&host=${SERVER_IP}#${FANCY_NAME}-TROJAN-2"
TROJAN_CONFIG3="trojan://${TROJAN_PASS3}@${SERVER_IP}:${PORT_TROJAN3}?path=%2F${PATH_TROJAN3}%2Ftrojan3&type=ws&security=none&host=${SERVER_IP}#${FANCY_NAME}-TROJAN-3"

# Shadowsocks
SS_CONFIG="ss://$(echo -n "chacha20-ietf-poly1305:${SS_PASS}" | base64 -w 0)@${SERVER_IP}:${PORT_SS}#${FANCY_NAME}-SS-1"
SS_CONFIG2="ss://$(echo -n "chacha20-ietf-poly1305:${SS_PASS2}" | base64 -w 0)@${SERVER_IP}:${PORT_SS2}#${FANCY_NAME}-SS-2"
SS_CONFIG3="ss://$(echo -n "chacha20-ietf-poly1305:${SS_PASS3}" | base64 -w 0)@${SERVER_IP}:${PORT_SS3}#${FANCY_NAME}-SS-3"

# ============================================
# BACKUP
# ============================================
BACKUP_DIR="/root/xray-backups"
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="${BACKUP_DIR}/xray_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
tar -czf "$BACKUP_FILE" -C /usr/local/xray config.json 2>/dev/null

# ============================================
# SUBSCRIPTION + QR CODES
# ============================================
loading_animation "Building subscription link and QR codes"

# All share links in one variable (REALITY first)
ALL_CONFIGS="${REALITY_CONFIG}
${REALITY_CONFIG2}
${REALITY_CONFIG3}
${VMESS_CONFIG}
${TROJAN_CONFIG}
${SS_CONFIG}
${VMESS_CONFIG2}
${TROJAN_CONFIG2}
${SS_CONFIG2}
${VMESS_CONFIG3}
${TROJAN_CONFIG3}
${SS_CONFIG3}"

# Standard subscription format = base64 of newline-joined links
SUB_DIR="/usr/local/xray/sub"
mkdir -p "$SUB_DIR"
SUB_TOKEN=$(openssl rand -hex 12)
printf '%s\n' "$ALL_CONFIGS" | base64 -w 0 > "${SUB_DIR}/${SUB_TOKEN}.txt"
cp "${SUB_DIR}/${SUB_TOKEN}.txt" /root/xray-subscription-base64.txt

# Pick a leftover port (not used by a protocol) for the subscription HTTP service
SUB_PORT=$(comm -23 <(printf '%s\n' "${ALL_PORTS[@]}" | sort -un) <(printf '%s\n' "${SELECTED_PORTS[@]}" | sort -un) | head -1)
[ -z "$SUB_PORT" ] && SUB_PORT=10080

# Serve the subscription over HTTP (token in the path acts as the secret)
SUB_URL=""
if command -v python3 &>/dev/null; then
    cat > /etc/systemd/system/xray-sub.service <<SVC
[Unit]
Description=EZxray Subscription Server
After=network.target

[Service]
Type=simple
ExecStart=$(command -v python3) -m http.server ${SUB_PORT} --bind 0.0.0.0 --directory ${SUB_DIR}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SVC
    systemctl daemon-reload
    systemctl enable xray-sub >/dev/null 2>&1
    systemctl restart xray-sub
    ufw allow "${SUB_PORT}/tcp" 2>/dev/null
    iptables -I INPUT -p tcp --dport "${SUB_PORT}" -j ACCEPT 2>/dev/null
    SUB_URL="http://${SERVER_IP}:${SUB_PORT}/${SUB_TOKEN}.txt"
fi

# Generate QR code PNGs for every config (easy mobile import)
QR_DIR="/root/xray-qr"
mkdir -p "$QR_DIR"
if command -v qrencode &>/dev/null; then
    qr_i=1
    for cfg in "$REALITY_CONFIG" "$REALITY_CONFIG2" "$REALITY_CONFIG3" \
               "$VMESS_CONFIG" "$TROJAN_CONFIG" "$SS_CONFIG" \
               "$VMESS_CONFIG2" "$TROJAN_CONFIG2" "$SS_CONFIG2" \
               "$VMESS_CONFIG3" "$TROJAN_CONFIG3" "$SS_CONFIG3"; do
        echo -n "$cfg" | qrencode -o "${QR_DIR}/config-${qr_i}.png" 2>/dev/null
        qr_i=$((qr_i+1))
    done
    [ -n "$SUB_URL" ] && echo -n "$SUB_URL" | qrencode -o "${QR_DIR}/subscription.png" 2>/dev/null
fi

# ============================================
# FINAL DISPLAY
# ============================================
clear
echo -e "${PURPLE}${BOLD}"
echo "==============================================================="
echo "          EZxray STEALTH EDITION - REALITY READY              "
echo "                  ${FANCY_NAME}"
echo "==============================================================="
echo -e "${NC}"

echo -e "${GREEN}IP:${NC} ${CYAN}${BOLD}${SERVER_IP}${NC}"
echo -e "${GREEN}REALITY Public Key:${NC} ${WHITE}${REALITY_PUBLIC}${NC}"
echo -e "${GREEN}AI Mode:${NC} ${OPTIMIZATION}"
echo -e "${GREEN}Network:${NC} BBR + TCP FastOpen (optimized for speed)"
echo -e "${GREEN}Ports:${NC} ${BOLD}${SELECTED_PORTS[*]}${NC}"
[ -n "$SUB_URL" ] && echo -e "${GREEN}Subscription URL:${NC} ${CYAN}${BOLD}${SUB_URL}${NC}"

echo -e "\n${YELLOW}${BOLD}=== STEALTH CONFIGS (RECOMMENDED - Anti-DPI) ===${NC}\n"
echo -e "${GREEN}${BOLD}1) VLESS-REALITY (Port ${PORT_REALITY}, SNI ${SNI_TARGET})${NC}"
echo -e "${WHITE}${REALITY_CONFIG}${NC}\n"
echo -e "${GREEN}${BOLD}2) VLESS-REALITY (Port ${PORT_REALITY2}, SNI ${SNI_TARGET2})${NC}"
echo -e "${WHITE}${REALITY_CONFIG2}${NC}\n"
echo -e "${GREEN}${BOLD}3) VLESS-REALITY (Port ${PORT_REALITY3}, SNI ${SNI_TARGET3})${NC}"
echo -e "${WHITE}${REALITY_CONFIG3}${NC}\n"

echo -e "${YELLOW}${BOLD}=== FALLBACK CONFIGS (WS, no TLS) ===${NC}\n"
echo -e "${GREEN}4) VMESS (Port ${PORT_VMESS})${NC}\n${WHITE}${VMESS_CONFIG}${NC}\n"
echo -e "${GREEN}5) Trojan (Port ${PORT_TROJAN})${NC}\n${WHITE}${TROJAN_CONFIG}${NC}\n"
echo -e "${GREEN}6) Shadowsocks (Port ${PORT_SS})${NC}\n${WHITE}${SS_CONFIG}${NC}\n"
echo -e "${GREEN}7) VMESS 2 (Port ${PORT_VMESS2})${NC}\n${WHITE}${VMESS_CONFIG2}${NC}\n"
echo -e "${GREEN}8) Trojan 2 (Port ${PORT_TROJAN2})${NC}\n${WHITE}${TROJAN_CONFIG2}${NC}\n"
echo -e "${GREEN}9) Shadowsocks 2 (Port ${PORT_SS2})${NC}\n${WHITE}${SS_CONFIG2}${NC}\n"
echo -e "${GREEN}10) VMESS 3 (Port ${PORT_VMESS3})${NC}\n${WHITE}${VMESS_CONFIG3}${NC}\n"
echo -e "${GREEN}11) Trojan 3 (Port ${PORT_TROJAN3})${NC}\n${WHITE}${TROJAN_CONFIG3}${NC}\n"
echo -e "${GREEN}12) Shadowsocks 3 (Port ${PORT_SS3})${NC}\n${WHITE}${SS_CONFIG3}${NC}\n"

# Subscription QR (one scan imports ALL configs into the client)
if [ -n "$SUB_URL" ] && command -v qrencode &>/dev/null; then
    echo -e "${YELLOW}${BOLD}=== SUBSCRIPTION (scan to import ALL configs) ===${NC}"
    echo -n "$SUB_URL" | qrencode -t ANSIUTF8 2>/dev/null
    echo -e "${GREEN}Sub URL:${NC} ${CYAN}${SUB_URL}${NC}"
    echo -e "${GREEN}Per-config QR PNGs saved in:${NC} ${QR_DIR}/\n"
fi

# ============================================
# COPY MENU
# ============================================
echo -e "${YELLOW}${BOLD}=== COPY MENU ===${NC}"
echo -e "${GREEN}1) Copy ALL Configs   2) Copy Specific   3) Skip${NC}"
echo -ne "${CYAN}Choose option (1-3): ${NC}"
read -r choice

case $choice in
    1)
        echo -e "\n${WHITE}${ALL_CONFIGS}${NC}"
        copy_to_clipboard "$ALL_CONFIGS" "ALL"
        ;;
    2)
        echo -ne "${CYAN}Enter config number (1-12): ${NC}"
        read -r num
        case $num in
            1) copy_to_clipboard "$REALITY_CONFIG" "REALITY-1" ;;
            2) copy_to_clipboard "$REALITY_CONFIG2" "REALITY-2" ;;
            3) copy_to_clipboard "$REALITY_CONFIG3" "REALITY-3" ;;
            4) copy_to_clipboard "$VMESS_CONFIG" "VMESS-1" ;;
            5) copy_to_clipboard "$TROJAN_CONFIG" "Trojan-1" ;;
            6) copy_to_clipboard "$SS_CONFIG" "SS-1" ;;
            7) copy_to_clipboard "$VMESS_CONFIG2" "VMESS-2" ;;
            8) copy_to_clipboard "$TROJAN_CONFIG2" "Trojan-2" ;;
            9) copy_to_clipboard "$SS_CONFIG2" "SS-2" ;;
            10) copy_to_clipboard "$VMESS_CONFIG3" "VMESS-3" ;;
            11) copy_to_clipboard "$TROJAN_CONFIG3" "Trojan-3" ;;
            12) copy_to_clipboard "$SS_CONFIG3" "SS-3" ;;
            *) echo -e "${RED}Invalid number${NC}" ;;
        esac
        ;;
    3) echo -e "${GREEN}[OK] Skipped${NC}" ;;
    *) echo -e "${RED}[X] Invalid option${NC}" ;;
esac

# ============================================
# MANAGEMENT
# ============================================
echo -e "\n${CYAN}${BOLD}=== MANAGEMENT COMMANDS ===${NC}"
echo -e "${PURPLE}Start:${NC}   ${WHITE}systemctl start xray${NC}"
echo -e "${PURPLE}Stop:${NC}    ${WHITE}systemctl stop xray${NC}"
echo -e "${PURPLE}Restart:${NC} ${WHITE}systemctl restart xray${NC}"
echo -e "${PURPLE}Status:${NC}  ${WHITE}systemctl status xray${NC}"
echo -e "${PURPLE}Logs:${NC}    ${WHITE}journalctl -u xray -f${NC}"
echo -e "${PURPLE}Ports:${NC}   ${WHITE}ss -tulpn | grep xray${NC}"
echo -e "${PURPLE}Sub server:${NC} ${WHITE}systemctl status xray-sub${NC}"
echo -e "${PURPLE}BBR check:${NC}  ${WHITE}sysctl net.ipv4.tcp_congestion_control${NC}"

# ============================================
# SAVE TO FILE
# ============================================
cat > /root/xray-configs-stealth.txt <<EOF
===============================================================================
        EZxray STEALTH EDITION (REALITY) - CONFIG EXPORT
===============================================================================
Server IP: ${SERVER_IP}
Config Name: ${FANCY_NAME}
Generated: $(date '+%Y-%m-%d %H:%M:%S')
AI Mode: ${OPTIMIZATION}
REALITY Public Key: ${REALITY_PUBLIC}
Selected Ports: ${SELECTED_PORTS[*]}
Subscription URL: ${SUB_URL}
QR codes (PNG): /root/xray-qr/
Network: BBR + TCP FastOpen enabled

=== STEALTH CONFIGS (RECOMMENDED - Anti-DPI, no domain needed) ===

1) VLESS-REALITY (Port ${PORT_REALITY}, SNI ${SNI_TARGET}):
${REALITY_CONFIG}

2) VLESS-REALITY (Port ${PORT_REALITY2}, SNI ${SNI_TARGET2}):
${REALITY_CONFIG2}

3) VLESS-REALITY (Port ${PORT_REALITY3}, SNI ${SNI_TARGET3}):
${REALITY_CONFIG3}

=== FALLBACK CONFIGS (WebSocket, no TLS) ===

4) VMESS (Port ${PORT_VMESS}):
${VMESS_CONFIG}

5) Trojan (Port ${PORT_TROJAN}):
${TROJAN_CONFIG}

6) Shadowsocks (Port ${PORT_SS}):
${SS_CONFIG}

7) VMESS 2 (Port ${PORT_VMESS2}):
${VMESS_CONFIG2}

8) Trojan 2 (Port ${PORT_TROJAN2}):
${TROJAN_CONFIG2}

9) Shadowsocks 2 (Port ${PORT_SS2}):
${SS_CONFIG2}

10) VMESS 3 (Port ${PORT_VMESS3}):
${VMESS_CONFIG3}

11) Trojan 3 (Port ${PORT_TROJAN3}):
${TROJAN_CONFIG3}

12) Shadowsocks 3 (Port ${PORT_SS3}):
${SS_CONFIG3}

===============================================================================
NOTES
===============================================================================
- REALITY configs (1-3) are the most censorship-resistant. Prefer them.
- SNI targets are auto-selected live from this server (TLS1.3 + X25519).
- Subscription URL imports ALL configs at once and the client auto-updates.
- QR code PNGs for every config are in /root/xray-qr/.
- BBR + TCP FastOpen are enabled system-wide for best connection performance.
- To rotate identity, re-run this script (new keys/UUIDs each time).
- Management: systemctl {start|stop|restart|status} xray (and xray-sub)
===============================================================================
EOF

echo -e "\n${GREEN}[OK] All configs saved: /root/xray-configs-stealth.txt${NC}"
echo -e "${GREEN}[OK] Backup saved: ${BACKUP_FILE}${NC}"
echo -e "\n${PURPLE}${BOLD}=== SUCCESS! STEALTH MODE ACTIVE — USE REALITY CONFIGS (1-3) ===${NC}"
matrix_effect
echo -e "${YELLOW}${BOLD}EZxray STEALTH Edition - VLESS-REALITY-Vision${NC}\n"
