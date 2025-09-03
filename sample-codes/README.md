# ウェブページPDF化ツール

ウェブページにアクセスして、header、footer、sidebarなどの不要な要素を除いた**メインコンテンツのみ**をPDF化するRubyスクリプトです。

## ✨ 特徴

- 🎯 **メインコンテンツのみ抽出**: header、footer、sidebar、広告などを自動除去
- 🖼️ **画像も含めて変換**: 記事内の画像も含めてPDF化
- 🎨 **美しいレイアウト**: 読みやすい日本語対応レイアウト
- 🔄 **2段階アプローチ**: 直接PDF生成 → 失敗時はHTML生成 → 手動変換
- 🚫 **外部依存最小限**: Puppeteerやwkhtmltopdfは不要

## 📋 必要な環境

- Ruby 3.0+
- Google Chrome または Chromium（Ferrumが使用）
- bundler gem

## 🚀 セットアップ

```bash
# 1. リポジトリをクローンまたはファイルをダウンロード
git clone <このリポジトリのURL>
cd web-to-pdf-converter

# 2. 必要なGemをインストール
bundle install
```

## 📖 使用方法

### 基本的な使用方法

```bash
# デフォルトページ（建設業許可の記事）をPDF化
ruby complete_pdf_scraper.rb

# 任意のURLをPDF化
ruby complete_pdf_scraper.rb https://example.com

# ファイル名も指定
ruby complete_pdf_scraper.rb https://example.com my_article


ruby complete_pdf_scraper.rb https://activation-service.jp/iso/column/8334
```

### コマンドライン引数

| 引数 | 説明 | 例 |
|------|------|-----|
| なし | デフォルトURLを使用 | `ruby complete_pdf_scraper.rb` |
| URL | 指定URLをPDF化 | `ruby complete_pdf_scraper.rb https://example.com` |
| URL + ファイル名 | URLとファイル名を指定 | `ruby complete_pdf_scraper.rb https://example.com article` |

### ヘルプ表示

```bash
ruby complete_pdf_scraper.rb --help
```

## 🔄 変換プロセス

### 方法1: 直接PDF生成
スクリプトがChromeの内蔵PDF機能を使用して自動的にPDFを生成します。

### 方法2: HTML生成 → 手動変換
直接PDF生成に失敗した場合、きれいにフォーマットされたHTMLファイルを生成し、以下の手順で手動変換できます：

1. **HTMLファイルを開く**
   ```bash
   open filename.html  # macOS
   ```

2. **ブラウザの印刷機能を使用**
   - macOS: `Cmd+P`
   - Windows/Linux: `Ctrl+P`

3. **印刷設定**
   - 送信先: 「PDFとして保存」
   - レイアウト: 縦向き
   - 用紙サイズ: A4
   - 余白: 標準
   - オプション: 「背景のグラフィック」にチェック

4. **保存してPDF化完了**

## 📁 出力ファイル

- **PDFファイル**: `filename.pdf`
- **HTMLファイル**: `filename.html` （PDF生成失敗時）

## 🎨 除去される要素

以下の要素が自動的に除去されます：

- ヘッダー・フッター・ナビゲーション
- サイドバー・メニュー
- パンくずリスト
- SNSシェアボタン
- 関連記事・コメント欄
- 広告・バナー
- ポップアップ・モーダル
- クッキー通知

## 🛠️ トラブルシューティング

### Chrome/Chromiumがない場合

```bash
# macOSの場合
brew install --cask google-chrome

# Ubuntuの場合
sudo apt-get install google-chrome-stable

# 既存インストールの確認
ls /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome  # macOS
which google-chrome  # Linux
```

### Gemのインストールエラー

```bash
# Bundlerがない場合
gem install bundler

# 古いGemfile.lockを削除
rm Gemfile.lock
bundle install
```

### 権限エラー

```bash
# macOSでのセキュリティ設定
sudo xattr -r -d com.apple.quarantine /Applications/Google\ Chrome.app
```

## 📝 カスタマイズ

### 除去要素の追加

`clean_page_for_pdf`メソッド内の`selectorsToRemove`配列に追加：

```javascript
const selectorsToRemove = [
  // 既存の要素...
  '.your-custom-selector',
  '#your-custom-id'
];
```

### スタイルの変更

`style.textContent`内のCSSを編集してレイアウトをカスタマイズできます。

## 📄 ライセンス

MIT License

## 🤝 貢献

Issue や Pull Request を歓迎します。

## 📞 サポート

問題が発生した場合は、以下の情報と共にIssueを作成してください：

- OS バージョン
- Ruby バージョン
- Chrome バージョン
- エラーメッセージ
- 対象URL（可能であれば）