#!/bin/bash
# ============================================================
# EZtunnel - Domestic RELAY for EZxray (2-hop / bridge)
# Runs on the DOMESTIC (entry) server in Iran.
# Forwards each port to the FOREIGN (exit) EZxray server.
#
#   User --> THIS domestic server (fast IP) --> Foreign EZxray --> Internet
#
# In your client share links, only change the ADDRESS/host to this
# domestic server's IP. Port, UUID, SNI, pbk, sid stay the SAME,
# because REALITY/TLS is terminated on the foreign server.
# ============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
PURPLE='\033[0;35m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; BOLD='\033[1m'; NC='\033[0m'

# Default candidate ports (match EZxray's pool). Forwarding unused ones is harmless.
DEFAULT_PORTS="443 8443 8080 2096 2053 2083 2087 2095 8444 8445 8446 8447 8448 8449 8450 8081 8082 8083 8084 8085"

valid_host() {
    local h="$1"
    # IPv4
    [[ "$h" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && return 0
    # or a domain name
    [[ "$h" =~ ^[A-Za-z0-9._-]+\.[A-Za-z]{2,}$ ]] && return 0
    return 1
}

clear
echo -e "${PURPLE}${BOLD}"
echo "==============================================================="
echo "        EZtunnel - DOMESTIC RELAY for EZxray (2-hop)           "
echo "      User -> Domestic (this) -> Foreign EZxray -> Net         "
echo "==============================================================="
echo -e "${NC}"

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[X] Run as root!${NC}"
    exit 1
fi

# -------- Inputs --------
FOREIGN_HOST="$1"
while ! valid_host "$FOREIGN_HOST"; do
    echo -ne "${CYAN}Enter the FOREIGN (exit) server IP or domain: ${NC}"
    read -r FOREIGN_HOST
done

echo -ne "${CYAN}Ports to relay (space-separated) [Enter = default 20 ports]: ${NC}"
read -r PORTS_INPUT
PORTS="${PORTS_INPUT:-$DEFAULT_PORTS}"

echo -ne "${CYAN}Also relay a subscription port? Enter port number or leave empty: ${NC}"
read -r SUB_FWD_PORT
[ -n "$SUB_FWD_PORT" ] && PORTS="$PORTS $SUB_FWD_PORT"

echo -e "${GREEN}Foreign server:${NC} ${BOLD}${FOREIGN_HOST}${NC}"
echo -e "${GREEN}Relaying ports:${NC} ${PORTS}"

# -------- Tools --------
echo -e "${CYAN}Installing tools...${NC}"
apt-get update -qq 2>/dev/null
apt-get install -y curl iproute2 net-tools netcat-openbsd 2>/dev/null

# -------- Install Xray --------
echo -e "${CYAN}Installing Xray core...${NC}"
if ! command -v xray &>/dev/null; then
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >/dev/null 2>&1
fi
XRAY_BIN=$(command -v xray || echo /usr/local/bin/xray)
if [ ! -x "$XRAY_BIN" ]; then
    echo -e "${RED}[X] Xray installation failed. Check network.${NC}"
    exit 1
fi

# -------- Optional reachability check --------
FIRST_PORT=$(echo "$PORTS" | awk '{print $1}')
if command -v nc &>/dev/null; then
    if timeout 5 nc -z "$FOREIGN_HOST" "$FIRST_PORT" 2>/dev/null; then
        echo -e "${GREEN}[OK] Foreign server reachable on ${FIRST_PORT}.${NC}"
    else
        echo -e "${YELLOW}[!] Could not reach ${FOREIGN_HOST}:${FIRST_PORT} (check it's up / firewall). Continuing anyway.${NC}"
    fi
fi

# -------- Build dokodemo-door relay config --------
echo -e "${CYAN}Building relay configuration...${NC}"
mkdir -p /usr/local/xray /var/log/xray
touch /var/log/xray/access.log /var/log/xray/error.log

INBOUNDS=""
for p in $PORTS; do
    [[ "$p" =~ ^[0-9]+$ ]] || continue
    INBOUNDS+="{\"listen\":\"0.0.0.0\",\"port\":${p},\"protocol\":\"dokodemo-door\",\"settings\":{\"address\":\"${FOREIGN_HOST}\",\"port\":${p},\"network\":\"tcp,udp\",\"followRedirect\":false},\"tag\":\"relay-${p}\"},"
done
INBOUNDS="${INBOUNDS%,}"

cat > /usr/local/xray/config.json <<EOF
{
  "log": {"loglevel": "warning", "access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log"},
  "inbounds": [${INBOUNDS}],
  "outbounds": [{"protocol": "freedom", "tag": "direct", "settings": {"domainStrategy": "UseIP"}}]
}
EOF

if ! "$XRAY_BIN" run -test -config /usr/local/xray/config.json >/tmp/xray-relay-test.log 2>&1; then
    echo -e "${RED}[X] Relay config failed validation:${NC}"
    cat /tmp/xray-relay-test.log
    exit 1
fi
echo -e "${GREEN}[OK] Relay configuration validated!${NC}"

# -------- systemd service --------
cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=EZtunnel Relay (Xray dokodemo-door)
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
systemctl enable xray >/dev/null 2>&1
systemctl restart xray
sleep 3
if systemctl is-active --quiet xray; then
    echo -e "${GREEN}[OK] Relay is running!${NC}"
else
    echo -e "${RED}[X] Relay failed to start. Check: journalctl -u xray -n 50${NC}"
    journalctl -u xray -n 20 --no-pager 2>/dev/null
    exit 1
fi

# -------- Firewall --------
echo -e "${CYAN}Configuring firewall...${NC}"
for p in $PORTS; do
    [[ "$p" =~ ^[0-9]+$ ]] || continue
    ufw allow "${p}/tcp" 2>/dev/null
    ufw allow "${p}/udp" 2>/dev/null
    iptables -C INPUT -p tcp --dport "${p}" -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport "${p}" -j ACCEPT 2>/dev/null
    iptables -C INPUT -p udp --dport "${p}" -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport "${p}" -j ACCEPT 2>/dev/null
done

# Enable IP forwarding (needed for relaying)
sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
grep -q "net.ipv4.ip_forward" /etc/sysctl.conf 2>/dev/null || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# -------- Network performance tuning (BBR) --------
echo -e "${CYAN}Optimizing network (BBR + TCP tuning)...${NC}"
modprobe tcp_bbr 2>/dev/null
echo "tcp_bbr" > /etc/modules-load.d/bbr.conf 2>/dev/null
cat > /etc/sysctl.d/99-eztunnel-performance.conf <<'SYSCTL'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 65535
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
fs.file-max = 1000000
SYSCTL
sysctl --system >/dev/null 2>&1
ACTIVE_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
[ "$ACTIVE_CC" = "bbr" ] && echo -e "${GREEN}[OK] BBR active.${NC}" || echo -e "${YELLOW}[!] BBR not active (current: ${ACTIVE_CC}); a reboot may be needed.${NC}"

# -------- Result --------
DOMESTIC_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null)
[ -z "$DOMESTIC_IP" ] && DOMESTIC_IP=$(hostname -I | awk '{print $1}')

clear
echo -e "${PURPLE}${BOLD}"
echo "==============================================================="
echo "             EZtunnel RELAY - READY                            "
echo "==============================================================="
echo -e "${NC}"
echo -e "${GREEN}This (domestic) server IP:${NC} ${CYAN}${BOLD}${DOMESTIC_IP}${NC}"
echo -e "${GREEN}Forwarding to foreign:${NC}    ${BOLD}${FOREIGN_HOST}${NC}"
echo -e "${GREEN}Relayed ports:${NC} ${PORTS}"
echo -e "${GREEN}Network:${NC} BBR + TCP FastOpen"
echo ""
echo -e "${YELLOW}${BOLD}HOW TO USE ON CLIENTS:${NC}"
echo -e "${WHITE}Take your EZxray share links and change ONLY the server address"
echo -e "from the FOREIGN IP (${FOREIGN_HOST}) to THIS domestic IP (${DOMESTIC_IP}).${NC}"
echo -e "${WHITE}Keep port, UUID, SNI, pbk, sid EXACTLY the same.${NC}"
echo ""
echo -e "${CYAN}Example (REALITY):${NC}"
echo -e "${WHITE}  before: vless://UUID@${FOREIGN_HOST}:443?...sni=...&pbk=...&sid=...${NC}"
echo -e "${WHITE}  after:  vless://UUID@${DOMESTIC_IP}:443?...sni=...&pbk=...&sid=...${NC}"
echo ""
echo -e "${CYAN}${BOLD}MANAGEMENT:${NC}"
echo -e "${PURPLE}Status:${NC}  ${WHITE}systemctl status xray${NC}"
echo -e "${PURPLE}Restart:${NC} ${WHITE}systemctl restart xray${NC}"
echo -e "${PURPLE}Logs:${NC}    ${WHITE}journalctl -u xray -f${NC}"
echo -e "\n${GREEN}${BOLD}=== DONE! Domestic relay is live. ===${NC}\n"
