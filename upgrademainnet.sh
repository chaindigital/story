#!/usr/bin/env bash
set -e

STORY_VERSION="v1.4.2"
GETH_VERSION="v1.2.0"

echo "🛑 Stopping services..."
sudo systemctl stop story
sudo systemctl stop story-geth

echo "⬇️ Updating Story..."
cd $HOME
rm -rf story
git clone https://github.com/piplabs/story
cd story
git checkout ${STORY_VERSION}
go build -o story ./client

echo "📦 Installing Story binary..."
sudo mv story $(which story)

echo "⬇️ Updating story-geth..."
wget -q -O /tmp/geth https://github.com/piplabs/story-geth/releases/download/${GETH_VERSION}/geth-linux-amd64
chmod +x /tmp/geth
sudo mv /tmp/geth $(which geth)

echo "🚀 Starting services..."
sudo systemctl start story-geth
sleep 5
sudo systemctl restart story

echo "✅ Update completed"
echo "📄 Logs:"
journalctl -u story -u story-geth -f
