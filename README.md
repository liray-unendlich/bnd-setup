# RISC Zero Bento 2ノード分散デプロイメント

RISC Zero Bentoを2ノード構成（メインノード + GPUクラスター）で分散デプロイするためのファイル群です。

## 構成概要

### ノード1: メインノード
- **インフラサービス**: PostgreSQL, Redis, MinIO
- **APIサービス**: REST API, Grafana, Broker
- **CPUコンピューティング**: exec_agent0/1, aux_agent, snark_agent
- **推奨スペック**: 16-20コア、64GB RAM、1.5TB SSD

### ノード2: GPUクラスター
- **GPU証明処理**: gpu_prove_agent0-3（複数GPU対応）
- **推奨スペック**: 8-12コア、32GB RAM、500GB SSD、複数NVIDIA GPU

## ディレクトリ構造

```
bento-distributed-deploy/
├── node1-main/              # ノード1（メインノード）用ファイル
│   ├── docker-compose.yml   # Docker Compose設定
│   └── .env                 # 環境変数（要編集）
├── node2-gpu/               # ノード2（GPUノード）用ファイル
│   ├── docker-compose.yml   # Docker Compose設定
│   └── .env                 # 環境変数（要編集）
├── scripts/                 # デプロイメントスクリプト
│   ├── deploy-node1.sh      # ノード1デプロイスクリプト
│   ├── deploy-node2.sh      # ノード2デプロイスクリプト
│   ├── setup-firewall-node1.sh  # ノード1ファイアウォール設定
│   └── setup-firewall-node2.sh  # ノード2ファイアウォール設定
├── docs/                    # ドキュメント
└── README.md               # このファイル
```

## 🚀 超簡単セットアップ（推奨）

### ワンライナーでセットアップ開始

**ノード1（メインノード）で実行:**
```bash
export NODE_TYPE=1
curl -fsSL https://raw.githubusercontent.com/liray-unendlich/bnd-setup/main/quick-start.sh | bash
```

**ノード2（GPUノード）で実行:**
```bash
export NODE_TYPE=2
curl -fsSL https://raw.githubusercontent.com/liray-unendlich/bnd-setup/main/quick-start.sh | bash
```

このスクリプトが以下を自動実行します：
1. GitHubリポジトリのクローン
2. ノード種別の選択
3. 環境セットアップの実行

### 手動セットアップ

**1. リポジトリクローン:**
```bash
git clone https://github.com/liray-unendlich/bnd-setup.git
cd bnd-setup
```

**2. rootセットアップ（各ノードで1回のみ）:**
```bash
# ノード1で
sudo ./scripts/setup-node1-root.sh

# ノード2で  
sudo ./scripts/setup-node2-root.sh

# システム再起動
sudo reboot
```

**3. 開発環境セットアップ（作業用ユーザーで）:**
```bash
# 再起動後、作業用ユーザーでログイン
./scripts/setup-dev-environment.sh
```

### 3. 設定ファイル編集

**ノード1の環境変数編集:**
```bash
cd node1-main
cp .env .env.backup
vi .env
```

重要な設定項目:
- `POSTGRES_PASSWORD`: データベースパスワード
- `MINIO_ROOT_PASS`: MinIOパスワード  
- `PRIVATE_KEY`: ブローカー用秘密鍵
- `RPC_URL`: RPC接続URL

**ノード2の環境変数編集:**
```bash
cd node2-gpu
cp .env .env.backup
vi .env
```

重要な設定項目:
- `NODE1_IP`: ノード1の実際のIPアドレス
- パスワード類をノード1と同じ値に設定

### 4. デプロイ実行

**ステップ1: ノード1デプロイ**
```bash
cd scripts
./deploy-node1.sh
```

**ステップ2: ファイアウォール設定**
```bash
# ノード1で実行（NODE2_IPは実際のIPに置換）
./setup-firewall-node1.sh 192.168.1.101

# ノード2で実行
./setup-firewall-node2.sh
```

