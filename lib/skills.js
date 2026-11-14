// skill 提供方：把插件自带的 skills/<name>/SKILL.md 注册进 DSH 的 skill 目录（ctx.skills）。
// rank 600（随包档）：项目、custom、~/.dsh/skills、~/.agents/skills 里的同名本地副本优先于本副本；
// 本副本的价值是「零配置收集」——经 dsh-m 市场装完插件，收录的 skill 即全局可用。
// 收录 skill 的 frontmatter description 有单行 / >- 折叠块 / > 折叠块三种写法，解析要都吃下。
import { existsSync, readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'

const RANK = 600
const PROVIDER = 'robot0518-m'
const SOURCE = 'bundled'
const INVOCATION = { modelInvocable: true, userInvocable: true }

// 轻量 frontmatter 解析：单行值（可带引号）与 >、>-、|、|- 块标量；不追求 YAML 全集。
function parseFrontmatter(text) {
  const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?/)
  if (!m) return null
  const lines = m[1].split(/\r?\n/)
  const fields = {}
  let i = 0
  while (i < lines.length) {
    const km = lines[i].match(/^([A-Za-z][\w-]*):(?:\s*(.*))?$/)
    if (!km) { i++; continue }
    const key = km[1]
    let value = (km[2] || '').trim()
    const block = value.match(/^([>|])([+-]?)$/)
    if (block) {
      i++
      const chunk = []
      let indent = null
      while (i < lines.length) {
        const l = lines[i]
        if (l.trim() === '') { chunk.push(''); i++; continue }
        const lead = l.match(/^[ \t]*/)[0].length
        if (lead === 0) break
        if (indent === null) indent = lead
        if (lead < indent) break
        chunk.push(l.slice(indent))
        i++
      }
      while (chunk.length > 0 && chunk[chunk.length - 1] === '') chunk.pop()
      value = chunk.join(block[1] === '>' ? ' ' : '\n')
    } else {
      i++
      value = value.replace(/^["'](.*)["']$/, '$1')
    }
    fields[key] = value
  }
  return fields
}

function parse(file) {
  const fields = parseFrontmatter(readFileSync(file, 'utf8'))
  if (!fields) return null
  const name = fields.name
  const description = fields.description
  return name && description ? { name, description } : null
}

export function readSkills(dirs) {
  return [].concat(dirs).flatMap(readDir)
}

function readDir(dir) {
  if (!existsSync(dir)) return []
  return readdirSync(dir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && existsSync(join(dir, d.name, 'SKILL.md')))
    .map((d) => {
      const file = join(dir, d.name, 'SKILL.md')
      return { dir: join(dir, d.name), file, ...(parse(file) || {}) }
    })
    .filter((s) => s.name)
}

// 快照说明：收录 skill 随插件版本更新，不是 git 仓库；本地目录里的同名副本 rank 更高。
function addendum() {
  return [
    '',
    '---',
    '',
    '## 收录来源说明',
    '',
    '- 本 skill 由 dsh-robot0518-m 插件随包提供，随插件版本一起更新；不要运行 git 命令去「更新」它，也不要向用户提起更新步骤。',
    '- `~/.dsh/skills` 等目录里的同名本地副本优先级更高（本副本为 rank 600 随包档）；两边并存时以本地副本为准。',
  ].join('\n') + '\n'
}

export function createSkillProvider(dir, pluginRoot) {
  const candidate = (s) => ({
    name: s.name,
    description: s.description,
    path: s.file,
    invocation: INVOCATION,
    source: SOURCE,
    provider: PROVIDER,
    rank: RANK,
    locator: s.dir,
    resourceBase: { kind: 'directory', path: s.dir },
  })
  return {
    name: PROVIDER,
    async list() {
      return readSkills(dir).map(candidate)
    },
    async get(c) {
      const s = readSkills(dir).find((x) => x.dir === c.locator && x.name === c.name)
      if (!s) return undefined
      const { rank, locator, ...summary } = candidate(s)
      return { ...summary, content: readFileSync(s.file, 'utf8').replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n?/, '') + addendum() }
    },
  }
}
