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
clrBlue=$'\033[0;34m'
clrRed=$'\033[0;31m'
clrYellow=$'\033[1;33m'
clrMag=$'\033[1;35m'
clrReset=$'\033[0m'
clrBold=$'\033[1m'
clrDim=$'\033[2m'

ok()   { echo -e "${clrGreen}[OK]${clrReset} ${*:-}"; }
info() { echo -e "${clrCyan}[INFO]${clrReset} ${*:-}"; }
warn() { echo -e "${clrYellow}[УВАГА]${clrReset} ${*:-}"; }
err()  { echo -e "${clrRed}[ПОМИЛКА]${clrReset} ${*:-}"; }
hr()   { echo -e "${clrDim}────────────────────────────────────────────────────────${clrReset}"; }

# -----------------------------
# Конфіг / Шляхи
# -----------------------------
SCRIPT_NAME="drosera"
SCRIPT_VERSION="3.0.0"
VERSIONS_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/versions.txt"
SCRIPT_FILE_URL="https://raw.githubusercontent.com/k2wGG/scripts/main/drosera-node-manager.sh"

SERVICE_NAME="drosera"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
HOME_BIN="$HOME/.drosera/bin/drosera-operator"
USR_BIN="/usr/bin/drosera-operator"
DB_PATH="$HOME/.drosera.db"

# -----------------------------
# Повідомлення українською
# -----------------------------
tr() {
  case "$1" in
    script_upd_check) echo "Перевірка оновлень скрипта..." ;;
    script_upd_found) echo "Знайдено нову версію скрипта" ;;
    script_upd_ok) echo "Скрипт актуальний" ;;
    need_curl) echo "curl не знайдено, встановлюю..." ;;
    need_jq) echo "jq не знайдено, встановлюю..." ;;
    deps_install) echo "Встановлення необхідних пакетів та інструментів..." ;;
    deps_done) echo "Залежності встановлені" ;;
    ports_cfg) echo "Налаштовую порти 31313/31314..." ;;
    port_open) echo "Порт відкрито" ;;
    port_already) echo "Порт вже відкритий" ;;
    latest_check) echo "Перевірка останньої версії drosera-operator..." ;;
    not_found_url) echo "Не вдалося отримати URL останнього релізу" ;;
    bin_updated) echo "drosera-operator оновлено у /usr/bin" ;;
    bin_missing) echo "Бінарний файл operator не знайдено після розпакування" ;;
    versions_title) echo "Версії та статус" ;;
    path_shown) echo "Шлях до бінарного файлу (перший у PATH)" ;;
    inst_ver) echo "Встановлена версія" ;;
    usrbin_ver) echo "Версія /usr/bin" ;;
    homebin_ver) echo "Версія ~/.drosera/bin" ;;
    latest_rel) echo "Останній реліз" ;;
    svc_status) echo "Статус сервісу" ;;
    running_bin) echo "Запущений бінарник" ;;
    running_ver) echo "Версія процесу" ;;
    node_not_running) echo "Нода не запущена." ;;
    update_avail) echo "Доступне оновлення" ;;
    update_node) echo "Оновлюю ноду до останньої версії та перезапускаю..." ;;
    updater_summary) echo "Поточні версії" ;;
    service_active) echo "Сервіс активний" ;;
    service_inactive) echo "Після оновлення сервіс не активний. Перевірте логи." ;;
    start_node) echo "Запуск ноди Drosera..." ;;
    node_started) echo "Нода запущена" ;;
    logs_hint) echo "Перегляд логів (Ctrl+C для виходу)" ;;
    restarting) echo "Перезапуск сервісу..." ;;
    removed) echo "Нода видалена" ;;
    menu_title) echo "Drosera Node — менеджер" ;;
    m1_deps) echo "Встановити залежності" ;;
    m2_deploy_trap) echo "Деплой трапу" ;;
    m3_install_node) echo "Встановити ноду" ;;
    m4_register) echo "Зареєструвати оператора" ;;
    m5_start) echo "Запустити ноду" ;;
    m6_status) echo "Статус ноди" ;;
    m7_logs) echo "Логи ноди" ;;
    m8_restart) echo "Перезапустити ноду" ;;
    m9_remove) echo "Видалити ноду" ;;
    m11_two) echo "Деплой двох трапів" ;;
    m12_versions) echo "Перевірити версії та статус" ;;
    m13_update) echo "Оновити ноду" ;;
    press_enter) echo "Натисніть Enter для продовження..." ;;
    enter_email) echo "Введіть вашу GitHub пошту:" ;;
    enter_user) echo "Введіть GitHub ім'я користувача:" ;;
    ask_whitelist) echo "Введіть адресу вашого EVM гаманця (для whitelist):" ;;
    ask_priv) echo "Введіть приватний ключ EVM гаманця:" ;;
    reg_done) echo "Реєстрація завершена." ;;
    removing) echo "Видалення ноди Drosera..." ;;
    bad_input) echo "Невірний ввід, спробуйте ще раз." ;;
  esac
}

# -----------------------------
# Перевірка та встановлення curl/jq
# -----------------------------
ensure_curl() { command -v curl >/dev/null 2>&1 || { info "$(tr need_curl)"; sudo apt update && sudo apt install -y curl; }; }
ensure_jq()   { command -v jq   >/dev/null 2>&1 || { info "$(tr need_jq)";   sudo apt update && sudo apt install -y jq;   }; }

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
ExecStart=$(get_drosera_operator) node \
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
remove_node() { info "$(tr removing)"; sudo systemctl stop "$SERVICE_NAME" || true; sudo systemctl disable "$SERVICE_NAME" || true; sudo rm -f "$SERVICE_FILE"; sudo systemctl daemon-reload || true; rm -rf "$HOME/my-drosera-trap" || true; ok "$(tr removed)"; }

# -----------------------------
# Меню
# -----------------------------
menu() {
  while true; do
    clear; hr
    echo -e "${clrBold}${clrMag}$(tr menu_title)${clrReset} ${clrDim}(v${SCRIPT_VERSION})${clrReset}\n"
    echo -e "${clrGreen}1)${clrReset} $(tr m1_deps)"
    echo -e "${clrGreen}2)${clrReset} $(tr m2_deploy_trap)"
    echo -e "${clrGreen}3)${clrReset} $(tr m3_install_node)"
    echo -e "${clrGreen}4)${clrReset} $(tr m4_register)"
    echo -e "${clrGreen}5)${clrReset} $(tr m5_start)"
    echo -e "${clrGreen}6)${clrReset} $(tr m6_status)"
    echo -e "${clrGreen}7)${clrReset} $(tr m7_logs)"
    echo -e "${clrGreen}8)${clrReset} $(tr m8_restart)"
    echo -e "${clrGreen}9)${clrReset} $(tr m9_remove)"
    echo -e "${clrGreen}11)${clrReset} $(tr m11_two)"
    echo -e "${clrGreen}12)${clrReset} $(tr m12_versions)"
    echo -e "${clrGreen}13)${clrReset} $(tr m13_update)"
    echo -e "${clrGreen}0)${clrReset} Вихід"
    hr
    read -rp "> " choice
    case "${choice:-}" in
      1) install_dependencies ;;
      5) start_node ;;
      6) show_status ;;
      7) follow_logs ;;
      8) restart_node ;;
      9) remove_node ;;
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
