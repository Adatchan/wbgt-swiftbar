#!/bin/bash
# 岡山大学 津島キャンパス 屋外WBGT (10分ごと更新)
# データ元: 岡山大学スポーツ教育センター「みえる！熱中症リスク」プロジェクト
#           http://isec.cc.okayama-u.ac.jp/wbgt/wbgtDetail_tsushima.html
#
# 非公式ツールです。データ提供元とは無関係です。
# 取得間隔を10分より短くしないでください(元データの更新も約10分間隔です)。

URL="http://isec.cc.okayama-u.ac.jp/wbgt/gaitou.csv"
PAGE="http://isec.cc.okayama-u.ac.jp/wbgt/wbgtDetail_tsushima.html"
UA="wbgt-swiftbar/1.1 (+https://github.com/Adatchan/wbgt-swiftbar)"

# --- 条件付きGET: 更新がなければ304が返り、転送量ゼロでキャッシュを使う ---
CACHE_DIR="$HOME/Library/Caches/wbgt-swiftbar"
mkdir -p "$CACHE_DIR"
BODY="$CACHE_DIR/gaitou.csv"
ETAG_FILE="$CACHE_DIR/gaitou.etag"
TMP_BODY="$CACHE_DIR/gaitou.csv.tmp"
TMP_HDR="$CACHE_DIR/gaitou.hdr.tmp"

etag=""
[ -f "$ETAG_FILE" ] && [ -s "$BODY" ] && etag=$(cat "$ETAG_FILE")

code=$(curl -sf --max-time 15 -A "$UA" \
  ${etag:+-H "If-None-Match: $etag"} \
  -D "$TMP_HDR" -o "$TMP_BODY" -w '%{http_code}' "$URL")
curl_rc=$?

# curlが正常終了(=途中切断でない)し、200で本文があり、
# かつ最終行までWBGT値がそろっている場合だけキャッシュを更新する。
if [ "$curl_rc" = "0" ] && [ "$code" = "200" ] \
   && awk -F, 'NF>=5 && $5 ~ /^[0-9]+(\.[0-9]+)?$/{ok=1} END{exit !ok}' "$TMP_BODY" 2>/dev/null; then
  mv -f "$TMP_BODY" "$BODY"
  new_etag=$(grep -i '^etag:' "$TMP_HDR" | tr -d '\r' | sed 's/^[Ee][Tt][Aa][Gg]:[[:space:]]*//')
  if [ -n "$new_etag" ]; then
    printf '%s' "$new_etag" > "$ETAG_FILE"
  else
    rm -f "$ETAG_FILE"
  fi
fi
# 304 のときは何もしない(既存キャッシュをそのまま使う)
rm -f "$TMP_BODY" "$TMP_HDR"

# WBGT(第5列)まで数値がそろった完全な行だけを対象にする。
# ダウンロードが途中で切れた行(例: 日時だけの行)を拾って誤表示しないため。
line=$(awk -F, 'NF>=5 && $5 ~ /^[0-9]+(\.[0-9]+)?$/' "$BODY" 2>/dev/null | tail -1)

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

# 更新が60分以上古い場合は注意表示
now_epoch=$(date +%s)
data_epoch=$(date -j -f "%Y/%m/%d %H:%M:%S" "$datetime" +%s 2>/dev/null || echo 0)
stale=""
if [ $((now_epoch - data_epoch)) -gt 3600 ]; then
  stale=" ⚠︎"
fi

# 環境省の基準で色分け
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
