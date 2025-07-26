# GPUクラウドサービス対応デプロイメント

このドキュメントは、Salad Cloud、RunPod、Vast.ai等のシンプルなGPUクラウドサービスで、node2-gpu（GPU証明専用ノード）を単独コンテナとして実行する手順を説明します。

## 概要

Salad Cloud、RunPod、Vast.ai等のGPUクラウドサービスでは、WebUIでコンテナ設定を行い、単独のDockerイメージを起動するシンプルな方式を採用しています。このドキュメントでは、そのようなサービスでnode2-gpu（GPU証明専用ノード）を実行する設定方法を説明します。

### アーキテクチャ
```
┌─────────────────────────────────┐  ┌─────────────────────────────────┐
│ ノード1: オンプレミス/VPS        │  │ ノード2: コンテナサービス        │
├─────────────────────────────────┤  ├─────────────────────────────────┤
│ [インフラサービス]               │  │ [単独GPU証明コンテナ]           │
│ • PostgreSQL :5432             │  │ • risc0-bento-agent単体         │
│ • Redis      :6379             │  │ • GPU証明処理専用               │
│ • MinIO      :9000             │←─┤ • ブローカー接続対応             │
│                                 │  │                                 │
│ [CPU証明エージェント]            │  │ [環境変数設定]                  │
│ • exec_agent0                  │  │ • NODE1_IP: 外部接続先          │
│ • snark_agent                  │  │ • DB/Redis/MinIO認証情報        │
│                                 │  │ • GPU最適化設定                 │
│ [ブローカー] (Optional)          │  │                                 │
│ • 自動化マーケット参加           │  └─────────────────────────────────┘
└─────────────────────────────────┘
```

## 前提条件

### ノード1（インフラサーバー）
- オンプレミスサーバーまたはVPSで実行
- 通常のDocker Composeデプロイメント
- 外部からの接続受付（パスワード認証）

### ノード2（コンテナサービス）
- GPU対応コンテナサービス（NVIDIA GPU必須）
- 単独イメージ実行のみ対応
- 環境変数による設定

## セットアップ手順

### 1. ノード1のセットアップ

通常通りの手順でセットアップします：

```bash
# 1. 自動セットアップ
export NODE_TYPE=1
curl -fsSL https://raw.githubusercontent.com/liray-unendlich/bnd-setup/main/quick-start.sh | bash

# 2. 環境変数設定
vi node1-main/.env
# POSTGRES_PASSWORD, MINIO_ROOT_PASS等を設定

# 3. ファイアウォール設定（パスワード認証ベース）
./scripts/setup-firewall-node1.sh

# 4. デプロイ実行
./scripts/deploy-node1.sh
```

### 2. ノード2（単独コンテナ）のセットアップ

#### 2.1 環境変数設定

コンテナサービスで以下の環境変数を設定：

```bash
# ノード1接続設定
NODE1_IP=YOUR_NODE1_PUBLIC_IP              # 実際のIPまたはドメイン
DATABASE_URL=postgresql://worker:YOUR_DB_PASS@YOUR_NODE1_IP:5432/taskdb
REDIS_URL=redis://YOUR_NODE1_IP:6379
S3_URL=http://YOUR_NODE1_IP:9000

#認証情報（ノード1と同期）
POSTGRES_USER=worker
POSTGRES_PASSWORD=YOUR_DB_PASS              # ノード1と同じ
POSTGRES_DB=taskdb
MINIO_ROOT_USER=admin
MINIO_ROOT_PASS=YOUR_MINIO_PASS            # ノード1と同じ
MINIO_BUCKET=workflow

# GPU最適化設定
RISC0_KECCAK_PO2=17
CUDA_VISIBLE_DEVICES=0                      # 使用するGPU番号
LD_LIBRARY_PATH=/usr/local/cuda-12.2/compat/

# ログ設定
RUST_LOG=info
RUST_BACKTRACE=1
REDIS_TTL=57600
```

#### 2.2 WebUIでのコンテナ設定

**基本設定項目：**

| 設定項目 | 値 |
|---------|---|
| **コンテナイメージ** | `risczero/risc0-bento-agent:2.3.1@sha256:7873f18005efff03fc5399f1bdcb6760cda7ffbd4fdd4d9c39aedee8972e0a0d` |
| **起動コマンド** | `/app/agent -t prove --redis-ttl 57600` |
| **メモリ制限** | `4GB` (推奨最小値) |
| **CPU制限** | `2-4` cores |
| **GPU要件** | NVIDIA GPU 1台以上 |
| **再起動ポリシー** | `always` または `unless-stopped` |

## GPUクラウドサービス別設定手順

### Salad Cloud

1. **新しいコンテナグループ作成**
   - Dashboard → "Deploy a Container Group"

