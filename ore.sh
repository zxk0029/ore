#!/bin/bash

# 检查并安装Node.js和npm
install_nodejs_npm() {
    if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
        echo "Node.js或npm未安装，正在安装..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
        export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        nvm install node # 安装最新版本的Node.js和npm
        nvm use node
    else
        echo "Node.js和npm已安装。"
    fi
}

# 用于安装节点环境
install_node() {
    echo "检查并安装Node.js和npm..."
    install_nodejs_npm

    # 检查Rust是否已安装
    if command -v rustc &> /dev/null; then
        echo "Rust已安装。"
    else
        echo "安装Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
        source $HOME/.cargo/env
    fi

    # 检查ore-cli仓库是否已克隆
    if [ -d "ore-cli" ]; then
        echo "ore-cli仓库已存在。"
    else
        echo "克隆ore-cli仓库..."
        git clone https://github.com/HardhatChad/ore-cli.git
    fi

    # 编译ore-cli
    echo "编译ore-cli..."
    cd ore-cli
    cargo build --release
    cd target/release/

    # 安装npm依赖
    echo "安装npm依赖..."
    npm install -g @solana/web3.js bs58
    echo "环境安装完成。"
}

# 准备ore-cli运行所需的环境
prepare_ore_environment() {
    echo "准备ore-cli运行环境..."
    cd ore-cli/target/release/

    # 创建generation.js文件并初始化npm
    cat <<EOF >generation.js
// generation.js
const { Keypair } = require("@solana/web3.js");
const bs58 = require("bs58");

(async () => {
  const keypair = Keypair.fromSecretKey(
    bs58.decode("Private key") 
  );
  console.log(JSON.stringify(Array.from(keypair.secretKey)));
})();
EOF

    npm init -y && npm install @solana/web3.js
    sed -i '/"scripts": {/a \ \ \ \ "gene": "node generation.js",' package.json
    node generation.js > keypair.json
    echo "环境准备完毕，即将启动ore-cli。"
}

# 运行ore-cli并在中断后自动重启
auto_restart_ore() {
    cd ore-cli/target/release/
    while true; do
        ./ore --rpc https://linguistic-dulcea-fast-mainnet.helius-rpc.com --keypair keypair.json --priority-fee 1 mine --threads 8
        echo "ore 命令中断，正在重启..."
        sleep 5 # 等待5秒以避免立即重启导致的潜在问题
    done
}

# 主菜单函数
function main_menu() {
    clear
    echo "请选择要执行的操作:"
    echo "1. 安装节点"
    echo "2. 准备ore-cli环境"
    echo "3. 启动并自动重启ore-cli"
    read -p "请输入选项（1-3）: " OPTION

    case $OPTION in
        1) install_node ;;
        2) prepare_ore_environment ;;
        3) auto_restart_ore ;;
        *) echo "无效选项。" && sleep 2 && main_menu ;;
    esac
}

# 显示主菜单
main_menu
