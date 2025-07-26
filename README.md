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
bnd-setup/
├── node1-main/              # ノード1（メインノード）用ファイル
│   ├── docker-compose.yml   # Docker Compose設定
│   ├── broker.toml.example  # ブローカー設定テンプレート
│   ├── .env.template        # 環境変数テンプレート
│   └── .env                 # 環境変数（自動生成・要編集）
├── node2-gpu/               # ノード2（GPUノード）用ファイル
│   ├── docker-compose.yml   # Docker Compose設定
│   ├── .env.template        # 環境変数テンプレート
│   └── .env                 # 環境変数（自動生成・要編集）
├── scripts/                 # デプロイメントスクリプト
│   ├── deploy-node1.sh      # ノード1デプロイスクリプト
│   ├── deploy-node2.sh      # ノード2デプロイスクリプト
│   ├── setup-firewall-node1.sh  # ノード1ファイアウォール設定
│   ├── setup-firewall-node2.sh  # ノード2ファイアウォール設定
│   └── build-boundless.sh   # Boundlessプロジェクトビルド
├── docs/                    # ドキュメント
├── quick-start.sh           # ワンライナーセットアップ
└── README.md               # このファイル
```

## 📖 目次

- [🚀 超簡単セットアップ](#超簡単セットアップ推奨)
- [☁️ GPUクラウドサービス対応](#gpuクラウドサービス対応)
- [⚙️ 運用コマンド](#運用コマンド)  
- [🤖 ブローカー起動（本格運用）](#ブローカー起動本格運用)
- [📊 監視とトラブルシューティング](#監視とトラブルシューティング)
- [🔒 セキュリティ考慮事項](#セキュリティ考慮事項)
- [💾 バックアップ](#バックアップ)

## ☁️ GPUクラウドサービス対応

**Salad Cloud、RunPod、Vast.ai等のGPUクラウドサービス**でnode2-gpu（GPU証明専用）を実行する場合：

### 1. ノード1（インフラサーバー）のセットアップ
通常通りオンプレミス/VPSでセットアップ：
```bash
export NODE_TYPE=1
curl -fsSL https://raw.githubusercontent.com/liray-unendlich/bnd-setup/main/quick-start.sh | bash
```

### 2. ノード2（GPUクラウドサービス）の設定

#### WebUIでの基本設定:
- **イメージ**: `risczero/risc0-bento-agent:2.3.1@sha256:7873f18005efff03fc5399f1bdcb6760cda7ffbd4fdd4d9c39aedee8972e0a0d`
- **起動コマンド**: `/app/agent -t prove --redis-ttl 57600`
- **メモリ**: 4GB以上
- **GPU**: NVIDIA GPU必須

#### 必須環境変数:
```bash
NODE1_IP=YOUR_NODE1_PUBLIC_IP
DATABASE_URL=postgresql://worker:YOUR_DB_PASS@YOUR_NODE1_IP:5432/taskdb
REDIS_URL=redis://YOUR_NODE1_IP:6379
S3_URL=http://YOUR_NODE1_IP:9000
S3_BUCKET=workflow
S3_ACCESS_KEY=admin
S3_SECRET_KEY=YOUR_MINIO_PASS
RISC0_KECCAK_PO2=17
CUDA_VISIBLE_DEVICES=0
RUST_LOG=info
```

**📋 詳細手順**: [GPUクラウドサービス対応ガイド](docs/container-service-deployment.md)

---

## 🚀 完全セットアップガイド

### ステップ1: 初期セットアップ（root実行）

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
1. システム環境の自動構築（root権限で実行）
2. 作業用ユーザー（bento）の作成
3. bnd-setupリポジトリの自動クローン（~/work/bnd-setup）
4. Docker環境のインストール
5. **自動的にシステム再起動**

### ステップ2: 作業用ユーザーでのセットアップ

**システム再起動後、作業用ユーザー（bento）でログイン:**

#### 🎯 統合セットアップ（推奨）
```bash
cd ~/work/bnd-setup
./scripts/complete-setup.sh
```

このスクリプトが以下を**対話的に**実行します：
1. 開発環境セットアップ
2. 環境変数ファイル編集支援
3. GitHub認証設定（ブローカー使用時）
4. ファイアウォール設定
5. サービス起動
6. 動作確認

#### 📋 個別セットアップ（上級者向け）

<details>
<summary>個別セットアップ手順を表示</summary>

**ノード1（メインノード）の場合:**
```bash
# 1. 開発環境セットアップ
cd ~/work/bnd-setup
./scripts/setup-dev-environment.sh

