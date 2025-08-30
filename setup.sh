#!/bin/bash
set -e

# === Функція для перевірки команд ===
check_command() {
    command -v "$1" >/dev/null 2>&1 || { echo "❌ $1 не знайдений. Перевірте інсталяцію."; exit 1; }
}

# === Введення користувацьких даних ===
read -rp "Введіть свій GitHub email: " GITHUB_EMAIL
read -rp "Введіть свій GitHub username: " GITHUB_USERNAME
read -s -rp "Введіть приватний ключ (PRIVATE_KEY) для drosera: " DROSERA_PRIVATE_KEY
echo

# === Оновлення системи ===
sudo apt-get update && sudo apt-get upgrade -y

# === Базові пакети ===
sudo apt install -y curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop \
nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip

# === Docker ===
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    sudo apt-get remove -y "$pkg" || true
done

sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
| sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo docker run hello-world || true

# === Drosera CLI ===
curl -sSfL https://raw.githubusercontent.com/drosera-network/releases/main/droseraup/install | bash
echo 'export PATH=$HOME/.drosera/bin:$PATH' >> ~/.bashrc
export PATH=$HOME/.drosera/bin:$PATH
check_command droseraup

# === Foundry ===
curl -L https://foundry.paradigm.xyz | bash
echo 'export PATH=$HOME/.foundry/bin:$PATH' >> ~/.bashrc
export PATH=$HOME/.foundry/bin:$PATH
foundryup
check_command forge

# === Bun ===
curl -fsSL https://bun.sh/install | bash
echo 'export PATH=$HOME/.bun/bin:$PATH' >> ~/.bashrc
export PATH=$HOME/.bun/bin:$PATH
check_command bun

# === Функція для створення та деплою трапу ===
deploy_trap() {
    TRAP_DIR="$HOME/my-drosera-trap"
    mkdir -p "$TRAP_DIR" && cd "$TRAP_DIR"

    git config --global user.email "$GITHUB_EMAIL"
    git config --global user.name "$GITHUB_USERNAME"

    # Ініціалізація проекту якщо немає foundry.toml
    if [ ! -f "foundry.toml" ]; then
        forge init -t drosera-network/trap-foundry-template
    fi

    # Встановлення залежностей
    bun install
    bun add github:drosera-network/contracts

    # Автоматичне виправлення імпортів у src/ і test/
    find src test -type f -name "*.sol" -print0 | while IFS= read -r -d '' file; do
      sed -i 's|import "forge-std/\(.*\).sol"|import {\1} from "forge-std/\1.sol"|g' "$file"
      sed -i 's|drosera-contracts/|@drosera/contracts/src/|g' "$file"
    done

    forge build

    read -rp "Enter your EVM wallet address (for whitelist): " OPERATOR_ADDR

    cat > drosera.toml <<EOL
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

    export DROSERA_PRIVATE_KEY
    "$HOME/.drosera/bin/drosera" apply
    echo "✅ Trap deployed!"
}

# === Виклик деплою трапу ===
deploy_trap

# === Фінальні інструкції ===
echo
echo "⚠️ Після перезавантаження виконайте:"
echo "source ~/.bashrc"
echo
