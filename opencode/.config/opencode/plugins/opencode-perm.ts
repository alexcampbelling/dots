/**
 * opencode permission/question-queue indicator plugin.
 *
 * A pure observer: it watches the `permission.asked` / `permission.replied`
 * and `question.asked` / `question.replied` / `question.rejected` events and
 * mirrors pending interrupts into a tiny tmpfs directory so two Waybar
 * modules can render a yellow "● N" (permissions) and a light-purple "◆ N"
 * (questions) indicator and jump to the waiting window.
 *
 * It NEVER answers, auto-approves, or otherwise interferes with the
 * permission/question flow. Auto-approval belongs in agent prompts /
 * permission rules, not here.
 *
 * Signal protocol (shared with the Waybar scripts under ~/dots/waybar):
 *   /tmp/opencode-perm/<sessionID>.perm      — pending permission ask
 *   /tmp/opencode-perm/<sessionID>.question  — pending question
 *     line 1: plugin PID (the opencode process that owns the interrupt)
 *     line 2: project directory
 *     line 3: epoch seconds when the interrupt was first seen
 *     line 4: session title / question header (may be empty)
 *   /tmp/opencode-perm/.cursor.perm     — last-focused perm (click script)
 *   /tmp/opencode-perm/.cursor.question — last-focused question (click script)
 *
 * Cleanup strategy (so the dir never grows without end):
 *   - the matching replied/rejected event removes the file.
 *   - dispose (clean exit / plugin reload) removes files this instance wrote.
 *   - both the poll and click scripts prune markers whose owner PID is dead
 *     or whose timestamp is older than STALE_MS (crash mid-ask).
 */

