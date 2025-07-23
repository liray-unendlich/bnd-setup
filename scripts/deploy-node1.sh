#!/bin/bash
# ノード1（メインノード）デプロイスクリプト

set -e

echo "=== RISC Zero Bento メインノード デプロイスクリプト ==="
echo "このスクリプトはノード1（インフラ+API+CPUコンピューティング）をデプロイします"
echo

# 現在のディレクトリ確認  
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODE1_DIR="$SCRIPT_DIR/../node1-main"

if [ ! -d "$NODE1_DIR" ]; then
    echo "エラー: node1-mainディレクトリが見つかりません: $NODE1_DIR"
    exit 1
fi

cd "$NODE1_DIR"

# 環境変数ファイルチェック
if [ ! -f ".env" ]; then
    echo "エラー: .envファイルが見つかりません"
    echo "サンプル.envファイルを作成してから実行してください"
    exit 1
fi

# 必要なディレクトリ作成
echo "必要なディレクトリを作成中..."
mkdir -p dockerfiles/grafana
echo "✓ ディレクトリ作成完了"

# broker.tomlの確認
if [ ! -f "broker.toml" ]; then
    echo "警告: broker.tomlファイルが見つかりません"
    echo "ブローカーサービスを使用する場合は、node1-mainディレクトリにbroker.tomlを配置してください"
fi

# Docker Composeバージョン確認
if ! command -v docker &> /dev/null; then
    echo "エラー: Dockerがインストールされていません"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "エラー: Docker Composeがインストールされていません"
    exit 1
fi

echo "✓ Docker環境確認完了"

# 段階的デプロイ開始  
echo
echo "=== 段階1: インフラサービス起動 ==="
echo "PostgreSQL, Redis, MinIOを起動します..."

docker-compose up -d redis postgres minio

echo "インフラサービスの起動を待機中（30秒）..."
sleep 30

# ヘルスチェック
echo "サービス状態確認中..."
docker-compose ps

echo
echo "=== 段階2: APIサービス起動 ==="
echo "REST API, Grafanaを起動します..."

docker-compose up -d rest_api grafana

echo "APIサービスの起動を待機中（20秒）..."
sleep 20

echo
echo "=== 段階3: コンピューティングエージェント起動 ==="  
echo "実行エージェント、補助エージェント、SNARKエージェントを起動します..."

docker-compose up -d exec_agent0 exec_agent1 aux_agent snark_agent

echo "エージェントの起動を待機中（15秒）..."
sleep 15

echo
echo "=== サービス状態確認 ==="
docker-compose ps

echo
echo "=== ヘルスチェック ==="

# PostgreSQL接続確認
echo -n "PostgreSQL接続確認: "
if docker-compose exec -T postgres pg_isready -U worker > /dev/null 2>&1; then
    echo "✓ OK"
else
    echo "✗ NG"
fi

# Redis接続確認
echo -n "Redis接続確認: "  
if docker-compose exec -T redis redis-cli ping > /dev/null 2>&1; then
    echo "✓ OK"
else
    echo "✗ NG"
fi

# REST API確認
echo -n "REST API確認: "
if curl -s http://localhost:8081 > /dev/null 2>&1; then
    echo "✓ OK"
else
    echo "✗ NG (正常起動に時間がかかる場合があります)"
fi

# Grafana確認
echo -n "Grafana確認: "
if curl -s http://localhost:3000 > /dev/null 2>&1; then
    echo "✓ OK"
else
    echo "✗ NG (正常起動に時間がかかる場合があります)"
fi

echo
echo "=== デプロイ完了 ==="
echo "アクセス情報:"
echo "- REST API: http://localhost:8081"
echo "- Grafana: http://localhost:3000 (admin/admin)"
echo "- MinIO Console: http://localhost:9001 (admin/[設定したパスワード])"
echo

echo "ブローカー起動（オプション）:"
echo "docker-compose --profile broker up -d broker"
echo

echo "ログ確認:"
echo "docker-compose logs -f [サービス名]"
echo

echo "=== 次のステップ ==="
echo "1. ファイアウォール設定を実行してください"
echo "2. ノード2（GPU）の設定でNODE1_IPをこのサーバーのIPアドレスに設定してください"
echo "3. ノード2をデプロイしてください"