#!/bin/bash

# 检查并安装Node.js和npm
install_nodejs_npm() {
    if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
        echo "Node.js或npm未安装，正在安装..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        nvm install node # 安装最新版本的Node.js和npm
        nvm use node
        echo 'export NVM_DIR="$HOME/.nvm"' >> $HOME/.bashrc
        echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> $HOME/.bashrc
        echo "Node.js和npm安装完毕。"
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
        echo 'source $HOME/.cargo/env' >> $HOME/.bashrc
        echo "Rust安装完毕。"
    fi

    # 检查ore-cli仓库是否已克隆
    if [ -d "ore-cli" ]; then
        echo "ore-cli仓库已存在。"
    else
        echo "克隆ore-cli仓库..."
        git clone https://github.com/HardhatChad/ore-cli.git || { echo "克隆失败，可能是网络问题。"; exit 1; }
    fi

    # 编译ore-cli
    echo "编译ore-cli..."
    cd ore-cli || { echo "切换目录失败，可能是克隆不完整。"; exit 1; }
    cargo build --release || { echo "编译失败，请检查Rust环境。"; exit 1; }
    cd target/release/ || { echo "编译产物不存在，编译失败。"; exit 1; }

    # 安装npm依赖
    echo "安装npm依赖..."
    npm install -g @solana/web3.js bs58 || { echo "npm依赖安装失败，请检查npm环境。"; exit 1; }
    echo "环境安装完成。"
}

# 准备ore-cli运行所需的环境
prepare_ore_environment() {
    echo "准备ore-cli运行环境..."
    cd ore-cli/target/release/ || { echo "目录切换失败，ore-cli可能未正确安装。"; return; }

    # 提示用户输入私钥
    echo "请输入你的私钥："
    read -s PRIVATE_KEY

    # 创建generation.js文件并初始化npm
    cat <<EOF >generation.js
// generation.js
const { Keypair } = require("@solana/web3.js");
const bs58 = require("bs58");

if (process.argv.length < 3) {
  console.log("Usage: node generation.js <privateKey>");
  process.exit(1);
}

const privateKey = process.argv[2];
const keypair = Keypair.fromSecretKey(bs58.decode(privateKey));
console.log(JSON.stringify(Array.from(keypair.secretKey)));

EOF

    npm init -y && npm install @solana/web3.js bs58 || { echo "npm初始化或安装失败。"; return; }

    # 直接使用私钥作为命令行参数执行脚本
    node generation.js "$PRIVATE_KEY" > keypair.json || { echo "生成keypair.json失败。"; return; }
    echo "环境准备完毕，即将启动ore-cli。"
}

# 运行ore-cli并在中断后自动重启
auto_restart_ore() {
    # 定义一个screen会话名
    local session_name="ore_auto_restart"

    # 检查是否已经存在名为session_name的screen会话
    if screen -list | grep -q "$session_name"; then
        echo "已经存在一个名为'$session_name'的screen会话。"
        echo "你可以使用 'screen -r $session_name' 命令重新连接到这个会话。"
    else
        # 创建一个新的detached screen会话并在其中运行命令
        echo "创建新的screen会话 '$session_name' 并在其中执行ore-cli..."
        screen -dmS "$session_name" bash -c 'cd ore-cli/target/release/; while true; do ./ore --rpc https://linguistic-dulcea-fast-mainnet.helius-rpc.com --keypair keypair.json --priority-fee 1 mine --threads 8; echo "ore 命令中断，正在重启..."; sleep 5; done'
        echo "已在后台screen会话 '$session_name' 中启动ore-cli。"
        echo "使用 'screen -r $session_name' 命令可以重新连接到这个会话。"
    fi
}

auto_claim_ore() {
    # 定义一个screen会话名
    local session_name="ore_auto_claim"

    # 检查是否已经存在名为session_name的screen会话
    if screen -list | grep -q "$session_name"; then
        echo "已经存在一个名为'$session_name'的screen会话。"
        echo "你可以使用 'screen -r $session_name' 命令重新连接到这个会话。"
    else
        # 创建一个新的detached screen会话并在其中运行命令
        echo "创建新的screen会话 '$session_name' 并在其中执行ore-cli..."
        screen -dmS "$session_name" bash -c 'cd ore-cli/target/release/; while true; do ./ore --rpc https://linguistic-dulcea-fast-mainnet.helius-rpc.com --keypair keypair.json claim; echo "ore claim命令中断，正在重启..."; sleep 60; done'
        echo "已在后台screen会话 '$session_name' 中启动ore-cli。"
        echo "使用 'screen -r $session_name' 命令可以重新连接到这个会话。"
    fi
}

rewards_ore() {
    echo "查询ore数量..."
    cd ore-cli/target/release/ || { echo "目录切换失败，ore-cli可能未正确安装。"; return; }
    ./ore --rpc https://api.mainnet-beta.solana.com --keypair keypair.json rewards
}

# 主菜单函数
function main_menu() {
    clear
    echo "请选择要执行的操作:"
    echo "1. 安装节点"
    echo "2. 准备ore-cli环境"
    echo "3. 启动并自动重启ore-cli"
    echo "4. 自动重复claim ore"
    echo "5. 查询挖取ore数量"
    read -p "请输入选项（1-5）: " OPTION

    case $OPTION in
        1) install_node ;;
        2) prepare_ore_environment ;;
        3) auto_restart_ore ;;
        4) auto_claim_ore ;;
        5) rewards_ore ;;
        *) echo "无效选项。" && sleep 2 && main_menu ;;
    esac
}

# 显示主菜单
main_menu
