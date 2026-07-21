# wbgt-swiftbar

岡山大学 津島キャンパスの屋外 **WBGT（暑さ指数）** を macOS のメニューバーに表示する [SwiftBar](https://github.com/swiftbar/SwiftBar) プラグインです。

```
🟥WBGT 32.6
```

クリックすると気温・湿度・観測時刻と、環境省の運動指針にもとづく危険度が表示されます。

## 表示区分

| WBGT | 表示 | 区分 |
|---|---|---|
| 35.0 以上 | 💀 紫 | 災害級の酷暑（屋外活動は全面中止） |
| 31.0 以上 | 🟥 赤 | 危険（運動は原則中止） |
| 28.0 以上 | 🟧 橙 | 厳重警戒（激しい運動は中止） |
| 25.0 以上 | 🟨 黄 | 警戒（積極的に休憩） |
| 21.0 以上 | 🟩 緑 | 注意 |
| 21.0 未満 | 🟦 青 | ほぼ安全 |

データが1時間以上更新されていない場合は `⚠︎` が付きます。

## インストール

ターミナルに以下を貼り付けて実行するだけです。

```sh
brew install --cask swiftbar
mkdir -p ~/SwiftBarPlugins
curl -fsSL -o ~/SwiftBarPlugins/wbgt-tsushima.10m.sh \
  https://raw.githubusercontent.com/Adatchan/wbgt-swiftbar/main/wbgt-tsushima.10m.sh
chmod +x ~/SwiftBarPlugins/wbgt-tsushima.10m.sh
open -a SwiftBar
```

SwiftBar を初めて起動すると**プラグインフォルダを選ぶダイアログ**が出ます。ここで `~/SwiftBarPlugins` を選んでください（`Command + Shift + G` で `~/SwiftBarPlugins` と入力すると早いです）。

数秒でメニューバーに `🟥WBGT 33.2` のような表示が出れば成功です。

<details>
<summary>Homebrew を使わない場合</summary>

1. [SwiftBar のリリースページ](https://github.com/swiftbar/SwiftBar/releases)から `SwiftBar.zip` をダウンロードして、`SwiftBar.app` を「アプリケーション」フォルダに入れる
2. このリポジトリの `wbgt-tsushima.10m.sh` を[ダウンロード](https://raw.githubusercontent.com/Adatchan/wbgt-swiftbar/main/wbgt-tsushima.10m.sh)（右クリック →「リンク先のファイルをダウンロード」）
3. SwiftBar を起動し、プラグインフォルダを指定する
4. ダウンロードしたファイルをそのフォルダに入れ、ターミナルで実行権限を付ける

```sh
chmod +x ~/SwiftBarPlugins/wbgt-tsushima.10m.sh
```
</details>

### 更新間隔を変えたい場合

ファイル名の `10m` が更新間隔です。ただし**短くしないでください**（理由は[サーバーへの配慮について](#サーバーへの配慮について)）。

### アンインストール

```sh
rm ~/SwiftBarPlugins/wbgt-tsushima.10m.sh
rm -rf ~/Library/Caches/wbgt-swiftbar
```

## データ提供元

岡山大学スポーツ教育センター「みえる！熱中症リスク」プロジェクト
<http://isec.cc.okayama-u.ac.jp/wbgt/wbgtDetail_tsushima.html>

## サーバーへの配慮について

**本プラグインは非公式のツールであり、岡山大学およびデータ提供元とは一切関係ありません。**

データ提供元への負荷を抑えるため、以下の設計にしています。改変する場合も維持してください。

- **取得間隔は10分**。元データの更新間隔が約10分のため、これより短くしても新しい値は得られず、負荷が増えるだけです。ファイル名を `.1m.sh` などに変更しないでください。
- **条件付きGET（`If-None-Match`）を使用**。データが更新されていない場合はサーバーが `304 Not Modified` を返し、本文の転送は発生しません。キャッシュは `~/Library/Caches/wbgt-swiftbar/` に保存されます。
- **User-Agent にこのリポジトリの URL を記載**。サーバー管理者がアクセス元を特定し、必要なら連絡できるようにするためです。
- **取得したデータ自体はこのリポジトリに含めません。** 再配布ではなく、取得スクリプトのみを公開しています。

データ提供元から停止の要請があった場合、本リポジトリは速やかに公開を停止します。

## ライセンス

MIT License（このスクリプトについて）。取得されるデータの権利はデータ提供元に帰属します。
