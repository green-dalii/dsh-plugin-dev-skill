#!/usr/bin/env bash
# scripts/verify.sh — 跑本仓库的基线复核：版本三处一致 / URL 200 / SKILL frontmatter 合法 /
#                    阅读预算（单文件 ≤ 8192 字符）与索引完整性。
# 用途：
#   - 本地发版前最后一步；
#   - 让任何 Agent 在怀疑 SKILL.md 与官方 DSH 不一致时，可用此脚本在几秒内复核。
#
# 不做：tsc --strict（DSH SDK 是私有 npm 包，不能在 CI 公开节点上无副作用地安装）；
#       该检查留作本地（见 CONTRIBUTING.md §开发与验证）。
#
# 设计：所有检查默认跑；用环境变量关闭：SKIP_URLS=1 / SKIP_FRONT=1 / SKIP_VERSION=1 / SKIP_BUDGET=1。
# 退出码：0 = 全绿；非 0 = 有失败项。
# macOS bash 3.12 兼容（不用 mapfile / 不用 bashisms）。

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || { printf '\033[31m%s\033[0m\n' "cannot cd to $ROOT" >&2; exit 2; }

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }

fail=0

# ---------- 1. SKILL.md frontmatter 合法 ----------
if [ "${SKIP_FRONT:-0}" != "1" ]; then
  echo "==[1] SKILL.md YAML frontmatter =="
  if node -e '
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
  ' 2>&1; then
    green "✓ SKILL.md frontmatter legal"
  else
    red "✗ SKILL.md frontmatter check failed (see node output above)"; fail=1
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
  # README 徽章必须与 VERSION / metadata.sdk-baseline 一致（徽章日期是「上次发版日」，不参与比较）
  SKILL_BADGE=$(grep -m1 -oE 'skill-[0-9]+\.[0-9]+\.[0-9]+' README.md | sed 's/^skill-//')
  SDK_BADGE=$(grep -m1 -oE 'releases/tag/dsh-v[0-9][0-9A-Za-z.-]*' README.md | sed 's|.*/dsh-v||')
  SDK_BASE=$(grep -m1 '^  sdk-baseline:' SKILL.md | sed 's/.*sdk-baseline: *//' | tr -d '[:space:]')
  if [ "$SKILL_BADGE" = "$V" ]; then
    green "✓ README skill badge matches VERSION ($SKILL_BADGE)"
  else
    red "✗ README skill badge '$SKILL_BADGE' != VERSION '$V'"; fail=1
  fi
  if [ "$SDK_BADGE" = "$SDK_BASE" ]; then
    green "✓ README SDK badge matches metadata.sdk-baseline ($SDK_BADGE)"
  else
    red "✗ README SDK badge '$SDK_BADGE' != sdk-baseline '$SDK_BASE'"; fail=1
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
    # raw.githubusercontent.com 与 docs site 有时给 000（CDN 重连）；同一URL 最多重试两次
    code=$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 12 "$u" 2>/dev/null)
    if [ "$code" = "000" ]; then
      sleep 3
      code=$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 18 "$u" 2>/dev/null)
    fi
    if [ "$code" = "000" ]; then
      sleep 5
      code=$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 18 "$u" 2>/dev/null)
    fi
    if [ "$code" != "200" ]; then
      red "✗ [$code] $u"; bad=$((bad+1))
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

# ---------- 4. 阅读预算与索引完整性 ----------
# DSH 的 tool-result pruner 在 8192 字符以上只保留首尾（headChars 4096 + tailChars 1024）。
# 技能正文是通过 tool result 送达模型的，所以任何一篇超过 8192 字符，长会话压缩时就会被砍掉中间。
# 这不是风格问题，是「读不到」问题：单文件必须 <= 8192，且 SKILL.md 必须能路由到每一个文件。
if [ "${SKIP_BUDGET:-0}" != "1" ]; then
  echo "==[4] reading budget + index integrity =="
  if node -e '
    const fs=require("fs");
    const LIMIT=8192;
    let ok=true;
    const skill=fs.readFileSync("SKILL.md","utf8");
    if(skill.length>LIMIT){console.error("SKILL.md "+skill.length+" > "+LIMIT);ok=false}
    const refs=fs.readdirSync("References").filter(f=>f.endsWith(".md"));
    for(const f of refs){
      const n=fs.readFileSync("References/"+f,"utf8").length;
      if(n>LIMIT){console.error("References/"+f+" "+n+" > "+LIMIT);ok=false}
    }
    for(const f of refs){
      if(!skill.includes(f)){console.error("References/"+f+" 未被 SKILL.md 路由");ok=false}
    }
    const cited=new Set([...skill.matchAll(/\b(\d\d[a-z]?-[\w.-]+\.md)\b/g)].map(m=>m[1]));
    for(const c of cited){
      if(!refs.includes(c)){console.error("SKILL.md 路由到不存在的 "+c);ok=false}
    }
    process.exit(ok?0:1);
  ' 2>&1; then
    green "✓ every file <= 8192 chars; SKILL.md routes to exactly the files present"
  else
    red "✗ reading-budget / index integrity failed (see node output above)"; fail=1
  fi
fi

# ---------- 5. 收尾 ----------
echo
if [ "$fail" -eq 0 ]; then
  green "verify.sh: ALL GREEN"
  exit 0
else
  red "verify.sh: FAILED"
  exit 1
fi