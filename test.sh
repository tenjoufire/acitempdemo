#!/bin/bash

# Azure Container Instances テンプレートのテストスクリプト
# このスクリプトは各テンプレートを個別にテストします

set -e

# カラーコードの定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ロゴの表示
echo -e "${BLUE}"
echo "  ___   _____ _____   _______        _   "
echo " / _ \ / ____|_   _| |__   __|      | |  "
echo "| | | | |      | |      | | ___  ___| |_ "
echo "| | | | |      | |      | |/ _ \/ __| __|"
echo "| |_| | |____ _| |_     | |  __/\__ \ |_ "
echo " \___/ \_____|_____|    |_|\___||___/\__|"
echo -e "${NC}"
echo "Azure Container Instances Template Tester"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 設定可能な変数
RESOURCE_GROUP_PREFIX=${1:-"rg-aci-test"}
LOCATION=${2:-"japaneast"}
CLEANUP_AFTER_TEST=${3:-"true"}

# 現在の日時を取得
TIMESTAMP=$(date +%Y%m%d%H%M%S)
BASE_RG_NAME="$RESOURCE_GROUP_PREFIX-$TIMESTAMP"

# テスト結果を格納する配列
declare -a TEST_RESULTS

# 関数: ログメッセージの出力
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 関数: Azure CLI のログイン確認
check_azure_login() {
    log_info "Azure 認証状態を確認中..."
    if ! az account show > /dev/null 2>&1; then
        log_error "Azure にログインしていません"
        echo "以下のコマンドでログインしてください:"
        echo "az login"
        exit 1
    fi
    
    local subscription=$(az account show --query name -o tsv)
    log_success "Azure サブスクリプション: $subscription"
}

# 関数: Bicep テンプレートの構文チェック
validate_bicep_syntax() {
    local template_path=$1
    local template_name=$2
    
    log_info "$template_name の構文チェックを実行中..."
    
    if az bicep build --file "$template_path" --outfile "/tmp/$(basename $template_path .bicep).json" > /dev/null 2>&1; then
        log_success "$template_name の構文チェックが成功しました"
        return 0
    else
        log_error "$template_name の構文チェックが失敗しました"
        return 1
    fi
}

# 関数: テンプレートのデプロイテスト
test_template_deployment() {
    local template_dir=$1
    local template_name=$2
    local test_rg_name="$BASE_RG_NAME-$template_name"
    
    log_info "$template_name のデプロイテストを開始..."
    
    # リソースグループの作成
    log_info "テスト用リソースグループを作成: $test_rg_name"
    if ! az group create --name "$test_rg_name" --location "$LOCATION" > /dev/null 2>&1; then
        log_error "リソースグループの作成に失敗しました"
        return 1
    fi
    
    # What-If 分析
    log_info "What-If 分析を実行中..."
    if ! az deployment group what-if \
        --resource-group "$test_rg_name" \
        --template-file "$template_dir/main.bicep" \
        --parameters "$template_dir/main.parameters.json" \
        --parameters containerGroupName="test-$template_name-$TIMESTAMP" > /dev/null 2>&1; then
        log_warning "What-If 分析でエラーが発生しましたが、続行します"
    fi
    
    # 実際のデプロイメント
    log_info "テンプレートをデプロイ中..."
    local deployment_name="test-deployment-$TIMESTAMP"
    if az deployment group create \
        --resource-group "$test_rg_name" \
        --name "$deployment_name" \
        --template-file "$template_dir/main.bicep" \
        --parameters "$template_dir/main.parameters.json" \
        --parameters containerGroupName="test-$template_name-$TIMESTAMP" > /dev/null 2>&1; then
        
        log_success "$template_name のデプロイが成功しました"
        
        # デプロイ結果の取得
        local fqdn=$(az deployment group show --resource-group "$test_rg_name" --name "$deployment_name" --query properties.outputs.fqdn.value -o tsv 2>/dev/null || echo "N/A")
        local url=$(az deployment group show --resource-group "$test_rg_name" --name "$deployment_name" --query properties.outputs.url.value -o tsv 2>/dev/null || echo "N/A")
        
        log_info "デプロイ結果:"
        echo "  📍 FQDN: $fqdn"
        echo "  🔗 URL: $url"
        
        # エンドポイントテスト（URLが利用可能な場合）
        if [[ "$url" != "N/A" ]]; then
            test_endpoint "$url" "$template_name"
        fi
        
        # クリーンアップ
        if [[ "$CLEANUP_AFTER_TEST" == "true" ]]; then
            log_info "リソースグループを削除中: $test_rg_name"
            az group delete --name "$test_rg_name" --yes --no-wait > /dev/null 2>&1
        else
            log_warning "クリーンアップをスキップしました。手動で削除してください: $test_rg_name"
        fi
        
        return 0
    else
        log_error "$template_name のデプロイが失敗しました"
        
        # エラーの詳細を取得
        local error_details=$(az deployment group show --resource-group "$test_rg_name" --name "$deployment_name" --query properties.error.message -o tsv 2>/dev/null || echo "詳細不明")
        log_error "エラーの詳細: $error_details"
        
        # クリーンアップ
        if [[ "$CLEANUP_AFTER_TEST" == "true" ]]; then
            log_info "失敗したリソースグループを削除中: $test_rg_name"
            az group delete --name "$test_rg_name" --yes --no-wait > /dev/null 2>&1
        fi
        
        return 1
    fi
}

# 関数: エンドポイントテスト
test_endpoint() {
    local url=$1
    local template_name=$2
    
    log_info "$template_name のエンドポイントテストを実行中..."
    log_info "URL: $url"
    
    # 最大5分間待機してエンドポイントをテスト
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -f "$url" > /dev/null 2>&1; then
            log_success "エンドポイントが正常に応答しています ($attempt/$max_attempts)"
            return 0
        else
            log_info "エンドポイントの起動を待機中... ($attempt/$max_attempts)"
            sleep 10
            ((attempt++))
        fi
    done
    
    log_warning "エンドポイントのテストがタイムアウトしました"
    return 1
}

