#!/bin/bash
# 岡山大学 津島キャンパス 屋外WBGT (10分ごと更新)
# データ元: 岡山大学スポーツ教育センター「みえる！熱中症リスク」プロジェクト
#           http://isec.cc.okayama-u.ac.jp/wbgt/wbgtDetail_tsushima.html
#
# 非公式ツールです。データ提供元とは無関係です。
# 取得間隔を10分より短くしないでください(元データの更新も約10分間隔です)。

URL="http://isec.cc.okayama-u.ac.jp/wbgt/gaitou.csv"
PAGE="http://isec.cc.okayama-u.ac.jp/wbgt/wbgtDetail_tsushima.html"
UA="wbgt-swiftbar/1.2 (+https://github.com/Adatchan/wbgt-swiftbar)"

CACHE_DIR="$HOME/Library/Caches/wbgt-swiftbar"
mkdir -p "$CACHE_DIR"
BODY="$CACHE_DIR/gaitou.csv"
ETAG_FILE="$CACHE_DIR/gaitou.etag"

# 一時ファイルはPIDで分ける。10分ごとの自動更新と「今すぐ更新」が同時に
# 走っても、互いの書きかけのファイルを壊さないようにするため。
TMP_BODY="$CACHE_DIR/gaitou.csv.$$.tmp"
TMP_HDR="$CACHE_DIR/gaitou.hdr.$$.tmp"
trap 'rm -f "$TMP_BODY" "$TMP_HDR"' EXIT INT TERM
# 強制終了などで残った古い一時ファイルを掃除する
find "$CACHE_DIR" -name '*.tmp' -mmin +60 -delete 2>/dev/null

# CSVから「WBGT(第5列)まで数値がそろった行」だけを取り出す。
#  - 行末のCRを除去する(データ元がCRLFに変わっても動くように)
#  - 冬季は負のWBGT(例: -1.2)があるため符号を許容する
valid_rows() {
  awk -F, '{ sub(/\r$/, "") }
           NF >= 5 && $5 ~ /^-?[0-9]+(\.[0-9]+)?$/' "$1" 2>/dev/null
}

# --- 条件付きGET: 更新がなければ304が返り、転送量ゼロでキャッシュを使う ---
etag=""
[ -f "$ETAG_FILE" ] && [ -s "$BODY" ] && etag=$(cat "$ETAG_FILE")

# 引数は配列で組み立てる。${etag:+-H "..."} という書き方はシェルによって
# 単語分割の結果が変わり、zshではヘッダ先頭に空白が入って400になるため。
curl_args=(-sf --max-time 15 -A "$UA" -D "$TMP_HDR" -o "$TMP_BODY" -w '%{http_code}')
if [ -n "$etag" ]; then
  curl_args+=(-H "If-None-Match: $etag")
fi

code=$(curl "${curl_args[@]}" "$URL")
curl_rc=$?

# curlが正常終了(=途中切断でない)し、200で、かつ完全な行を含む場合だけ
# キャッシュを更新する。
if [ "$curl_rc" = "0" ] && [ "$code" = "200" ] && valid_rows "$TMP_BODY" | grep -q .; then
  mv -f "$TMP_BODY" "$BODY"
  new_etag=$(grep -i '^etag:' "$TMP_HDR" | tail -1 | tr -d '\r' \
             | sed 's/^[Ee][Tt][Aa][Gg]:[[:space:]]*//')
  if [ -n "$new_etag" ]; then
    printf '%s' "$new_etag" > "$ETAG_FILE"
  else
    rm -f "$ETAG_FILE"
  fi
fi
# 304 や通信失敗のときは何もしない(既存キャッシュをそのまま使う)

line=$(valid_rows "$BODY" | tail -1)

if [ -z "$line" ]; then
  echo "WBGT --"
  echo "---"
  echo "データ取得に失敗しました | color=red"
  echo "詳細ページを開く | href=$PAGE"
  exit 0
fi

datetime=$(echo "$line" | cut -d, -f1)
temp=$(echo "$line" | cut -d, -f2)
humid=$(echo "$line" | cut -d, -f3)
wbgt=$(echo "$line" | cut -d, -f5)

# 更新が60分以上古い場合は注意表示。
# 観測時刻はJST固定なので、Macのタイムゾーンが日本以外でもずれないよう
# TZを明示して解釈する(now_epochはタイムゾーンに依存しない)。
now_epoch=$(date +%s)
data_epoch=$(TZ=Asia/Tokyo date -j -f "%Y/%m/%d %H:%M:%S" "$datetime" +%s 2>/dev/null || echo 0)
stale=""
if [ $((now_epoch - data_epoch)) -gt 3600 ]; then
  stale=" ⚠︎"
fi

# 色分けの基準:
#   21.0〜31.0℃ … 環境省「熱中症予防運動指針」の4区分
#   35.0℃以上   … 運動指針には無い区分。環境省「熱中症特別警戒アラート」の
#                  発表基準(WBGT 35)に合わせて本プラグインが独自に追加。
level="ほぼ安全"; color="#1E90FF"; icon="🟦"; extra=""
w=$(printf '%.0f' "$(echo "$wbgt" | awk '{print $1*10}')")  # 小数比較用に10倍整数化
if   [ "$w" -ge 350 ]; then level="災害級の酷暑(屋外活動は全面中止)"; color="#8A2BE2"; icon="💀"
     extra="生命に危険が及ぶレベルです。屋外に出ないでください"
elif [ "$w" -ge 310 ]; then level="危険(運動は原則中止)"; color="#D00000"; icon="🟥"
elif [ "$w" -ge 280 ]; then level="厳重警戒(激しい運動は中止)"; color="#FF6600"; icon="🟧"
elif [ "$w" -ge 250 ]; then level="警戒(積極的に休憩)"; color="#E6B800"; icon="🟨"
elif [ "$w" -ge 210 ]; then level="注意"; color="#2E8B57"; icon="🟩"
fi

echo "${icon}WBGT ${wbgt}${stale} | color=$color"
echo "---"
echo "津島キャンパス 屋外"
echo "暑さ指数(WBGT): ${wbgt} ℃ — ${level} | color=$color"
if [ -n "$extra" ]; then
  echo "☠️ ${extra} | color=$color size=14"
fi
echo "気温: ${temp} ℃ / 湿度: ${humid} %"
echo "観測時刻: ${datetime}"
if [ -n "$stale" ]; then
  echo "⚠︎ データが1時間以上更新されていません | color=red"
fi
echo "---"
echo "詳細ページを開く | href=$PAGE"
echo "今すぐ更新 | refresh=true"
