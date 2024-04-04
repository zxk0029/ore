#!/bin/bash

# 第一步：安装Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 第二步：克隆ore-cli仓库
git clone https://github.com/HardhatChad/ore-cli.git 

# 第三步：编译ore-cli
cd ore-cli && cargo build --release

# 第四步：安装npm依赖
cd target/release/ && npm install -g @solana/web3.js bs58

# 第五步：在target/release目录下创建generation.js文件
cat <<EOF >generation.js
// generation.js
const { Keypair } = require("@solana/web3.js");
const bs58 = require("bs58");

(async () => {
  const keypair = Keypair.fromSecretKey(
    bs58.decode("Private key") 
  );
  console.log(JSON.stringify(keypair.secretKey));
})();
EOF

# 第六步：初始化npm并安装@solana/web3.js
npm init -y && npm install @solana/web3.js

# 修改package.json文件以添加自定义脚本
sed -i '/"scripts": {/a \ \ \ \ "gene": "node generation.js",' package.json

# 执行自定义脚本，结果输出到keypair.json
npm run gene > keypair.json

# 修改keypair.json文件格式，确保它是一个合法的JSON数组
sed -i '1s/^/[/' keypair.json
sed -i '$s/$/]/' keypair.json

# 第八步：执行ore命令
./ore-cli/target/release/ore --rpc https://linguistic-dulcea-fast-mainnet.helius-rpc.com --keypair target/release/keypair.json --priority-fee 1 mine --threads 8

