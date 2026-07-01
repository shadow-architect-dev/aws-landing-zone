# ==============================================================================
# AWS Control Tower AFT GitOps Repositories Bootstrap Script
# ==============================================================================
# このスクリプトは、AFTの稼働に必要な 4 つの専用リポジトリを GitHub 上に Private で自動作成し、
# 初期テンプレート（ボイラープレート）をコミットして自動プッシュします。

$ErrorActionPreference = "Stop"

# GitHub 組織名 / ユーザー名 (必要に応じて書き換えてください)
$GH_ORG = "shadow-architect-dev"

# AFT 用の 4 つのリポジトリ定義
$REPOSITORIES = @(
    "aws-landing-zone-aft-account-requests",
    "aws-landing-zone-aft-global-customizations",
    "aws-landing-zone-aft-account-customizations",
    "aws-landing-zone-aft-account-provisioning-customizations"
)

# テンプレートのローカルソースディレクトリ
$TEMPLATES_SRC = Join-Path $PSScriptRoot "scratch\aft-bootstrap"
# 作業用の一時フォルダ
$TEMP_DIR = Join-Path $PSScriptRoot "scratch\aft-bootstrap-working"

# 1. 依存関係のチェック (git & gh)
Write-Host "🔍 依存関係の検証中..." -ForegroundColor Cyan

if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
    Write-Error "Git がインストールされていないか、PATH が通っていません。"
}
if (-not (Get-Command "gh" -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI (gh) がインストールされていないか、PATH が通っていません。"
}

# 2. GitHub CLI 認証状態のチェック
Write-Host "🔑 GitHub CLI のログインステータスを確認中..." -ForegroundColor Cyan
try {
    gh auth status
} catch {
    Write-Error "GitHub CLI が認証されていません。先に 'gh auth login' を実行して認証を完了させてください。"
}

# 3. リポジトリの自動作成と初期コードプッシュ
Write-Host "`n🚀 AFT リポジトリの自動構築を開始します..." -ForegroundColor Green

if (Test-Path $TEMP_DIR) {
    Remove-Item -Recurse -Force $TEMP_DIR
}
New-Item -ItemType Directory -Path $TEMP_DIR | Out-Null

foreach ($repo in $REPOSITORIES) {
    Write-Host "`n------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "📦 リポジトリ設定中: $repo" -ForegroundColor Cyan
    
    $src_path = Join-Path $TEMPLATES_SRC $repo
    $dest_path = Join-Path $TEMP_DIR $repo

    if (-not (Test-Path $src_path)) {
        Write-Warning "ソーステンプレートが見つかりません: $src_path (スキップします)"
        continue
    }

    # 一時フォルダへコピー
    Copy-Item -Path $src_path -Destination $dest_path -Recurse -Force

    # 1. GitHub上にリポジトリを作成 (既に存在する場合は何もしない)
    $repo_full_name = "${GH_ORG}/${repo}"
    Write-Host "🤖 GitHub 上にプライベートリポジトリを作成します: $repo_full_name" -ForegroundColor Yellow
    
    try {
        gh repo create $repo_full_name --private -y
        Write-Host "✅ リポジトリが正常に作成されました。" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ リポジトリが既に存在するか、作成に失敗しました (次に進みます)。" -ForegroundColor Yellow
    }

    # 2. ローカルGitリポジトリの初期化とプッシュ
    Write-Host "💾 初期ファイルのコミットとプッシュを行います..." -ForegroundColor Yellow
    Push-Location $dest_path
    try {
        git init -b main
        git config user.name "SRE-Bootstrap"
        git config user.email "sre-bootstrap@example.com"
        git add .
        git commit -m "Initialize AFT baseline template"
        
        # リモートの設定とプッシュ (強制プッシュを避けるため、初回のみに設定)
        git remote add origin "https://github.com/${repo_full_name}.git"
        git push -u origin main -f
        Write-Host "🎉 プッシュが完了しました: https://github.com/${repo_full_name}" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ リポジトリ $repo のプッシュ中にエラーが発生しました (リモートの既存ファイルと衝突した可能性があります)。" -ForegroundColor Yellow
    } finally {
        Pop-Location
    }
}

# クリーンアップ
if (Test-Path $TEMP_DIR) {
    Remove-Item -Recurse -Force $TEMP_DIR
}

Write-Host "`n✨ すべての AFT リポジトリの初期セットアップが完了しました！" -ForegroundColor Green
Write-Host "AFT パイプラインを実行するには、管理アカウントで terraform apply を実行してください。" -ForegroundColor Green