2. **基本設定**
   - Container Image: `risczero/risc0-bento-agent:2.3.1@sha256:7873f18005efff03fc5399f1bdcb6760cda7ffbd4fdd4d9c39aedee8972e0a0d`
   - Startup Command: `/app/agent -t prove --redis-ttl 57600`

3. **リソース設定**
   - vCPU: 4 (推奨)
   - RAM: 4GB (最小)
   - GPU: 任意のNVIDIA GPU

4. **環境変数設定**
   - 上記「2.1 環境変数設定」の全変数を設定

5. **ネットワーク設定**
   - Networking: Public (デフォルト)
   - Exposed Ports: 不要

### RunPod

1. **新しいポッド作成**
   - Templates → "New Template" または "Deploy Pod"

2. **コンテナ設定**
   - Docker Image: `risczero/risc0-bento-agent:2.3.1@sha256:7873f18005efff03fc5399f1bdcb6760cda7ffbd4fdd4d9c39aedee8972e0a0d`
   - Docker Command: `/app/agent -t prove --redis-ttl 57600`

3. **リソース設定**
   - GPU Type: RTX 3090 / RTX 4090 / A6000 等
   - Container Disk: 10GB (最小)
   - Volume Disk: 不要

4. **環境変数設定**
   - Environment Variables セクションで上記変数を設定

### Vast.ai

#### Vast.aiのUI設定項目対応表

| Docker Compose設定 | Vast.ai UI設定項目 | 設定値 |
|-------------------|------------------|-------|
| `image` | **Docker Image** | `risczero/risc0-bento-agent:2.3.1@sha256:7873f18005efff03fc5399f1bdcb6760cda7ffbd4fdd4d9c39aedee8972e0a0d` |
| `entrypoint` | **On-start script** | `/app/agent -t prove --redis-ttl 57600` |
| `mem_limit: 4G` | **RAM** | 4GB以上を選択 |
| `cpus: 4` | **vCPUs** | 4コア以上を選択 |
| `runtime: nvidia` | **GPU Type** | 任意のNVIDIA GPU |
| `environment` | **Env** | 下記の環境変数を設定 |
| `restart: always` | **Auto-restart** | ON (利用可能な場合) |

#### 具体的な設定手順

1. **インスタンス検索・選択**
   - Search → GPU種別（RTX 3090, RTX 4090, A6000等）とリージョンを選択
   - RAM: 4GB以上、vCPU: 4コア以上のインスタンスを選択

2. **基本設定**
   - **Docker Image**: `risczero/risc0-bento-agent:2.3.1@sha256:7873f18005efff03fc5399f1bdcb6760cda7ffbd4fdd4d9c39aedee8972e0a0d`
   - **Launch Mode**: "Docker"
   - **Run Interactive**: OFF

3. **On-start script設定**
   ```bash
   /app/agent -t prove --redis-ttl 57600
   ```

4. **Docker options設定**
   ```bash
   --runtime=nvidia --gpus all --memory=4g --cpus=4 --restart=always
   ```

5. **Ports設定**
   - ポート開放は不要（空欄のまま）

6. **Env設定**
   以下の環境変数を一行ずつ設定：
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
   LD_LIBRARY_PATH=/usr/local/cuda-12.2/compat/
   RUST_LOG=info
   RUST_BACKTRACE=1
   REDIS_TTL=57600
   ```

#### 設定例スクリーンショット風ガイド

**Docker Image欄:**
```
risczero/risc0-bento-agent:2.3.1@sha256:7873f18005efff03fc5399f1bdcb6760cda7ffbd4fdd4d9c39aedee8972e0a0d
```

**Docker options欄:**
```
--runtime=nvidia --gpus all --memory=4g --cpus=4 --restart=always
```

**On-start script欄:**
```
/app/agent -t prove --redis-ttl 57600
```

**Env欄（各行を個別に追加）:**
```
NODE1_IP=192.168.1.100
DATABASE_URL=postgresql://worker:secure_password@192.168.1.100:5432/taskdb
REDIS_URL=redis://192.168.1.100:6379
S3_URL=http://192.168.1.100:9000
S3_BUCKET=workflow
S3_ACCESS_KEY=admin
S3_SECRET_KEY=secure_minio_pass
RISC0_KECCAK_PO2=17
CUDA_VISIBLE_DEVICES=0
LD_LIBRARY_PATH=/usr/local/cuda-12.2/compat/
RUST_LOG=info
RUST_BACKTRACE=1
REDIS_TTL=57600
```

**Ports欄:**
```
(空欄 - ポート開放不要)
```

### その他のサービス

**一般的なWebUI設定項目：**
- **Image/Repository**: `risczero/risc0-bento-agent:2.3.1@sha256:7873f18005efff03fc5399f1bdcb6760cda7ffbd4fdd4d9c39aedee8972e0a0d`
- **Command**: `/app/agent -t prove --redis-ttl 57600`
- **Memory**: 4GB以上
- **CPU**: 2-4コア
- **GPU**: NVIDIA GPU必須
- **Environment Variables**: 上記の全環境変数を設定

## ブローカー接続設定

コンテナサービスでの運用時は、ノード1でブローカーを起動し、GPU証明処理をnode2-gpuコンテナで実行します。

### ブローカー有効化（ノード1）

```bash
# ブローカー設定ファイル編集
cd node1-main
cp broker.toml.example broker.toml
vi broker.toml

