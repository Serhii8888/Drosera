#!/bin/bash
set -e

# === Кольори для виводу ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# === Функції для виводу ===
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
step() { echo -e "${CYAN}=== $1 ===${NC}"; }

# === Визначення користувача ===
if [ "$EUID" -eq 0 ]; then
    MAIN_USER=$(logname 2>/dev/null || echo "root")
    USER_HOME=$(eval echo ~$MAIN_USER)
    warning "Запуск під root! Буде використано користувача: $MAIN_USER"
else
    MAIN_USER=$USER
    USER_HOME=$HOME
    info "Запуск під звичайного користувача: $MAIN_USER"
fi

# === Функції для роботи з користувачем ===
run_as_user() {
    sudo -u $MAIN_USER bash -c "$1"
}

export_for_user() {
    echo "export $1=\"$2\"" >> "$USER_HOME/.bashrc"
    run_as_user "export $1=\"$2\""
}

# === Користувацькі дані ===
step "Введення даних для налаштування"
read -rp "Введіть свій GitHub email: " GITHUB_EMAIL
read -rp "Введіть свій GitHub username: " GITHUB_USERNAME
read -s -rp "Введіть приватний ключ (PRIVATE_KEY) для drosera: " DROSERA_PRIVATE_KEY
echo
read -rp "Введіть адресу вашого EVM гаманця (для whitelist): " OPERATOR_ADDR

# === Оновлення системи ===
step "Оновлення системи"
apt-get update && apt-get upgrade -y

# === Базові пакети ===
step "Встановлення базових пакетів"
apt install -y curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop \
nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip

# === Docker ===
step "Встановлення Docker"
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    apt-get remove -y "$pkg" 2>/dev/null || true
done

apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
| tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker $MAIN_USER
docker run --rm hello-world || true

# === Drosera CLI ===
step "Встановлення Drosera CLI"
run_as_user "curl -sSfL https://raw.githubusercontent.com/drosera-network/releases/main/droseraup/install | bash"

export_for_user "PATH" "\$HOME/.drosera/bin:\$PATH"

# Оновлюємо droseraup і встановлюємо drosera CLI
run_as_user "$USER_HOME/.drosera/bin/droseraup self-update"
run_as_user "$USER_HOME/.drosera/bin/droseraup install"

# Перевірка drosera
if ! run_as_user "command -v drosera"; then
    error "drosera не знайдений. Перевір встановлення."
    #exit 1
fi

# === Foundry ===
step "Встановлення Foundry"
run_as_user "curl -L https://foundry.paradigm.xyz | bash"
export_for_user "PATH" "\$HOME/.foundry/bin:\$PATH"
run_as_user "$USER_HOME/.foundry/bin/foundryup"

if ! run_as_user "command -v forge"; then
    error "forge не знайдений"
    #exit 1
fi

# === Bun ===
step "Встановлення Bun"
run_as_user "curl -fsSL https://bun.sh/install | bash"
export_for_user "PATH" "\$HOME/.bun/bin:\$PATH"

if ! run_as_user "command -v bun"; then
    error "bun не знайдений"
    #exit 1
fi

# === Налаштування Git ===
run_as_user "git config --global user.email \"$GITHUB_EMAIL\""
run_as_user "git config --global user.name \"$GITHUB_USERNAME\""

# === Створення проекту Trap ===
TRAP_DIR="$USER_HOME/my-drosera-trap"
step "Створення проекту в $TRAP_DIR"
run_as_user "mkdir -p \"$TRAP_DIR\""
run_as_user "cd \"$TRAP_DIR\""

# Ініціалізація проекту
if ! run_as_user "[ -f \"$TRAP_DIR/foundry.toml\" ]"; then
    run_as_user "cd \"$TRAP_DIR\" && forge init -t drosera-network/trap-foundry-template ."
fi

# Встановлення залежностей Bun
step "Встановлення залежностей Bun"
run_as_user "cd \"$TRAP_DIR\" && bun install"

# Встановлення контрактів Drosera
step "Встановлення контрактів Drosera"
run_as_user "cd \"$TRAP_DIR\" && forge install drosera-network/contracts --no-commit"

