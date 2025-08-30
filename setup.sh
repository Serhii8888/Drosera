#!/bin/bash
set -e

# === Хелпери ===
step() { echo -e "\n==== $1 ====\n"; }
run_as_user() { sudo -u "$SUDO_USER" bash -c "$1"; }

# === Запит користувача ===
read -rp "Введіть ваш GitHub email: " GITHUB_EMAIL
read -rp "Введіть ваш GitHub username: " GITHUB_USERNAME
read -rp "Введіть вашу EVM адресу (для whitelist): " OPERATOR_ADDR
read -srp "Введіть приватний ключ (EVM PRIVATE KEY): " DROSERA_PRIVATE_KEY; echo

# === Оновлення системи ===
step "Оновлення системи"
apt-get update && apt-get upgrade -y

# === Базові пакети ===
step "Встановлення базових пакетів"
apt install -y curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop \
nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip ca-certificates gnupg

# === Docker ===
step "Встановлення Docker"
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    apt-get remove -y "$pkg" || true
done
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
| tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
docker run hello-world || true

# === Drosera CLI (droseraup + drosera) ===
step "Встановлення Drosera CLI"
curl -sSfL https://raw.githubusercontent.com/drosera-network/releases/main/droseraup/install | bash
echo 'export PATH=$HOME/.drosera/bin:$PATH' >> ~/.bashrc
export PATH=$HOME/.drosera/bin:$PATH
~/.drosera/bin/droseraup install
command -v drosera >/dev/null || { echo "❌ drosera не знайдений"; exit 1; }

# === Foundry ===
step "Встановлення Foundry"
curl -L https://foundry.paradigm.xyz | bash
echo 'export PATH=$HOME/.foundry/bin:$PATH' >> ~/.bashrc
export PATH=$HOME/.foundry/bin:$PATH
foundryup
command -v forge >/dev/null || { echo "❌ forge не знайдений"; exit 1; }

# === Bun ===
step "Встановлення Bun"
curl -fsSL https://bun.sh/install | bash
echo 'export PATH=$HOME/.bun/bin:$PATH' >> ~/.bashrc
export PATH=$HOME/.bun/bin:$PATH
command -v bun >/dev/null || { echo "❌ bun не знайдений"; exit 1; }

# === Створення Trap проекту ===
step "Створення Trap проекту"
TRAP_DIR="$HOME/my-drosera-trap"
if [ -d "$TRAP_DIR" ]; then
    echo "⚠️ Каталог $TRAP_DIR вже існує"
else
    forge init -t drosera-network/trap-foundry-template "$TRAP_DIR"
fi
cd "$TRAP_DIR"

# GitHub дані
git config --global user.email "$GITHUB_EMAIL"
git config --global user.name "$GITHUB_USERNAME"

# === Встановлення залежностей ===
step "Встановлення залежностей через Bun"
bun install

# === Forge deps ===
step "Встановлення forge-std та drosera contracts"
forge install foundry-rs/forge-std
forge install drosera-network/contracts

# Remappings
cat > remappings.txt <<EOL
forge-std/=lib/forge-std/src/
drosera-contracts/=lib/contracts/src/
contracts/=lib/contracts/src/
EOL

# === Компіляція ===
step "Компіляція Trap"
forge build

# === Створення drosera.toml ===
step "Формування drosera.toml"

read -rp "Введіть вашу EVM адресу (для whitelist): " OPERATOR_ADDR

cat > drosera.toml <<EOL
ethereum_rpc = "https://ethereum-hoodi-rpc.publicnode.com"
drosera_rpc = "https://relay.hoodi.drosera.io"
eth_chain_id = 560048
drosera_address = "0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D"

[traps]

[traps.mytrap]
path = "out/HelloWorldTrap.sol/HelloWorldTrap.json"
response_contract = "0x183D78491555cb69B68d2354F7373cc2632508C7"
response_function = "helloworld(string)"
cooldown_period_blocks = 33
min_number_of_operators = 1
max_number_of_operators = 2
block_sample_size = 10
private_trap = true
whitelist = ["$OPERATOR_ADDR"]
EOL


# === Deploy Trap ===
step "Деплой Trap"
export DROSERA_PRIVATE_KEY="$DROSERA_PRIVATE_KEY"
drosera apply

echo -e "\n✅ Trap успішно задеплоєний!"
echo "⚠️ Не забудь виконати: source ~/.bashrc"
