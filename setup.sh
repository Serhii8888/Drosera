#!/usr/bin/env bash
# =====================================================================
#  Drosera Node — менеджер українською (systemd-based)
#  Version: 3.0.0 (adapted)
# =====================================================================
set -Eeuo pipefail

# -----------------------------
# Кольори / UI
# -----------------------------
clrGreen=$'\033[0;32m'
clrCyan=$'\033[0;36m'
clrRed=$'\033[0;31m'
clrMag=$'\033[1;35m'
clrReset=$'\033[0m'
clrBold=$'\033[1m'
clrDim=$'\033[2m'

ok()   { echo -e "${clrGreen}[OK]${clrReset} ${*:-}"; }
info() { echo -e "${clrCyan}[INFO]${clrReset} ${*:-}"; }
err()  { echo -e "${clrRed}[ПОМИЛКА]${clrReset} ${*:-}"; }
hr()   { echo -e "${clrDim}────────────────────────────────────────────────────────${clrReset}"; }

# -----------------------------
# Конфіг / Шляхи
# -----------------------------
SCRIPT_VERSION="3.0.0"
SERVICE_NAME="drosera"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
DB_PATH="$HOME/.drosera.db"

# -----------------------------
# Повідомлення українською
# -----------------------------
tr() {
  case "$1" in
    deps_install) echo "Встановлення необхідних пакетів та інструментів..." ;;
    deps_done) echo "Залежності встановлені" ;;
    ports_cfg) echo "Налаштовую порти 31313/31314..." ;;
    port_open) echo "Порт відкрито" ;;
    port_already) echo "Порт вже відкритий" ;;
    start_node) echo "Запуск ноди Drosera..." ;;
    node_started) echo "Нода запущена" ;;
    logs_hint) echo "Перегляд логів (Ctrl+C для виходу)" ;;
    restarting) echo "Перезапуск сервісу..." ;;
    removed) echo "Нода видалена" ;;
    menu_title) echo "Drosera Node — менеджер" ;;
    m1_deps) echo "Встановити залежності" ;;
    m5_start) echo "Запустити ноду" ;;
    m6_status) echo "Статус ноди" ;;
    m7_logs) echo "Логи ноди" ;;
    m8_restart) echo "Перезапустити ноду" ;;
    m9_remove) echo "Видалити ноду" ;;
    press_enter) echo "Натисніть Enter для продовження..." ;;
    ask_priv) echo "Введіть приватний ключ EVM гаманця:" ;;
    bad_input) echo "Невірний ввід, спробуйте ще раз." ;;
  esac
}

# -----------------------------
# Перевірка та встановлення curl/jq
# -----------------------------
ensure_curl() { command -v curl >/dev/null 2>&1 || { info "curl не знайдено, встановлюю..."; sudo apt update && sudo apt install -y curl; }; }
ensure_jq()   { command -v jq   >/dev/null 2>&1 || { info "jq не знайдено, встановлюю...";   sudo apt update && sudo apt install -y jq;   }; }

# -----------------------------
# Залежності
# -----------------------------
install_dependencies() {
  info "$(tr deps_install)"
  sudo apt-get update && sudo apt-get upgrade -y
  sudo apt install -y curl ufw iptables build-essential git wget lz4 jq make gcc nano \
    automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev \
    libleveldb-dev tar clang bsdmainutils ncdu unzip
  info "$(tr ports_cfg)"
  for port in 31313 31314; do
    if ! sudo iptables -C INPUT -p tcp --dport $port -j ACCEPT 2>/dev/null; then
      sudo iptables -I INPUT -p tcp --dport $port -j ACCEPT
      ok "$(tr port_open): $port"
    else
      info "$(tr port_already): $port"
    fi
  done
  ok "$(tr deps_done)"
}

# -----------------------------
# Встановлення та запуск ноди
# -----------------------------
start_node() {
  info "$(tr start_node)"
  read -s -rp "$(tr ask_priv) " PRIV_KEY; echo
  export DROSERA_PRIVATE_KEY="$PRIV_KEY"
  sudo tee "$SERVICE_FILE" >/dev/null <<EOF
[Unit]
Description=drosera node service
After=network-online.target

[Service]
User=$USER
Restart=always
RestartSec=15
LimitNOFILE=65535
ExecStart=/usr/bin/drosera-operator node \
  --db-file-path $DB_PATH \
  --network-p2p-port 31313 \
  --server-port 31314 \
  --eth-rpc-url https://ethereum-hoodi-rpc.publicnode.com \
  --drosera-address 0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D \
  --eth-private-key $DROSERA_PRIVATE_KEY \
  --eth-chain-id 560048 \
  --listen-address 0.0.0.0

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable "$SERVICE_NAME"
  sudo systemctl restart "$SERVICE_NAME"
  ok "$(tr node_started)"
}

restart_node() { info "$(tr restarting)"; sudo systemctl restart "$SERVICE_NAME"; }
show_status() { systemctl status "$SERVICE_NAME" --no-pager || true; }
follow_logs() { info "$(tr logs_hint)"; journalctl -u "$SERVICE_NAME" -fn 200; }
remove_node() { info "$(tr removed)"; sudo systemctl stop "$SERVICE_NAME" || true; sudo systemctl disable "$SERVICE_NAME" || true; sudo rm -f "$SERVICE_FILE"; sudo systemctl daemon-reload || true; rm -rf "$HOME/my-drosera-trap" || true; ok "$(tr removed)"; }

# -----------------------------
# Меню
# -----------------------------
menu() {
  while true; do
    clear; hr
    echo -e "${clrBold}${clrMag}$(tr menu_title)${clrReset} ${clrDim}(v${SCRIPT_VERSION})${clrReset}\n"
    echo -e "${clrGreen}1)${clrReset} $(tr m1_deps)"
    echo -e "${clrGreen}2)${clrReset} $(tr m5_start)"
    echo -e "${clrGreen}3)${clrReset} $(tr m6_status)"
    echo -e "${clrGreen}4)${clrReset} $(tr m7_logs)"
    echo -e "${clrGreen}5)${clrReset} $(tr m8_restart)"
    echo -e "${clrGreen}6)${clrReset} $(tr m9_remove)"
    echo -e "${clrGreen}0)${clrReset} Вихід"
    hr
    read -rp "> " choice
    case "${choice:-}" in
      1) install_dependencies ;;
      2) start_node ;;
      3) show_status ;;
      4) follow_logs ;;
      5) restart_node ;;
      6) remove_node ;;
      0) exit 0 ;;
      *) err "$(tr bad_input)" ;;
    esac
    echo -e "\n$(tr press_enter)"; read -r
  done
}

# -----------------------------
# Точка входу
# -----------------------------
ensure_curl; ensure_jq; menu
