/**
 * vendor.mjs — 把收录 skill 从收录仓库（默认 ../dsh-skills/skills）同步进插件 skills/。
 * 用法：node scripts/vendor.mjs [--from <skills 目录>]
 * 收录仓库是 curated 事实源；本插件只做随包快照，更新流程：vendor → 改 version → release。
 */
import { cpSync, existsSync, readdirSync, rmSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const fromIdx = process.argv.indexOf('--from')
const argFrom = fromIdx > -1 ? process.argv[fromIdx + 1] : undefined
const from = resolve(argFrom || join(root, '..', 'dsh-skills', 'skills'))
const to = join(root, 'skills')

if (!existsSync(from)) {
  console.error(`✗ 收录来源不存在：${from}（用 --from 指定）`)
  process.exit(1)
}
const names = readdirSync(from, { withFileTypes: true })
  .filter((d) => d.isDirectory() && existsSync(join(from, d.name, 'SKILL.md')))
  .map((d) => d.name)
if (names.length === 0) {
  console.error(`✗ 来源目录里没有含 SKILL.md 的 skill：${from}`)
  process.exit(1)
}
rmSync(to, { recursive: true, force: true })
for (const name of names) cpSync(join(from, name), join(to, name), { recursive: true })
console.log(`✓ vendored ${names.length} skills: ${names.join(', ')}`)
