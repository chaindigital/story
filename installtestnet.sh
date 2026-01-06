#!/usr/bin/env bash
set -e

### ===== CONFIG =====
MONIKER="your_moniker_here"
### ==================

echo "🔧 Updating system..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git wget htop tmux build-essential jq make lz4 gcc unzip

echo "🐹 Installing Go 1.24.6..."
cd $HOME
wget -q https://golang.org/dl/go1.24.6.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.24.6.linux-amd64.tar.gz
rm go1.24.6.linux-amd64.tar.gz

grep -q "/usr/local/go/bin" ~/.bash_profile || \
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bash_profile
source ~/.bash_profile
go version

echo "⬇️ Building story-geth (testnet)..."
cd $HOME
rm -rf story-geth
git clone https://github.com/piplabs/story-geth.git
cd story-geth
git checkout v1.2.0
make geth
mkdir -p $HOME/go/bin
mv build/bin/geth $HOME/go/bin/

echo "⬇️ Installing Story..."
cd $HOME
rm -rf story
git clone https://github.com/piplabs/story
cd story
git checkout v1.4.2
go build -o story ./client
mv story $HOME/go/bin/

echo "⚙️ Initializing node..."
story init "$MONIKER" --network aeneid

echo "📥 Downloading genesis & addrbook..."
wget -O $HOME/.story/story/config/genesis.json https://testnets.chaindigital.io/story/genesis.json
wget -O $HOME/.story/story/config/addrbook.json https://testnets.chaindigital.io/story/addrbook.json

echo "🔗 Configuring peers..."
CONFIG="$HOME/.story/story/config/config.toml"

SEEDS=""
PEERS="7b2e2414d01ec6ca440180151ae1373cbffb373b@story.peer.testnets.chaindigital.io:26656,d6c13af818704c64a42f77d74ab6ab6dc4e164dd@65.108.74.218:40656,cee58e7a8724fea3022be98898d7346d12a0ef80@164.152.162.119:36656"

sed -i -e "/^\[p2p\]/,/^\[/{s/^seeds *=.*/seeds = \"$SEEDS\"/}" \
       -e "/^\[p2p\]/,/^\[/{s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/}" $CONFIG

sed -i 's/prometheus = false/prometheus = true/' $CONFIG
sed -i 's/^indexer *=.*/indexer = "null"/' $CONFIG

echo "🧩 Creating systemd services..."

sudo tee /etc/systemd/system/story-geth.service > /dev/null <<EOF
[Unit]
Description=Story Geth daemon (testnet)
After=network-online.target

[Service]
User=$USER
ExecStart=$HOME/go/bin/geth --aeneid --syncmode full \
  --http --http.api eth,net,web3,engine \
  --http.vhosts '*' --http.addr 0.0.0.0 --http.port 8545 \
  --authrpc.port 8551 \
  --ws --ws.api eth,web3,net,txpool \
  --ws.addr 0.0.0.0 --ws.port 8546
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/story.service > /dev/null <<EOF
[Unit]
Description=Story Service (testnet)
After=network-online.target

[Service]
User=$USER
WorkingDirectory=$HOME/.story/story
ExecStart=$(which story) run
Restart=on-failure
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

echo "📦 Downloading snapshots..."
cp $HOME/.story/story/data/priv_validator_state.json \
   $HOME/.story/story/priv_validator_state.json.backup

rm -rf $HOME/.story/story/data
curl https://snapshots.chaindigital.tech/story/testnet/snap_story.tar.lz4 \
  | lz4 -dc - | tar -xf - -C $HOME/.story/story

mv $HOME/.story/story/priv_validator_state.json.backup \
   $HOME/.story/story/data/priv_validator_state.json

rm -rf $HOME/.story/geth/aeneid/geth/chaindata
mkdir -p $HOME/.story/geth/aeneid/geth
curl https://snapshots.chaindigital.tech/story/testnet/snap_geth_story.tar.lz4 \
  | lz4 -dc - | tar -xf - -C $HOME/.story/geth/aeneid/geth

echo "🚀 Starting services..."
sudo systemctl daemon-reload
sudo systemctl enable story story-geth
sudo systemctl restart story-geth
sleep 5
sudo systemctl restart story

echo "✅ Testnet node started!"
echo "📄 Logs:"
echo "journalctl -u story -u story-geth -f"
