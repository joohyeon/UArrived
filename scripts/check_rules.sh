#!/usr/bin/env bash
# Hard repo rules, enforced in CI. See docs/ENGINEERING_RULES.md. Run from the repo root.
set -u
cd "$(git rev-parse --show-toplevel)"
fail=0
bad() { echo "✖ $*"; fail=1; }

# --- Rule 1: Jac must be at least MIN_JAC_PCT of hand-written source, measured in bytes --------
MIN_JAC_PCT=${MIN_JAC_PCT:-40}
WARN_JAC_PCT=${WARN_JAC_PCT:-50}
jac_b=0; other_b=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  case "$f" in
    data/*|docs/*|public/*|scripts/*|.github/*|.claude/*|node_modules/*|*/node_modules/*|*.lock|*package-lock.json) continue ;;
  esac
  case "$f" in
    *.jac) jac_b=$((jac_b + $(wc -c < "$f"))) ;;
    *.py|*.js|*.jsx|*.ts|*.tsx|*.css|*.html) other_b=$((other_b + $(wc -c < "$f"))) ;;
  esac
done < <(git ls-files --cached --others --exclude-standard)
total=$((jac_b + other_b))
if [ "$total" -eq 0 ]; then pct=100; else pct=$((jac_b * 100 / total)); fi
echo "Jac share: ${pct}% (${jac_b} B Jac / ${other_b} B other)  floor ${MIN_JAC_PCT}%"
[ "$pct" -ge "$MIN_JAC_PCT" ] || bad "Jac share ${pct}% is below the ${MIN_JAC_PCT}% floor"
[ "$pct" -ge "$WARN_JAC_PCT" ] || echo "⚠ Jac share is under ${WARN_JAC_PCT}% — the team target; move logic/UI back into Jac"

# --- Rule 2: non-Jac source only under interop/ ----------------------------------------------------
while IFS= read -r f; do
  case "$f" in interop/*|scripts/*|.github/*|.claude/*|docs/*|data/*|public/*|node_modules/*) continue ;; esac
  bad "non-Jac source outside interop/: $f"
done < <(git ls-files --cached --others --exclude-standard | grep -E '\.(py|js|jsx|ts|tsx|css|html)$' | grep -v '^interop/' || true)

# --- Rule 3: features may not import each other (talk through core/) ------------------------------
chk_imports() { # dir forbidden
  [ -d "$1" ] || return 0
  if grep -rEn --include='*.jac' "^[[:space:]]*(import|include).*[[:space:].]$2([[:space:].{]|$)" "$1" >/tmp/xf.$$ 2>/dev/null; then
    while IFS= read -r l; do bad "$1 must not import $2: $l"; done </tmp/xf.$$
  fi; rm -f /tmp/xf.$$
}
chk_imports journey market
chk_imports market journey

# --- Rule 4: no raw colors outside ui/tokens.jac (one design language) ----------------------------
if grep -rEn --include='*.jac' -e '"#[0-9a-fA-F]{3,8}"' -e '(rgb|hsl)a?\(' journey market core ai main.jac ui/components 2>/dev/null >/tmp/col.$$; then
  while IFS= read -r l; do bad "raw color (use ui/tokens.jac): $l"; done </tmp/col.$$
fi; rm -f /tmp/col.$$

# --- Rule 5: no LLM/AI import in the rules or matching-eligibility code ---------------------------
if grep -rEn --include='*.jac' '^[[:space:]]*import.*\bai\b' journey/walkers.jac core 2>/dev/null >/tmp/ai.$$; then
  while IFS= read -r l; do bad "rules code must not import ai/: $l"; done </tmp/ai.$$
fi; rm -f /tmp/ai.$$

[ "$fail" -eq 0 ] && echo "✔ repo rules pass"
exit "$fail"