# 2. 環境変数ファイル編集
vi node1-main/.env
# 必須設定項目:
# - POSTGRES_PASSWORD=強力なパスワード
# - MINIO_ROOT_PASS=強力なパスワード
# ブローカー使用時のみ:
# - PRIVATE_KEY=0x...
# - RPC_URL=https://...
# - WS_RPC_URL=wss://...
# （コントラクトアドレス等はデフォルト値設定済み）

# 3. ファイアウォール設定
./scripts/setup-firewall-node1.sh

# 4. サービス起動
./scripts/deploy-node1.sh
```

**ノード2（GPUノード）の場合:**
```bash
# 1. 開発環境セットアップ
cd ~/work/bnd-setup
./scripts/setup-dev-environment.sh

# 2. 環境変数ファイル編集
vi node2-gpu/.env
# NODE1_IP=実際のノード1のIPアドレス
# パスワード類をノード1と同じ値に設定

# 3. ファイアウォール設定
./scripts/setup-firewall-node2.sh

# 4. サービス起動
./scripts/deploy-node2.sh
```

</details>

### ステップ3: 動作確認

#### ノード1での確認:
```bash
# サービス状態確認
docker-compose ps

# API動作確認
curl http://localhost:8081/health

# Grafana確認（ブラウザで）
# http://[ノード1のIP]:3000
```

#### ノード2での確認:
```bash
# GPU証明エージェント確認
docker-compose ps | grep gpu_prove_agent

# GPU使用状況確認
nvidia-smi
```

### ステップ4: ブローカー設定（オプション・本格運用時）

**自動化されたZK証明マーケットプレイス参加を行う場合:**

💡 **統合セットアップスクリプト使用時**: GitHub認証設定は自動的に対話形式で実行されます

**手動でブローカー設定する場合:**
```bash
# 詳細手順は「ブローカー起動（本格運用）」セクションを参照
```

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
# ノード1で実行（パスワード認証ベース、IP制限なし）
./setup-firewall-node1.sh

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

## ブローカー起動（本格運用）

ブローカーはBoundlessマーケットプレイスと連携してZK証明を自動化するサービスです。

### 1. 作業ディレクトリの確認・移動
```bash
# 現在のディレクトリ確認
pwd

# bnd-setupディレクトリに移動（どこからでも実行可能）
cd ~/work/bnd-setup

# ディレクトリ構造確認
ls -la
```

### 2. Boundlessプロジェクト準備
```bash
# bnd-setupから一つ上のworkディレクトリに移動
cd ~/work

# ディレクトリ構造確認
ls -la
# 以下のような構造になっているはず：
# ~/work/bnd-setup/         <- このリポジトリ
# ~/work/boundless-custom/  <- カスタムBoundlessプロジェクト（次でクローン）

# カスタムBoundlessプロジェクトのクローン（存在しない場合）
if [ ! -d "boundless-custom" ]; then
    echo "カスタムBoundlessプロジェクトをクローンします..."
    
    # 環境変数から設定を読み込み
    GITHUB_USERNAME=${GITHUB_USERNAME:-}
    GITHUB_TOKEN=${GITHUB_TOKEN:-}
    BOUNDLESS_REPO_URL=${BOUNDLESS_REPO_URL:-"github.com/0xmakase/boundless-custom.git"}
    BOUNDLESS_BRANCH=${BOUNDLESS_BRANCH:-"chore/new-order-lock-feature"}
    
    # 設定ファイルから読み込み（環境変数が設定されていない場合）
    if [ -z "$GITHUB_USERNAME" ] && [ -f ~/.bnd-setup-config ]; then
        source ~/.bnd-setup-config
    fi
    
    # 対話的に設定を取得
    if [ -z "$GITHUB_USERNAME" ]; then
        read -p "GitHubユーザー名を入力してください: " GITHUB_USERNAME
    fi
    
    if [ -z "$GITHUB_TOKEN" ]; then
        read -sp "GitHub Personal Access Tokenを入力してください: " GITHUB_TOKEN
        echo
    fi
    
    if [ -z "$BOUNDLESS_REPO_URL" ]; then
        read -p "Boundlessリポジトリ（デフォルト: github.com/0xmakase/boundless-custom.git）: " REPO_INPUT
        BOUNDLESS_REPO_URL=${REPO_INPUT:-"github.com/0xmakase/boundless-custom.git"}
    fi
    
    if [ -z "$BOUNDLESS_BRANCH" ]; then
        read -p "ブランチ名（デフォルト: chore/new-order-lock-feature）: " BRANCH_INPUT
        BOUNDLESS_BRANCH=${BRANCH_INPUT:-"chore/new-order-lock-feature"}
    fi
    
    # 設定保存確認
    read -p "設定を保存しますか？ [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cat > ~/.bnd-setup-config << EOF
