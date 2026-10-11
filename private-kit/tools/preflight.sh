#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# خودآزمون پیش از انتشار — مخزن خصوصی توسعه
#
#   bash tools/preflight.sh [ZIP_PATH]
#
# اگر ZIP بدهید، همهٔ بررسی‌ها را روی بستهٔ ساخته‌شده هم اجرا می‌کند.
# اگر ندهید، تازه‌ترین فایل pasokhban.*.zip را در rیشهٔ مخزن یا pasokhban-build/ می‌جوید.
#
# خروجی: ✅ / ⚠ / ❌ برای هر بند + کد خروج ۱ اگر خطایی پیدا شود.
# این اسکریپت چیزی را تغییر نمی‌دهد؛ فقط می‌خواند.
# ---------------------------------------------------------------------------
set -uo pipefail

FAIL=0
ok()   { printf '✅ %s\n' "$1"; }
warn() { printf '⚠️  %s\n' "$1"; }
bad()  { printf '❌ %s\n' "$1"; FAIL=1; }

PLUGIN_DIR="pasokhban"
ZIP_PATH="${1:-}"
if [ -z "$ZIP_PATH" ]; then
  ZIP_PATH="$(ls -1t pasokhban-build/pasokhban.*.zip pasokhban.*.zip 2>/dev/null | head -1 || true)"
fi

echo "=== ۱) شمارهٔ نسخه در سه جا ==="
if [ -f "$PLUGIN_DIR/pasokhban.php" ] && [ -f "$PLUGIN_DIR/readme.txt" ]; then
  V_HEADER="$(grep -m1 -E '^[[:space:]]*\*[[:space:]]*Version:' "$PLUGIN_DIR/pasokhban.php" | sed -E 's/.*Version:[[:space:]]*//' | tr -d ' \r')"
  V_CONST="$(grep -m1 -oE "PASOKHBAN_VERSION'[[:space:]]*,[[:space:]]*'[^']+'" "$PLUGIN_DIR/pasokhban.php" | sed -E "s/.*,[[:space:]]*'([^']+)'.*/\1/" || true)"
  V_README="$(grep -m1 -E '^[[:space:]]*Stable tag:' "$PLUGIN_DIR/readme.txt" | sed -E 's/.*Stable tag:[[:space:]]*//' | tr -d ' \r')"
  printf '   هدر=%s | ثابت=%s | readme=%s\n' "${V_HEADER:-?}" "${V_CONST:-?}" "${V_README:-?}"
  if [ -n "$V_HEADER" ] && [ "$V_HEADER" = "$V_CONST" ] && [ "$V_HEADER" = "$V_README" ]; then
    ok "نسخه در سه جا یکسان است ($V_HEADER)"
  else
    bad "نسخه در سه جا یکسان نیست"
  fi
else
  warn "پوشهٔ «$PLUGIN_DIR» یا فایل‌های نسخه پیدا نشد؛ این بند رد شد"
fi

echo
echo "=== ۲) هیچ کلید/توکنی در سورس نباشد ==="
if [ -d "$PLUGIN_DIR" ]; then
  hits="$(grep -REnI --exclude-dir=.git \
    '(sk-[A-Za-z0-9]{16,}|[0-9]{8,10}:AA[A-Za-z0-9_-]{25,}|xox[baprs]-|ghp_[A-Za-z0-9]{30,}|gho_[A-Za-z0-9]{30,}|AIza[0-9A-Za-z_-]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY)' \
    "$PLUGIN_DIR" || true)"
  if [ -n "$hits" ]; then bad "چیزی شبیه کلید/توکن در سورس:"; printf '%s\n' "$hits"; else ok "سورس تمیز است"; fi
else
  warn "پوشهٔ افزونه نیست؛ رد شد"
fi

echo
echo "=== ۳) بستهٔ نصب ==="
if [ -n "$ZIP_PATH" ] && [ -f "$ZIP_PATH" ]; then
  printf '   بسته: %s\n' "$ZIP_PATH"
  roots="$(unzip -Z1 "$ZIP_PATH" | awk -F/ 'NF>1 {print $1}' | sort -u)"
  if [ "$(printf '%s\n' "$roots" | wc -l | tr -d ' ')" = "1" ] && [ "$roots" = "$PLUGIN_DIR" ]; then
    ok "ریشهٔ بسته «$PLUGIN_DIR/» است (نصب/آپدیت پیشخوان بدون خطا)"
  else
    bad "ریشهٔ بسته درست نیست: $roots — باید یکتا و «pasokhban/» باشد"
  fi
  if unzip -Z1 "$ZIP_PATH" | grep -qE '(^|/)\.DS_Store$|\.log$|node_modules/'; then
    warn "داخل بسته فایل اضافه (.DS_Store/لاگ/node_modules) هست"
  else
    ok "داخل بسته فایل اضافه نیست"
  fi
  if [ -f "$PLUGIN_DIR/readme.txt" ]; then
    Z_VER="$(unzip -p "$ZIP_PATH" "$PLUGIN_DIR/readme.txt" | grep -m1 -E '^[[:space:]]*Stable tag:' | sed -E 's/.*Stable tag:[[:space:]]*//' | tr -d ' \r')"
    printf '   نسخهٔ داخل بسته: %s\n' "${Z_VER:-?}"
  fi
else
  warn "بستهٔ ZIP برای بررسی داده نشد (بی‌اشکال است، فقط بعضی بندها رد شدند)"
fi

echo
echo "=== ۴) فایل‌های ممنوع در درخت گیت ==="
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  tracked="$(git ls-files | grep -Ei '\.(zip|tar|gz|rar|7z)$' || true)"
  if [ -n "$tracked" ]; then bad "فایل ZIP/آرشیو در گیت ردیابی می‌شود (باید از درخت بیرون و در .gitignore باشد):"; printf '%s\n' "$tracked"; else ok "هیچ ZIP/آرشیوی در گیت ردیابی نمی‌شود"; fi
  if [ -f .gitignore ] && grep -qE '^\*\.zip$' .gitignore; then ok ".gitignore الگوی *.zip را دارد"; else warn ".gitignore الگوی *.zip را ندارد"; fi
else
  warn "این مسیر مخزن گیت نیست (برای بند ۴ لازم است)"
fi

echo
echo "=== ۵) مستندات عمومی (اگر در همین مخزن یا مسیر کنارِ آن باشد) ==="
PUBLIC_DIR="${PUBLIC_DIR:-}"
if [ -z "$PUBLIC_DIR" ]; then
  for cand in "../pasokhban-public" "public-docs" "docs-public"; do
    [ -d "$cand" ] && PUBLIC_DIR="$cand" && break
  done
fi
if [ -n "$PUBLIC_DIR" ] && [ -d "$PUBLIC_DIR" ]; then
  if hits="$(grep -RInE --exclude-dir=.git '<\?php|pasokhban_options\[|class-Pasokhban|function pasokhban_|Pasokhban_' "$PUBLIC_DIR")"; then
    bad "در مستندات عمومی نشتی پیدا شد:"; printf '%s\n' "$hits"
  else
    ok "مستندات عمومی تمیز است ($PUBLIC_DIR)"
  fi
else
  warn "پوشهٔ مستندات عمومی پیدا نشد؛ اگر دارید با PUBLIC_DIR=مسیر اجرا کنید"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "🎉 همهٔ بندها پاس شد — آمادهٔ انتشار."
else
  echo "⛔ جلوی انتشار را بگیرید: بندهای ❌ بالا باید رفع شوند."
fi
exit "$FAIL"