**ステップ3: ノード2デプロイ**
```bash
cd scripts
./deploy-node2.sh
```

## アクセス情報

### ノード1（メインノード）
- **REST API**: http://[NODE1_IP]:8081
- **Grafana**: http://[NODE1_IP]:3000 (admin/admin)
- **MinIO Console**: http://[NODE1_IP]:9001

### 必要ポート
| サービス | ポート | アクセス元 |
|---------|-------|----------|
| PostgreSQL | 5432 | ノード2から |
| Redis | 6379 | ノード2から |
| MinIO | 9000 | ノード2から |
| REST API | 8081 | 外部から |
| Grafana | 3000 | 外部から |
| MinIO Console | 9001 | 外部から |

## 運用コマンド

### 基本操作
```bash
# サービス状態確認
docker-compose ps

# ログ確認
docker-compose logs -f [サービス名]

# サービス再起動
docker-compose restart [サービス名]

# 全サービス停止
docker-compose down

# 全サービス起動
docker-compose up -d
```

### スケーリング
```bash
# ノード1でCPUエージェント追加
docker-compose up -d --scale exec_agent0=3

# ノード2でGPUエージェント追加（マルチGPU）
docker-compose --profile multi-gpu up -d

# 特定GPUエージェントのスケール
docker-compose up -d --scale gpu_prove_agent0=2
```

### ブローカー起動（オプション）
```bash
# ノード1で実行
docker-compose --profile broker up -d broker
```

## 監視とトラブルシューティング

### ヘルスチェック
```bash
# ノード1で実行
curl http://localhost:8081        # REST API
curl http://localhost:3000        # Grafana
redis-cli ping                    # Redis
pg_isready -h localhost -p 5432   # PostgreSQL

# ノード2からノード1への接続確認
telnet [NODE1_IP] 5432  # PostgreSQL
telnet [NODE1_IP] 6379  # Redis
telnet [NODE1_IP] 9000  # MinIO
```

### GPU監視
```bash
# GPU使用状況確認
nvidia-smi

# リアルタイム監視
watch -n 1 nvidia-smi

# Docker統計
docker stats
```

### よくある問題

1. **ノード間接続エラー**
   - ファイアウォール設定を確認
   - IPアドレスが正しく設定されているか確認

2. **GPU認識エラー**
   - NVIDIA Container Toolkitのインストール確認
   - `docker run --rm --runtime=nvidia --gpus all nvidia/cuda:11.0.3-base-ubuntu20.04 nvidia-smi`

3. **メモリ不足**
   - `free -h`でメモリ使用量確認
   - `docker system prune -f`で不要なイメージ削除

## セキュリティ考慮事項

- データベースとMinIOのパスワードを強固に設定
- 秘密鍵の安全な管理
- ファイアウォールで不要なポートの封鎖
- 定期的なセキュリティアップデート

## バックアップ

### 重要データのバックアップ
```bash
# PostgreSQLバックアップ
docker-compose exec postgres pg_dump -U worker taskdb > backup.sql

# MinIOデータのバックアップ
docker run --rm -v minio-data:/data -v $(pwd):/backup alpine tar czf /backup/minio-backup.tar.gz /data

# ブローカーデータのバックアップ
docker run --rm -v broker-data:/data -v $(pwd):/backup alpine tar czf /backup/broker-backup.tar.gz /data
```

## サポート

問題が発生した場合は、以下の情報を収集してください:

1. `docker-compose ps` の出力
2. `docker-compose logs [サービス名]` の関連ログ
3. システムリソース使用状況 (`htop`, `free -h`, `df -h`)
4. ネットワーク接続状況
5. GPU状況（ノード2の場合: `nvidia-smi`）

## ライセンス

このデプロイメント設定ファイル群は、RISC Zero Bentoのライセンスに従います。