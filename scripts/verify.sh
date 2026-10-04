#!/usr/bin/env bash
# scripts/verify.sh — 跑本仓库的基线复核：版本三处一致 / URL 200 / SKILL frontmatter 合法。
# 用途：
#   - 本地发版前最后一步；
#   - 让任何 Agent 在怀疑 SKILL.md 与官方 DSH 不一致时，可用此脚本在几秒内复核。
#
# 不做：tsc --strict（DSH SDK 是私有 npm 包，不能在 CI 公开节点上无副作用地安装）；
#       该检查留作本地（见 CONTRIBUTING.md §开发与验证）。
#
# 设计：所有检查默认跑；用环境变量关闭：SKIP_URLS=1 / SKIP_FRONT=1 / SKIP_VERSION=1。
# 退出码：0 = 全绿；非 0 = 有失败项。
# macOS bash 3.12 兼容（不用 mapfile / 不用 bashisms）。

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

fail=0

# ---------- 1. SKILL.md frontmatter 合法 ----------
if [ "${SKIP_FRONT:-0}" != "1" ]; then
  echo "==[1] SKILL.md YAML frontmatter =="
  out=$(node -e '
    const fs=require("fs");
    const head=fs.readFileSync("SKILL.md","utf8").split("\n").slice(0,40).join("\n");
    if(!head.startsWith("---\n")){console.error("missing opening ---");process.exit(2)}
    const end=head.indexOf("\n---\n",4);
    if(end<0){console.error("missing closing ---");process.exit(2)}
    const ym=head.slice(4,end);
    function has(re){return re.test(ym);}
    let ok=true;
    if(!has(/^name:/m)){console.error("missing name");ok=false}
    else {
      const n=(ym.match(/^name:\s*(.+)$/m)||[])[1]||"";
      if(!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(n)){console.error("name not kebab-case: "+n);ok=false}
    }
    if(!has(/^description:/m)){console.error("missing description");ok=false}
    if(!has(/^metadata:/m)){console.error("missing metadata");ok=false}
    else {
      const m=ym.match(/^metadata:\n((?:  .*\n?)+)/m);
      if(!m){console.error("metadata block empty");ok=false}
      else {
        for(const k of ["version","upstream","sdk-baseline"]){
          if(!new RegExp("^  "+k+":","m").test(m[1])){console.error("metadata."+k+" missing");ok=false}
        }
      }
    }
    process.exit(ok?0:1);
  ' 2>&1)
  if [ $? -eq 0 ]; then
    green "✓ SKILL.md frontmatter legal"
  else
    red "✗ SKILL.md frontmatter: $out"; fail=1
  fi
fi

# ---------- 2. 版本三处一致 ----------
if [ "${SKIP_VERSION:-0}" != "1" ]; then
  echo "==[2] version triple (VERSION / frontmatter / CHANGELOG heading) =="
  V=$(tr -d '[:space:]' < VERSION)
  M=$(grep -m1 '^  version:' SKILL.md | sed 's/.*version: *//')
  C=$(grep -m1 -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | tr -d '#[] ')
  if [ "$V" = "$M" ] && [ "$V" = "$C" ]; then
    green "✓ version $V consistent (VERSION / SKILL.md / CHANGELOG)"
  else
    red "✗ version mismatch: VERSION=$V  SKILL.md=$M  CHANGELOG=$C"; fail=1
  fi
  # README 徽章必须含有 SDK 版本（不要求与今天同日期——徽章日期为「上次发版日」，不是今天）
  BADGE_VER=$(grep -m1 -oE 'DeepSeek%20Harness-[0-9]+\.[0-9]+\.[0-9]+[^"]*' README.md | sed 's/DeepSeek%20Harness-//')
  if [ -n "$BADGE_VER" ]; then
    green "✓ README badge SDK version: $BADGE_VER"
  else
    red "✗ no DeepSeek Harness version badge in README.md"; fail=1
  fi
fi

# ---------- 3. URL 200 扫描 ----------
if [ "${SKIP_URLS:-0}" != "1" ]; then
  echo "==[3] URL 200 sweep (official docs + repo) =="
  # 用临时文件代替 mapfile（兼容 bash 3）
  tmp_urls=$(mktemp)
  grep -rhoE 'https?://[^ )>`,}{）]+' . --include='*.md' --include='*.txt' \
    | sed 's/[.,)）]*$//' \
    | grep -v '\$' \
    | grep -E '^(https://deepseek-harness\.github\.io|https://github\.com/deepseek-ai|https://github\.com/cordiverse|https://arxiv\.org|https://registry\.npmjs\.org|https://raw\.githubusercontent\.com/green-dalii)' \
    | sort -u > "$tmp_urls"
  total=$(wc -l < "$tmp_urls" | tr -d ' ')
  bad=0
  while IFS= read -r u; do
    [ -z "$u" ] && continue
    # raw.githubusercontent.com 与 docs site 有时给 000（CDN 重连）；同一URL 重试一次
    code=$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 12 "$u" 2>/dev/null)
    if [ "$code" = "000" ]; then
      sleep 2
      code=$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 18 "$u" 2>/dev/null)
    fi
    if [ "$code" != "200" ]; then
      # npmjs.com 是反爬 403，不是真正的链接失效
      if [[ "$u" == https://www.npmjs.com/* && "$code" == "403" ]]; then
        :
      else
        red "✗ [$code] $u"; bad=$((bad+1))
      fi
    fi
  done < "$tmp_urls"
  rm -f "$tmp_urls"
  if [ "$bad" -eq 0 ]; then
    green "✓ all $total official URLs return 200"
  else
    red "✗ $bad of $total URLs broken (above)"
    fail=1
  fi
fi

# ---------- 4. 收尾 ----------
echo
if [ "$fail" -eq 0 ]; then
  green "verify.sh: ALL GREEN"
  exit 0
else
  red "verify.sh: FAILED"
  exit 1
fi