# bnd-setup configuration
GITHUB_USERNAME="$GITHUB_USERNAME"
GITHUB_TOKEN="$GITHUB_TOKEN"
BOUNDLESS_REPO_URL="$BOUNDLESS_REPO_URL"
BOUNDLESS_BRANCH="$BOUNDLESS_BRANCH"
EOF
        chmod 600 ~/.bnd-setup-config
        echo "設定を ~/.bnd-setup-config に保存しました"
    fi
    
    # クローン実行
    echo "リポジトリをクローンしています..."
    git clone https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@${BOUNDLESS_REPO_URL}
    cd boundless-custom
    git checkout ${BOUNDLESS_BRANCH}
    cd ~/work
    
    echo "✓ カスタムBoundlessプロジェクトのクローン完了"
fi

# カスタムBoundlessディレクトリに移動してビルド
cd ~/work/boundless-custom

# Solidity contractsビルド
forge build

# Rust cratesビルド
cargo build --release

# brokerのDockerイメージビルド（ブローカー使用時に必須）
docker build -f dockerfiles/broker.dockerfile -t boundless-broker .

# ビルド確認
docker images | grep boundless-broker

# 開発環境確認
cargo risczero --version
forge --version
```

### 3. ブローカー設定
```bash
# bnd-setupのnode1-mainディレクトリに移動
cd ~/work/bnd-setup/node1-main

# 現在のディレクトリ確認
pwd
# /home/bento/work/bnd-setup/node1-main であることを確認

# 設定ファイル作成
cp broker.toml.example broker.toml

# 設定編集（重要）
vi broker.toml
# 以下の項目を環境に合わせて設定：
# - mcycle_price: 証明価格設定
# - peak_prove_khz: GPU性能設定
# - allow_client_addresses: 許可クライアント
# - timing_mode: 競争戦略
```

### 4. 環境変数確認
```bash
# node1-mainディレクトリで実行
cd ~/work/bnd-setup/node1-main

# .envファイルで以下が設定されていることを確認
cat .env | grep -E "(PRIVATE_KEY|RPC_URL|BOUNDLESS_MARKET_ADDRESS)"

# 必要に応じて設定編集
vi .env
```

### 5. ブローカー起動
```bash
# node1-mainディレクトリで実行
cd ~/work/bnd-setup/node1-main

# 設定確認
docker-compose --profile broker config

# ブローカー起動
docker-compose --profile broker up -d broker

# 起動確認
docker-compose logs -f broker

# ブローカー状態確認
docker-compose ps | grep broker
```

### 6. ブローカー監視・動作確認
```bash
# node1-mainディレクトリで実行
cd ~/work/bnd-setup/node1-main

# ログ監視
docker-compose logs -f broker | grep -E "(order|proof|batch)"

# ブローカーAPI確認
curl http://localhost:8082/health

# データベース確認
docker-compose exec postgres psql -U worker -d taskdb -c "SELECT * FROM orders LIMIT 5;"

# 残高確認（ログ内で警告を確認）
docker-compose logs broker | grep -E "(balance|stake)"
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
   - PostgreSQL、Redis、MinIOのパスワード設定を確認
   - ポート開放状況を確認: `sudo ufw status`

2. **GPU認識エラー**
   - NVIDIA Container Toolkitのインストール確認
   - `docker run --rm --runtime=nvidia --gpus all nvidia/cuda:11.0.3-base-ubuntu20.04 nvidia-smi`

3. **メモリ不足**
   - `free -h`でメモリ使用量確認
   - `docker system prune -f`で不要なイメージ削除

4. **ブローカー関連のトラブル**
   - **Dockerfile not found**: `~/work/boundless`にBoundlessプロジェクトをクローン
     ```bash
     cd ~/work && git clone https://github.com/boundless-xyz/boundless.git
     ```
   - **Build context error**: ディレクトリ構造を確認 (`ls -la ~/work/`)
     - `~/work/bnd-setup/` と `~/work/boundless/` が同じレベルにあること
   - **Environment variables**: `.env`ファイルでPRIVATE_KEY、RPC_URL等を設定
   - **Permission denied**: `broker.toml`の権限を確認 (`chmod 644 broker.toml`)
   - **Connection failed**: Ethereumネットワーク接続とRPC_URLを確認
   - **Balance insufficient**: ウォレット残高（ETH）とステーク残高を確認

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