import type { Plugin, PluginModule } from "@opencode-ai/plugin"
import { execFile } from "node:child_process"
import {
  chmodSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  renameSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs"
import { join } from "node:path"

const SIGNAL_DIR = "/tmp/opencode-perm"
/** Hard cap: a pending marker older than this is pruned. */
const STALE_MS = 10 * 60 * 1000
/** Opt-in: send a single dunst notification when the first interrupt appears. */
const NOTIFY_ON_FIRST_ASK = false

type Kind = "perm" | "question"

// opencode 1.17.20 emits these shapes on the plugin bus. The bundled
// @opencode-ai/sdk Event union is stale (it still types "permission.updated"),
// so we declare the shapes verified in the binary and narrow defensively.
type AskedProperties = {
  id: string
  sessionID: string
  permission: string
  patterns: string[]
  metadata: Record<string, unknown>
  always: string[]
  tool?: { messageID: string; callID: string }
}
type RepliedProperties = {
  sessionID: string
  requestID: string
  reply: "once" | "always" | "reject"
}
type QuestionInfo = {
  question: string
  header: string
  options: unknown[]
  multiple?: boolean
  custom?: boolean
}
type QuestionAskedProperties = {
  id: string
  sessionID: string
  questions: QuestionInfo[]
  tool?: { messageID: string; callID: string }
}
type QuestionRepliedProperties = {
  sessionID: string
  requestID: string
  answers: string[][]
}
type QuestionRejectedProperties = {
  sessionID: string
  requestID: string
}
type WireEvent = { type: string; properties?: Record<string, unknown> }

function markerPath(sessionID: string, kind: Kind): string {
  return join(SIGNAL_DIR, `${sessionID}.${kind}`)
}

function isAlive(pid: number): boolean {
  return Number.isFinite(pid) && pid > 0 && existsSync(`/proc/${pid}`)
}

/** True when a marker should be pruned: dead owner, or older than the cap. */
function isStale(name: string, nowMs: number): boolean {
  const path = join(SIGNAL_DIR, name)
  try {
    const lines = readFileSync(path, "utf8").split("\n")
    const pid = Number(lines[0])
    const ts = Number(lines[2])
    if (Number.isFinite(pid) && pid > 0 && !isAlive(pid)) return true
    if (Number.isFinite(ts) && nowMs - ts * 1000 > STALE_MS) return true
  } catch {
    // Unreadable/malformed: fall back to mtime so junk still gets cleaned up.
    try {
      const st = statSync(path)
      if (nowMs - st.mtimeMs > STALE_MS) return true
    } catch {
      return true
    }
  }
  return false
}

function pruneStale(): void {
  const now = Date.now()
  for (const name of readdirSync(SIGNAL_DIR)) {
    if (name.startsWith(".")) continue
    if (isStale(name, now)) rmSync(join(SIGNAL_DIR, name), { force: true })
  }
}

function countPending(): number {
  pruneStale()
  return readdirSync(SIGNAL_DIR).filter((n: string) => !n.startsWith(".")).length
}

function writeMarker(sessionID: string, kind: Kind, dir: string, title: string): void {
  const content = [
    String(process.pid),
    dir,
    String(Math.floor(Date.now() / 1000)),
    title,
  ].join("\n")
  // Atomic write so the poll loop never reads a half-written marker.
  const tmp = join(SIGNAL_DIR, `.tmp-${process.pid}-${sessionID}-${kind}`)
  writeFileSync(tmp, content)
  renameSync(tmp, markerPath(sessionID, kind))
}

function removeMarker(sessionID: string, kind: Kind): void {
  rmSync(markerPath(sessionID, kind), { force: true })
}

/** Best-effort session title/directory enrichment; never blocks the flow. */
async function enrich(
  directory: string,
  client: unknown,
  sessionID: string,
): Promise<{ dir: string; title: string }> {
  let dir = directory
  let title = ""
  try {
    const c = client as { session: { get: (i: { path: { id: string } }) => Promise<any> } }
    const res: any = await c.session.get({ path: { id: sessionID } })
    const info: any = res?.data ?? res
    if (typeof info?.directory === "string") dir = info.directory
    if (typeof info?.title === "string") title = info.title
  } catch {
    /* fall back to directory only */
  }
  return { dir, title }
}

function notify(title: string, body: string): void {
  try {
    // Fire-and-forget; swallow errors so a missing notify-send never breaks
    // the permission flow.
    execFile("notify-send", ["--app-name=opencode", "--urgency=normal", title, body], () => {})
  } catch {
    /* ignore */
  }
}

/** Write a marker for a new interrupt and (optionally) ping once. */
async function onInterrupt(
  directory: string,
  client: unknown,
  kind: Kind,
  sessionID: string,
  fallbackLabel = "",
): Promise<void> {
  const wasFirst = countPending() === 0
  const { dir, title } = await enrich(directory, client, sessionID)
  const label = title || fallbackLabel
  writeMarker(sessionID, kind, dir, label)
  if (NOTIFY_ON_FIRST_ASK && wasFirst) {
    const what = kind === "question" ? "a question" : "permission"
    notify("opencode needs input", `A session is waiting for ${what}${label ? ` — ${label}` : ""}`)
  }
}

const server: Plugin = async ({ directory, client }) => {
  mkdirSync(SIGNAL_DIR, { recursive: true, mode: 0o700 })
  // mkdirSync's mode is ignored when the dir already exists, so enforce it.
  chmodSync(SIGNAL_DIR, 0o700)
  pruneStale()

  return {
    event: async ({ event }) => {
      const ev = event as unknown as WireEvent
      const props = ev.properties ?? {}

      if (ev.type === "permission.asked") {
        const p = props as unknown as AskedProperties
        if (!p.sessionID) return
        await onInterrupt(directory, client, "perm", p.sessionID)
        return
      }

      if (ev.type === "permission.replied") {
        const p = props as unknown as RepliedProperties
        if (!p.sessionID) return
        removeMarker(p.sessionID, "perm")
        return
      }

      if (ev.type === "question.asked") {
        const p = props as unknown as QuestionAskedProperties
        if (!p.sessionID) return
        const first = p.questions?.[0]
        const label = first?.header || first?.question?.slice(0, 60) || ""
        await onInterrupt(directory, client, "question", p.sessionID, label)
        return
      }

      if (ev.type === "question.replied" || ev.type === "question.rejected") {
        const p = props as unknown as QuestionRejectedProperties
        if (!p.sessionID) return
        removeMarker(p.sessionID, "question")
        return
      }
    },

    dispose: async () => {
      // Clean shutdown / plugin reload: drop only the markers we wrote.
      for (const name of readdirSync(SIGNAL_DIR)) {
        if (name.startsWith(".")) continue
        try {
          const lines = readFileSync(join(SIGNAL_DIR, name), "utf8").split("\n")
          if (Number(lines[0]) === process.pid) {
            rmSync(join(SIGNAL_DIR, name), { force: true })
          }
        } catch {
          /* ignore */
        }
      }
    },
  }
}

// Local file plugins must export an `id` (npm plugins derive it from their
// package.json name instead).
export default { id: "opencode-perm", server } satisfies PluginModule
