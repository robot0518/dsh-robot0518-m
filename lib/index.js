// dsh-robot0518-m · Host 半边：把收录的 skill（skills/）注册进 ctx.skills（全局层）。
// 无 Client 半边、无依赖：纯 skill 收录载体，经 dsh-m 市场安装/升级/卸载。
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createSkillProvider } from './skills.js'

const ROOT = fileURLToPath(new URL('..', import.meta.url))
const SKILL_DIRS = [join(ROOT, 'skills')]

export const name = 'robot0518-m'
export const inject = ['skills']

export function apply(ctx) {
  ctx.effect(() => ctx.skills.registerProvider(() => createSkillProvider(SKILL_DIRS, ROOT)))
}
