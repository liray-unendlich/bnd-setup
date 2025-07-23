# 分散デプロイメント詳細ガイド

## アーキテクチャ詳細

### サービス依存関係
```
外部 → REST API → PostgreSQL
    → Grafana  → PostgreSQL, Redis
    → Broker   → REST API, PostgreSQL, Redis, MinIO
    
エージェント → PostgreSQL, Redis, MinIO
GPU Agent   → PostgreSQL@Node1, Redis@Node1, MinIO@Node1
```

### データフロー
1. 外部リクエスト → REST API
2. タスクキュー → Redis
3. エージェント → Redis からタスク取得
4. 結果保存 → PostgreSQL, MinIO
5. GPU処理 → ノード2で実行

## パフォーマンス最適化

### リソース調整
```bash
# CPUエージェント数の調整
docker-compose up -d --scale exec_agent0=4

# GPUエージェント数の調整  
docker-compose up -d --scale gpu_prove_agent0=2
```

### メモリ制限調整
各サービスの`mem_limit`を環境に応じて調整してください。

## 高可用性設定

### PostgreSQLレプリケーション
本構成では単一PostgreSQLインスタンスを使用していますが、本番環境では以下を検討してください:
- PostgreSQLクラスタリング
- 自動フェイルオーバー設定

### Redis Cluster
高可用性が必要な場合はRedis Clusterの導入を検討してください。

## ログ管理

### ログローテーション設定
```bash
# Dockerログローテーション設定
cat >> /etc/docker/daemon.json << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "5"
  }
}
EOF
sudo systemctl restart docker
```

### 集約ログ設定（オプション）
FluentdやELKスタックを使用したログ集約の設定例は別途提供予定です。