# 主要設定項目
[market]
mcycle_price = "0.000000000010000000"  # 価格設定
peak_prove_khz = 700                   # GPU証明性能
max_concurrent_proofs = 1              # 同時証明数

[prover]
risc0_prover = "remote"               # リモート証明使用
executor_cores = 4                    # CPU実行コア数

# ブローカー起動
docker-compose --profile broker up -d broker
```

### 接続確認

```bash
# ノード1からノード2（コンテナ）への接続確認
# Redis接続テスト
redis-cli -h YOUR_NODE1_IP -p 6379 ping

# PostgreSQL接続テスト
psql -h YOUR_NODE1_IP -U worker -d taskdb -c "SELECT 1;"

# MinIO接続テスト
curl http://YOUR_NODE1_IP:9000/minio/health/live
```

## 監視とトラブルシューティング

### 監視方法

#### Salad Cloud
- Dashboard → Container Groups → 該当グループ → "Logs" タブ
- リアルタイムログとダウンロード機能を提供

#### RunPod
- Pods → 該当ポッド → "Logs" タブ
- ターミナルアクセスも可能（必要に応じて）

#### Vast.ai
- Instances → 該当インスタンス → "Logs"
- SSH接続でのログ確認: `docker logs <container_id>`

#### 一般的な確認事項
```bash
# 証明処理の動作確認（ログ出力例）
INFO bento_agent: Connecting to Redis at redis://[NODE1_IP]:6379
INFO bento_agent: Starting prove agent
INFO risc0_circuit_keccak: Initializing GPU acceleration
INFO bento_agent: Waiting for proof requests...
```

### よくある問題

1. **コンテナが起動しない**
   - 環境変数の設定漏れ確認
   - NODE1_IPが正しく設定されているか確認
   - イメージ名とタグの確認

2. **ノード1への接続エラー**
   - ノード1のファイアウォール設定確認
   - パスワード認証情報の一致確認
   - ノード1の各サービス起動状況確認

3. **GPU認識エラー**
   - サービス側のGPU対応インスタンス選択確認
   - CUDA_VISIBLE_DEVICES設定確認
   - ログでGPU初期化メッセージ確認

4. **証明処理が開始されない**
   - Redis/PostgreSQL接続状況をログで確認
   - ノード1で証明タスクが投入されているか確認
   - ブローカー設定（使用している場合）確認

### パフォーマンス最適化

#### メモリ・GPU最適化
- **高性能GPU使用時**: メモリを8GB以上に設定、`RISC0_KECCAK_PO2=18`に変更
- **複数GPU環境**: 各GPUに対して個別コンテナを起動
- **CPU設定**: GPU性能に応じて4-8コアに調整

#### 複数インスタンス運用
- **Salad Cloud**: 複数のContainer Groupを作成、各々に異なる`CUDA_VISIBLE_DEVICES`設定
- **RunPod**: 複数Podを起動、GPU種別を変えて負荷分散
- **Vast.ai**: 複数インスタンスでコスト効率の良いGPUを選択

#### 推奨GPU構成
- **エントリー**: RTX 3070/3080 (4-8GB VRAM)
- **標準**: RTX 3090/4090 (24GB VRAM)
- **高性能**: A6000/A100 (48-80GB VRAM)

## セキュリティ考慮事項

### 認証情報保護
- **環境変数暗号化**: サービス提供者の暗号化機能を使用
- **パスワード強度**: 32文字以上の強固なパスワード設定
- **定期ローテーション**: データベース・MinIOパスワードの定期変更

### ネットワークセキュリティ
- **ノード1要塞化**: ファイアウォール設定でGrafana以外の外部アクセス制限
- **接続元制限**: 可能であればGPUクラウドサービスのIPレンジ制限
- **TLS化**: プロダクション環境でのHTTPS/TLS接続推奨

### 運用セキュリティ
- **アクセス制御**: GPUクラウドサービスのアカウント保護
- **監査ログ**: コンテナ実行ログの定期的な確認
- **コスト監視**: 予期しない大量実行の早期検出

### プライバシー保護
- **データ暗号化**: ZK証明データの暗号化保存
- **ログ管理**: 機密情報がログに含まれないよう設定
- **データ保持期間**: 処理完了後の自動データ削除設定

この構成により、Salad Cloud等のシンプルなGPUクラウドサービスでも、セキュアで効率的なZK証明処理環境を実現できます。
