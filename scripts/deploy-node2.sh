#!/bin/bash
# ノード2（GPUノード）デプロイスクリプト

set -e

echo "=== RISC Zero Bento GPUノード デプロイスクリプト ==="
echo "このスクリプトはノード2（GPU証明処理専用）をデプロイします"
echo

# 現在のディレクトリ確認
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODE2_DIR="$SCRIPT_DIR/../node2-gpu"

if [ ! -d "$NODE2_DIR" ]; then
    echo "エラー: node2-gpuディレクトリが見つかりません: $NODE2_DIR"
    exit 1
fi

cd "$NODE2_DIR"

# 環境変数ファイルチェック
if [ ! -f ".env" ]; then
    echo "エラー: .envファイルが見つかりません"
    echo "サンプル.envファイルを作成してから実行してください"
    exit 1
fi

# NODE1_IPの設定確認
source .env
if [ "$NODE1_IP" = "192.168.1.100" ]; then
    echo "警告: NODE1_IPがデフォルト値のままです"
    echo "実際のノード1のIPアドレスに変更してください"
    read -p "続行しますか？ [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Docker環境確認
if ! command -v docker &> /dev/null; then
    echo "エラー: Dockerがインストールされていません"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "エラー: Docker Composeがインストールされていません"  
    exit 1
fi

# NVIDIA Container Toolkit確認
echo "NVIDIA Container Toolkit確認中..."
if ! docker run --rm --runtime=nvidia --gpus all nvidia/cuda:11.0.3-base-ubuntu20.04 nvidia-smi > /dev/null 2>&1; then
    echo "エラー: NVIDIA Container Toolkitが正しく設定されていません"
    echo "以下のコマンドでインストールしてください:"
    echo "curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -"
    echo "distribution=\$(. /etc/os-release;echo \$ID\$VERSION_ID)"
    echo "curl -s -L https://nvidia.github.io/nvidia-docker/\$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list"
    echo "sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit"
    echo "sudo systemctl restart docker"
    exit 1
fi

echo "✓ NVIDIA Container Toolkit確認完了"

# GPU確認
echo "利用可能なGPU確認中..."
GPU_COUNT=$(nvidia-smi -L | wc -l)
echo "検出されたGPU数: $GPU_COUNT"

if [ "$GPU_COUNT" -eq 0 ]; then
    echo "エラー: GPUが検出されませんでした"
    exit 1
fi

nvidia-smi -L

# ノード1への接続確認
echo
echo "=== ノード1接続確認 ==="

echo -n "PostgreSQL接続確認 ($NODE1_IP:5432): "
if timeout 5 bash -c "</dev/tcp/$NODE1_IP/5432" 2>/dev/null; then
    echo "✓ OK"
else
    echo "✗ NG - ノード1が起動していないか、ファイアウォールで接続がブロックされています"
    exit 1
fi

echo -n "Redis接続確認 ($NODE1_IP:6379): "
if timeout 5 bash -c "</dev/tcp/$NODE1_IP/6379" 2>/dev/null; then
    echo "✓ OK"
else
    echo "✗ NG - ノード1のRedisに接続できません"
    exit 1
fi

echo -n "MinIO接続確認 ($NODE1_IP:9000): "
if timeout 5 bash -c "</dev/tcp/$NODE1_IP/9000" 2>/dev/null; then
    echo "✓ OK"
else
    echo "✗ NG - ノード1のMinIOに接続できません"
    exit 1
fi

# GPU エージェント起動
echo
echo "=== GPU証明エージェント起動 ==="
echo "メインGPUエージェント（gpu_prove_agent0）を起動します..."

docker-compose up -d gpu_prove_agent0

echo "GPUエージェントの起動を待機中（20秒）..."
sleep 20

# 複数GPU利用確認
if [ "$GPU_COUNT" -gt 1 ]; then
    echo
    echo "複数GPU検出: 追加のGPUエージェントを起動しますか？"
    echo "利用可能GPU数: $GPU_COUNT"
    read -p "追加GPUエージェントを起動しますか？ [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "マルチGPUプロファイルでエージェント起動中..."
        docker-compose --profile multi-gpu up -d
    fi
fi

echo
echo "=== サービス状態確認 ==="
docker-compose ps

echo
echo "=== GPU使用状況確認 ==="
nvidia-smi

echo
echo "=== ログ確認（最新10行） ==="
docker-compose logs --tail=10 gpu_prove_agent0

echo
echo "=== デプロイ完了 ==="
echo "GPU証明エージェントが起動しました"
echo
echo "有用なコマンド:"
echo "- ログ確認: docker-compose logs -f gpu_prove_agent0"
echo "- GPU使用状況: nvidia-smi"
echo "- サービス再起動: docker-compose restart gpu_prove_agent0"
echo "- 追加GPU起動: docker-compose --profile multi-gpu up -d"
echo
echo "パフォーマンス監視:"
echo "- watch -n 1 nvidia-smi"
echo "- docker stats"