# 関数: セキュリティチェック
security_check() {
    log_info "セキュリティチェックを実行中..."
    
    local security_issues=0
    
    # 機密情報のハードコーディングチェック
    log_info "機密情報のハードコーディングをチェック中..."
    if grep -r "password\|secret\|key" ./templates/ --include="*.bicep" --include="*.json" > /dev/null 2>&1; then
        log_warning "機密情報がハードコーディングされている可能性があります"
        grep -r "password\|secret\|key" ./templates/ --include="*.bicep" --include="*.json" || true
        ((security_issues++))
    else
        log_success "機密情報のハードコーディングは検出されませんでした"
    fi
    
    # パブリックアクセスのチェック
    log_info "パブリックアクセス設定をチェック中..."
    if grep -r "\"type\": \"Public\"" ./templates/ --include="*.bicep" --include="*.json" > /dev/null 2>&1; then
        log_warning "パブリックアクセスが設定されています（開発環境では問題ありませんが、本番環境では確認してください）"
        ((security_issues++))
    fi
    
    if [[ $security_issues -eq 0 ]]; then
        log_success "セキュリティチェックが完了しました（問題なし）"
        return 0
    else
        log_warning "セキュリティチェックで $security_issues 件の注意点が見つかりました"
        return 1
    fi
}

# 関数: テスト結果のサマリー表示
show_test_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}📊 テスト結果サマリー${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local total_tests=${#TEST_RESULTS[@]}
    local passed_tests=0
    
    for result in "${TEST_RESULTS[@]}"; do
        if [[ "$result" == *"✅"* ]]; then
            echo -e "${GREEN}$result${NC}"
            ((passed_tests++))
        else
            echo -e "${RED}$result${NC}"
        fi
    done
    
    echo ""
    echo "📈 総テスト数: $total_tests"
    echo "✅ 成功: $passed_tests"
    echo "❌ 失敗: $((total_tests - passed_tests))"
    
    if [[ $passed_tests -eq $total_tests ]]; then
        echo ""
        log_success "すべてのテストが成功しました! 🎉"
        return 0
    else
        echo ""
        log_error "一部のテストが失敗しました"
        return 1
    fi
}

# メイン処理
main() {
    echo "テスト設定:"
    echo "  📂 リソースグループプレフィックス: $RESOURCE_GROUP_PREFIX"
    echo "  🌍 ロケーション: $LOCATION"
    echo "  🧹 テスト後のクリーンアップ: $CLEANUP_AFTER_TEST"
    echo ""
    
    # Azure ログイン確認
    check_azure_login
    echo ""
    
    # セキュリティチェック
    if security_check; then
        TEST_RESULTS+=("✅ セキュリティチェック")
    else
        TEST_RESULTS+=("❌ セキュリティチェック")
    fi
    echo ""
    
    # テンプレートディレクトリの確認
    if [[ ! -d "./templates" ]]; then
        log_error "templates ディレクトリが見つかりません"
        exit 1
    fi
    
    # 各テンプレートのテスト
    for template_dir in ./templates/*/; do
        if [[ -d "$template_dir" ]]; then
            local template_name=$(basename "$template_dir")
            local main_bicep="$template_dir/main.bicep"
            local main_params="$template_dir/main.parameters.json"
            
            log_info "テンプレート '$template_name' をテスト中..."
            
            # 必要なファイルの存在チェック
            if [[ ! -f "$main_bicep" ]]; then
                log_error "$template_name: main.bicep が見つかりません"
                TEST_RESULTS+=("❌ $template_name - main.bicep が見つかりません")
                continue
            fi
            
            if [[ ! -f "$main_params" ]]; then
                log_error "$template_name: main.parameters.json が見つかりません"
                TEST_RESULTS+=("❌ $template_name - main.parameters.json が見つかりません")
                continue
            fi
            
            # 構文チェック
            if ! validate_bicep_syntax "$main_bicep" "$template_name"; then
                TEST_RESULTS+=("❌ $template_name - 構文チェック失敗")
                continue
            fi
            
            # デプロイテスト
            if test_template_deployment "$template_dir" "$template_name"; then
                TEST_RESULTS+=("✅ $template_name - デプロイテスト成功")
            else
                TEST_RESULTS+=("❌ $template_name - デプロイテスト失敗")
            fi
            
            echo ""
        fi
    done
    
    # 結果サマリーの表示
    show_test_summary
}

# ヘルプの表示
show_help() {
    echo "使用方法: $0 [RESOURCE_GROUP_PREFIX] [LOCATION] [CLEANUP_AFTER_TEST]"
    echo ""
    echo "パラメータ:"
    echo "  RESOURCE_GROUP_PREFIX  テスト用リソースグループのプレフィックス (デフォルト: rg-aci-test)"
    echo "  LOCATION              Azure リージョン (デフォルト: japaneast)"
    echo "  CLEANUP_AFTER_TEST    テスト後のクリーンアップ (true/false, デフォルト: true)"
    echo ""
    echo "例:"
    echo "  $0                                    # デフォルト設定でテスト実行"
    echo "  $0 rg-mytest eastus true             # カスタム設定でテスト実行"
    echo "  $0 rg-mytest eastus false            # クリーンアップなしでテスト実行"
    echo ""
    echo "前提条件:"
    echo "  - Azure CLI がインストールされていること"
    echo "  - Azure にログインしていること (az login)"
    echo "  - 必要な権限があること"
}

# ヘルプオプションの処理
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# メイン処理の実行
main
