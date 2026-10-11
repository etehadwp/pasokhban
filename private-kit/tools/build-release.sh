#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# ساخت بستهٔ نصب پاسخ‌بان — مخزن خصوصی توسعه
#
#   bash tools/build-release.sh              # نسخه از روی سورس خوانده می‌شود
#   bash tools/build-release.sh --out DIR    # محل خروجی (پیش‌فرض: pasokhban-build/)
#
# کارهایی که می‌کند:
#   ۱) شمارهٔ نسخه را از سه جا می‌خواند و اگر یکی نبود/فرق داشت، بیلد را می‌بندد.
#   ۲) پوشهٔ افزونه را تمیز به /tmp کپی می‌کند (بدون .DS_Store، لاگ، node_modules).
#   ۳) ZIP را با پوشهٔ ریشهٔ «pasokhban/» می‌سازد — شرط نصب/آپدیت درست در پیشخوان.
#   ۴) sha256 و فهرست ریشهٔ بسته را چاپ می‌کند.
#
# خروجی داخل pasokhban-build/ ساخته می‌شود که در .gitignore هست؛ هرگز commit نشود.
# ---------------------------------------------------------------------------
set -euo pipefail

PLUGIN_DIR="pasokhban"          # پوشهٔ افزونه در ریشهٔ مخزن
OUT_DIR="pasokhban-build"
ZIP_BIN="$(command -v zip || true)"

while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT_DIR="${2:?--out نیاز به مسیر دارد}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "گزینهٔ ناشناس: $1" >&2; exit 2 ;;
  esac
done

[ -d "$PLUGIN_DIR" ] || { echo "❌ پوشهٔ «$PLUGIN_DIR» پیدا نشد. اسکریپت را از ریشهٔ مخزن توسعه اجرا کنید." >&2; exit 1; }
[ -f "$PLUGIN_DIR/pasokhban.php" ] || { echo "❌ فایل اصلی افزونه در $PLUGIN_DIR نیست." >&2; exit 1; }
[ -f "$PLUGIN_DIR/readme.txt" ] || { echo "❌ فایل readme.txt در $PLUGIN_DIR نیست." >&2; exit 1; }
[ -n "$ZIP_BIN" ] || { echo "❌ دستور zip نصب نیست (apt install zip / brew install zip)." >&2; exit 1; }

# --- ۱) هم‌خوانی شمارهٔ نسخه در سه جا -------------------------------------
V_HEADER="$(grep -m1 -E '^[[:space:]]*\*[[:space:]]*Version:' "$PLUGIN_DIR/pasokhban.php" | sed -E 's/.*Version:[[:space:]]*//' | tr -d ' \r')"
V_CONST="$(grep -m1 -oE "PASOKHBAN_VERSION'[[:space:]]*,[[:space:]]*'[^']+'" "$PLUGIN_DIR/pasokhban.php" | sed -E "s/.*,[[:space:]]*'([^']+)'.*/\1/" || true)"
V_README="$(grep -m1 -E '^[[:space:]]*Stable tag:' "$PLUGIN_DIR/readme.txt" | sed -E 's/.*Stable tag:[[:space:]]*//' | tr -d ' \r')"

echo "نسخه — هدر افزونه: ${V_HEADER:-?} | ثابت: ${V_CONST:-?} | Stable tag: ${V_README:-?}"
if [ -z "$V_HEADER" ] || [ -z "$V_CONST" ] || [ -z "$V_README" ]; then
  echo "❌ یکی از سه جای نسخه خوانده نشد؛ بیلد متوقف شد." >&2; exit 1
fi
if [ "$V_HEADER" != "$V_CONST" ] || [ "$V_HEADER" != "$V_README" ]; then
  echo "❌ شمارهٔ نسخه در سه جا یکسان نیست. اول یکی‌اش کنید، بعد بیلد بگیرید." >&2
  echo "   (هدر=$V_HEADER ثابت=$V_CONST readme=$V_README)" >&2
  exit 1
fi
VERSION="$V_HEADER"

# --- ۲) کپی تمیز -----------------------------------------------------------
BUILD_ROOT="$(mktemp -d /tmp/pb-build.XXXXXX)"
trap 'rm -rf "$BUILD_ROOT"' EXIT
cp -R "$PLUGIN_DIR" "$BUILD_ROOT/$PLUGIN_DIR"
find "$BUILD_ROOT" \
  \( -name '.DS_Store' -o -name 'Thumbs.db' -o -name '*.log' -o -name '*.zip' \
     -o -name 'node_modules' -o -name '.git' -o -name '.github' \) \
  -prune -exec rm -rf {} + 2>/dev/null || true

# --- ۳) ساخت ZIP -----------------------------------------------------------
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
ZIP_PATH="$OUT_DIR/pasokhban.$VERSION.zip"
rm -f "$ZIP_PATH"
( cd "$BUILD_ROOT" && "$ZIP_BIN" -qrX "$ZIP_PATH" "$PLUGIN_DIR" )

# --- ۴) گزارش --------------------------------------------------------------
echo
echo "✅ بسته ساخته شد: $ZIP_PATH"
echo "حجم: $(du -h "$ZIP_PATH" | cut -f1)"
if command -v sha256sum >/dev/null 2>&1; then
  echo "sha256: $(sha256sum "$ZIP_PATH" | cut -d' ' -f1)"
elif command -v shasum >/dev/null 2>&1; then
  echo "sha256: $(shasum -a 256 "$ZIP_PATH" | cut -d' ' -f1)"
fi
echo "ریشهٔ بسته (باید همه «pasokhban/» باشد):"
unzip -l "$ZIP_PATH" | awk 'NR>3 && $4 != "" {print "  " $4}' | sed 's#/.*#/#' | sort -u | head -5
echo
echo "یادآوری: این فایل داخل .gitignore است؛ آن را commit نکنید و فقط به خریدار بدهید."
