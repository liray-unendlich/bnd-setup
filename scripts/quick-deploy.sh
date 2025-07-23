#!/bin/bash
# 全自動デプロイスクリプト - 設定後の一括実行用

set -e

echo "=================================================================="
echo "RISC Zero Bento 2ノード構成 全自動デプロイスクリプト"
echo "=================================================================="
echo "このスクリプトは既にセットアップ済みの環境で実行してください"
echo

# 実行前チェック
if [ ! -f "../node1-main/.env" ] || [ ! -f "../node2-gpu/.env" ]; then
    echo "エラー: 環境変数ファイル（.env）が見つかりません"
    echo "node1-main/.env と node2-gpu/.env を先に設定してください"
    exit 1
fi

# ノード情報の取得
source ../node1-main/.env
NODE1_IP=$(hostname -I | awk '{print $1}')

source ../node2-gpu/.env
if [ "$NODE1_IP" = "192.168.1.100" ]; then
    echo "警告: NODE1_IPがデフォルト値のままです"
    echo "node2-gpu/.env の NODE1_IP を実際の値に設定してください"
    exit 1
fi

echo "デプロイ設定:"
echo "- ノード1 IP: $NODE1_IP"
echo "- ノード2から接続先: $NODE1_IP"
echo

read -p "この設定でデプロイを開始しますか？ [y/N]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

echo "=== 段階1: ノード1デプロイ ==="
cd ../node1-main
echo "ノード1のデプロイを開始します..."

# インフラ起動
echo "インフラサービス起動中..."
docker-compose up -d redis postgres minio
sleep 30

# API起動
echo "APIサービス起動中..."
docker-compose up -d rest_api grafana
sleep 20

# エージェント起動
echo "コンピューティングエージェント起動中..."
docker-compose up -d exec_agent0 exec_agent1 aux_agent snark_agent
sleep 15

echo "✓ ノード1デプロイ完了"

# ヘルスチェック
echo "=== ノード1ヘルスチェック ==="
echo -n "PostgreSQL: "
if docker-compose exec -T postgres pg_isready -U worker > /dev/null 2>&1; then
    echo "✓ OK"
else
    echo "✗ NG"
fi

echo -n "Redis: "
if docker-compose exec -T redis redis-cli ping > /dev/null 2>&1; then
    echo "✓ OK"
else
    echo "✗ NG"
fi

echo -n "REST API: "
if curl -s http://localhost:8081 > /dev/null 2>&1; then
    echo "✓ OK"
else
    echo "✗ NG"
fi

echo
echo "=== 段階2: ノード2デプロイ ==="
echo "注意: ノード2は別サーバーで実行してください"
echo "ノード2で以下のコマンドを実行:"
echo "cd /opt/bento-node2"
echo "docker-compose up -d gpu_prove_agent0"
echo

echo "=== 段階3: 最終確認 ==="
echo "アクセス情報:"
echo "- REST API: http://$NODE1_IP:8081"
echo "- Grafana: http://$NODE1_IP:3000 (admin/admin)"
echo "- MinIO Console: http://$NODE1_IP:9001"
echo

echo "追加コマンド:"
echo "- ブローカー起動: docker-compose --profile broker up -d broker"
echo "- ログ確認: docker-compose logs -f [サービス名]"
echo "- GPU確認（ノード2）: nvidia-smi"
echo

echo "=================================================================="
echo "デプロイ完了！"
echo "=================================================================="