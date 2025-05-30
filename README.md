# Azure Container Instances Deployment Environment Catalog

Azure Deployment Environment のための Azure Container Instances カタログです。開発者が簡単にコンテナ化されたアプリケーションをデプロイできるシンプルなテンプレートを提供します。

## 📋 カタログ概要

このカタログには以下のテンプレートが含まれています：

### シンプル ACI テンプレート (`aci-simple`)
- 基本的な Azure Container Instances のデプロイメント
- パブリック IP アドレスの自動割り当て
- DNS 名の自動生成
- 軽量なアプリケーション向け
- プロトタイプや開発環境に最適

## 🏗️ アーキテクチャ

```
Azure Deployment Environment
│
├── Catalog (catalog.yaml)
│
├── Templates
│   └── aci-simple/
│       ├── main.bicep
│       ├── main.parameters.json
│       └── README.md
│
├── deploy.sh (デプロイスクリプト)
└── README.md
```

## 🚀 クイックスタート

### 前提条件

- Azure CLI がインストールされていること
- Azure サブスクリプションへのアクセス権限
- リソースグループの作成権限

### 1. シンプル ACI のデプロイ

```bash
# リポジトリのクローン
git clone https://github.com/your-org/aci-catalog.git
cd aci-catalog

# シンプル ACI のデプロイ
./deploy.sh "rg-aci-demo" "japaneast" "aci-simple" "my-aci-app" "development"
```

### 2. Azure CLI での個別デプロイ

```bash
# リソースグループの作成
az group create --name rg-aci-demo --location japaneast

# Bicep テンプレートの直接デプロイ
az deployment group create \
  --resource-group rg-aci-demo \
  --template-file ./templates/aci-simple/main.bicep \
  --parameters ./templates/aci-simple/main.parameters.json
```

## 📊 テンプレート機能

### aci-simple テンプレート

| 機能 | 対応状況 |
|------|----------|
| **基本機能** | |
| コンテナデプロイ | ✅ |
| パブリック IP | ✅ |
| DNS 名 | ✅ |
| 環境変数 | ✅ |
| **用途** | |
| プロトタイプ | ✅ |
| 開発環境 | ✅ |
| ステージング | ⚠️ |
| 本番環境 | ❌ |

このテンプレートは軽量なコンテナアプリケーションに最適で、素早く環境を立ち上げることができます。

## 🔧 カスタマイズ

### パラメータのカスタマイズ

各テンプレートの `main.parameters.json` ファイルを編集して、アプリケーションに合わせてカスタマイズできます：

```json
{
  "containerImage": {
    "value": "your-registry.azurecr.io/your-app:latest"
  },
  "cpuCores": {
    "value": 2
  },
  "memoryInGb": {
    "value": 4
  }
}
```

### 環境変数の追加

Bicep テンプレート内で環境変数を追加できます：

```bicep
environmentVariables: [
  {
    name: 'API_KEY'
    secureValue: keyVaultSecret
  },
  {
    name: 'DATABASE_URL'
    value: databaseConnectionString
  }
]
```

## 🔐 セキュリティ考慮事項

### 推奨設定

1. **機密情報の管理**
   - Azure Key Vault を使用
   - Managed Identity の活用
   - 環境変数での機密情報保存を避ける

2. **ネットワークセキュリティ**
   - 本番環境では Private IP の使用を検討
   - Network Security Groups の適用
   - Virtual Network 統合

3. **イメージセキュリティ**
   - 信頼できるレジストリの使用
   - 定期的なイメージ更新
   - 脆弱性スキャンの実施

### セキュリティチェックリスト

- [ ] 機密情報は Azure Key Vault に保存
- [ ] Managed Identity を使用
- [ ] 最新のベースイメージを使用
- [ ] HTTPS 通信を強制
- [ ] 不要なポートを開放しない
- [ ] ログ監視を有効化

## 📈 監視とログ

### Azure Monitor 統合

```bicep
// Application Insights の追加
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appinsights-${containerGroupName}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}
```

### ログ収集

```bash
# コンテナログの確認
az container logs --resource-group myResourceGroup --name myContainerGroup

# リアルタイムログの表示
az container logs --resource-group myResourceGroup --name myContainerGroup --follow
```

## 🧪 テスト

### デプロイメントテスト

```bash
# テンプレートの構文チェック
az deployment group validate \
  --resource-group rg-test \
  --template-file ./templates/aci-simple/main.bicep \
  --parameters ./templates/aci-simple/main.parameters.json

# What-if 分析
az deployment group what-if \
  --resource-group rg-test \
  --template-file ./templates/aci-simple/main.bicep \
  --parameters ./templates/aci-simple/main.parameters.json
```

### 動作確認

```bash
# エンドポイントの疎通確認
curl -I http://your-aci-app.japaneast.azurecontainer.io

# ヘルスチェック
curl http://your-aci-app.japaneast.azurecontainer.io/health
```

## 🚨 トラブルシューティング

### よくある問題と解決法

1. **デプロイメントの失敗**
   ```bash
   # デプロイメント履歴の確認
   az deployment group list --resource-group myResourceGroup
   
   # エラーの詳細確認
   az deployment group show --resource-group myResourceGroup --name deploymentName
   ```

2. **コンテナの起動失敗**
   ```bash
   # コンテナの状態確認
   az container show --resource-group myResourceGroup --name myContainer
   
   # イベントログの確認
   az container show --resource-group myResourceGroup --name myContainer --query instanceView.events
   ```

3. **ネットワーク接続の問題**
   ```bash
   # DNS 解決の確認
   nslookup your-app.japaneast.azurecontainer.io
   
   # ポート接続の確認
   telnet your-app.japaneast.azurecontainer.io 80
   ```

## 💰 料金最適化

### コスト削減のヒント

1. **リソースサイズの最適化**
   - 必要最小限の CPU/メモリを設定
   - 使用量監視による適切なサイジング

2. **スケジューリング**
   - 開発環境は夜間停止
   - オートスケーリングの活用

3. **ストレージ最適化**
   - 適切なストレージティアの選択
   - 不要なデータの定期削除

## 🤝 貢献

このカタログへの貢献を歓迎します！

### 貢献方法

1. リポジトリをフォーク
2. フィーチャーブランチを作成
3. 変更をコミット
4. プルリクエストを作成

### 開発ガイドライン

- Bicep のベストプラクティスに従う
- 適切なドキュメントを追加
- テンプレートのテストを実施
- セキュリティ要件を満たす

## 📞 サポート

- 🐛 バグ報告: [Issues](https://github.com/your-org/aci-catalog/issues)
- 💡 機能要望: [Feature Requests](https://github.com/your-org/aci-catalog/discussions)
- 📚 ドキュメント: [Wiki](https://github.com/your-org/aci-catalog/wiki)

## 📄 ライセンス

このプロジェクトは [MIT License](LICENSE) の下で公開されています。

## 🎯 ロードマップ

- [ ] Azure Service Bus 統合テンプレート
- [ ] Azure SQL Database 統合テンプレート
- [ ] Multi-container テンプレート
- [ ] GPU 対応テンプレート
- [ ] ARM テンプレート版の提供