# Створення remappings.txt
step "Створення remappings.txt"
run_as_user "cat > \"$TRAP_DIR/remappings.txt\" << 'EOL'
forge-std/=lib/forge-std/src/
drosera-contracts/=lib/contracts/src/
EOL"

# Компіляція
step "Компіляція контрактів"
run_as_user "cd \"$TRAP_DIR\" && forge build"

# === Створення повної конфігурації drosera.toml ===
step "Створення конфігурації drosera.toml"
run_as_user "cat > \"$TRAP_DIR/drosera.toml\" << EOL
ethereum_rpc = \"https://ethereum-hoodi-rpc.publicnode.com\"
drosera_rpc = \"https://relay.hoodi.drosera.io\"
eth_chain_id = 560048
drosera_address = \"0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D\"

[traps.mytrap]
path = \"out/HelloWorldTrap.sol/HelloWorldTrap.json\"
response_contract = \"0x183D78491555cb69B68d2354F7373cc2632508C7\"
response_function = \"helloworld(string)\"
cooldown_period_blocks = 33
min_number_of_operators = 1
max_number_of_operators = 2
block_sample_size = 10
private_trap = true
whitelist = [\"$OPERATOR_ADDR\"]
EOL"

# === Експорт приватного ключа ===
export_for_user "DROSERA_PRIVATE_KEY" "$DROSERA_PRIVATE_KEY"

# === Застосування трапу ===
step "Застосування трапу"
if run_as_user "cd \"$TRAP_DIR\" && DROSERA_PRIVATE_KEY=\"$DROSERA_PRIVATE_KEY\" drosera apply"; then
    success "Трап успішно зареєстровано!"
else
    error "Не вдалося зареєструвати трап. Перевірте помилки вище."
    exit 1
fi

# === Створення systemd сервісу ===
step "Створення systemd сервісу"
cat > /etc/systemd/system/drosera.service << EOL
[Unit]
Description=Drosera Node Service
After=network.target

[Service]
Type=simple
User=$MAIN_USER
WorkingDirectory=$TRAP_DIR
Environment="DROSERA_PRIVATE_KEY=$DROSERA_PRIVATE_KEY"
Environment="PATH=$USER_HOME/.drosera/bin:$USER_HOME/.foundry/bin:$USER_HOME/.bun/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=$USER_HOME/.drosera/bin/drosera-operator node \\
  --db-file-path $USER_HOME/.drosera.db \\
  --network-p2p-port 31313 \\
  --server-port 31314 \\
  --eth-rpc-url https://ethereum-hoodi-rpc.publicnode.com \\
  --eth-backup-rpc-url https://0xrpc.io/hoodi \\
  --drosera-address 0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D \\
  --eth-private-key \$DROSERA_PRIVATE_KEY \\
  --eth-chain-id 560048 \\
  --listen-address 0.0.0.0 \\
  --disable-dnr-confirmation true

Restart=always
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOL

# === Налаштування firewall ===
step "Налаштування firewall"
ufw allow 31313/tcp
ufw allow 31314/tcp
ufw reload

# === Запуск сервісу ===
step "Запуск сервісу Drosera"
systemctl daemon-reload
systemctl enable drosera.service
systemctl start drosera.service

# === Перевірка статусу ===
step "Перевірка статусу сервісу"
sleep 5
systemctl status drosera.service --no-pager

# === Фінальні інструкції ===
cat <<EOF

${GREEN}✅ Установка завершена!${NC}

${CYAN}Важливі наступні кроки:${NC}
1. Перезавантажте термінал або виконайте: source ~/.bashrc
2. Перевірте статус: systemctl status drosera.service
3. Для перегляду логів: journalctl -u drosera.service -f

${CYAN}Інформація про проект:${NC}
- Директорія: $TRAP_DIR
- Користувач: $MAIN_USER
- Адреса оператора: $OPERATOR_ADDR
- Мережа: Hoodi Testnet (Chain ID: 560048)

${CYAN}Команди для керування:${NC}
- Перегляд статусу: systemctl status drosera.service
- Перегляд логів: journalctl -u drosera.service -f
- Перезапуск: systemctl restart drosera.service
- Зупинка: systemctl stop drosera.service

EOF

success "Скрипт успішно виконано!"
success "Трап зареєстровано та сервіс запущено!"
