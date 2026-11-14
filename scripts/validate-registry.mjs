/**
 * 个人市场清单校验：与本机 dsh-m（0.12.x）src/core/registry.ts 的 validateRegistry v1 语义对齐，
 * 保证 registry.json 能通过 dsh-m 的严格校验（自定义收录清单 / 默认清单同一 schema）。
 * 零依赖：node scripts/validate-registry.mjs
 */
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const root = dirname(fileURLToPath(import.meta.url)) + '/..'
const raw = JSON.parse(readFileSync(join(root, 'registry.json'), 'utf8'))

const CATEGORIES = ['market', 'tools', 'ui', 'search', 'other']
const TOP_LEVEL_KEYS = new Set(['version', 'plugins'])
const ENTRY_KEYS = new Set(['id', 'name', 'description', 'category', 'tags', 'source', 'npm', 'github', 'homepage', 'icon', 'verified'])
const ID_RE = /^[a-z0-9][a-z0-9._-]*$/
const NPM_RE = /^(@[a-z0-9-~][a-z0-9-._~]*\/)?[a-z0-9-~][a-z0-9-._~]*$/
const GITHUB_RE = /^[A-Za-z0-9][A-Za-z0-9-]*\/[A-Za-z0-9._-]+$/
const EXACT_SEMVER_RE = /^\d+\.\d+\.\d+(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$/
const MAX_DESCRIPTION = 500
const MAX_TAGS = 10
const MAX_NPM = 214

const errors = []
const fail = (msg) => errors.push(msg)
function httpsUrlError(s) {
  if (/[\0-\x1F\x7F]/.test(s)) return '包含控制字符'
  let url
  try { url = new URL(s) } catch { return '不是合法 URL' }
  if (url.protocol !== 'https:') return '只允许 HTTPS'
  if (url.username || url.password) return '不允许 userinfo'
  return null
}

if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
  console.error('registry 根必须是对象')
  process.exit(1)
}
for (const key of Object.keys(raw)) {
  if (!TOP_LEVEL_KEYS.has(key)) fail(`${key}: 未知字段（顶层只允许 version/plugins）`)
}
if (raw.version !== 1) fail('version: 必须为 1')
if (!Array.isArray(raw.plugins)) {
  console.error('plugins: 必须是数组')
  process.exit(1)
}

const seen = new Set()
raw.plugins.forEach((e, index) => {
  const where = `plugins[${index}]`
  if (!e || typeof e !== 'object' || Array.isArray(e)) return fail(`${where}: 必须是对象`)
  for (const key of Object.keys(e)) {
    if (!ENTRY_KEYS.has(key)) fail(`${where}.${key}: 未知字段`)
  }
  const id = typeof e.id === 'string' ? e.id.trim() : ''
  if (id === '') fail(`${where}.id: 必填`)
  else if (!ID_RE.test(id)) fail(`${where}.id: 须小写字母/数字开头，只含小写字母、数字、.、_、-`)
  else if (seen.has(id)) fail(`${where}.id: 重复 ${id}`)
  else seen.add(id)
  if (typeof e.name !== 'string' || !e.name.trim()) fail(`${where}.name: 必填`)
  if (typeof e.description !== 'string' || !e.description.trim()) fail(`${where}.description: 必填`)
  else if (e.description.length > MAX_DESCRIPTION) fail(`${where}.description: 超过 ${MAX_DESCRIPTION} 字符`)
  if (!CATEGORIES.includes(e.category)) fail(`${where}.category: 无效（允许 ${CATEGORIES.join('/')}）`)
  if (!Array.isArray(e.tags) || e.tags.length === 0) fail(`${where}.tags: 必须是非空字符串数组`)
  else if (e.tags.length > MAX_TAGS) fail(`${where}.tags: 超过 ${MAX_TAGS} 个`)
  if (e.source !== 'npm' && e.source !== 'github') fail(`${where}.source: 必须是 npm 或 github`)
  if (e.source === 'npm') {
    if (typeof e.npm !== 'string' || !NPM_RE.test(e.npm.trim())) fail(`${where}.npm: source=npm 必填合法包名`)
  }
  if (e.source === 'github') {
    if (typeof e.github !== 'string' || !GITHUB_RE.test(e.github.trim())) fail(`${where}.github: source=github 必填 owner/repo`)
  }
  for (const key of ['homepage', 'icon']) {
    if (e[key] === undefined) continue
    const problem = httpsUrlError(String(e[key]).trim())
    if (problem) fail(`${where}.${key}: ${problem}`)
  }
  if (e.verified !== undefined) {
    if (!Array.isArray(e.verified)) fail(`${where}.verified: 必须是字符串数组`)
    else {
      const list = []
      e.verified.forEach((v, vi) => {
        if (typeof v !== 'string' || v !== v.trim()) return fail(`${where}.verified[${vi}]: 必须是非空白精确 semver`)
        if (!EXACT_SEMVER_RE.test(v)) return fail(`${where}.verified[${vi}]: ${v} 不是精确 semver（禁 range/前缀）`)
        if (list.includes(v)) fail(`${where}.verified[${vi}]: 重复 ${v}`)
        list.push(v)
      })
    }
  }
})

if (errors.length > 0) {
  console.error('✗ registry.json 校验失败：')
  for (const e of errors) console.error('  -', e)
  process.exit(1)
}
console.log(`✓ registry 合法，共 ${raw.plugins.length} 条收录`)
