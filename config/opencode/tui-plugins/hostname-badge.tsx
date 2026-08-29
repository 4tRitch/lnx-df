// @ts-nocheck
/** @jsxImportSource @opentui/solid */
import type { TuiPlugin } from "@opencode-ai/plugin/tui"
import os from "node:os"
import { execSync } from "node:child_process"
import { createSignal, createMemo, onCleanup } from "solid-js"

const id = "hostname-badge"

const rawHostname = os.hostname()
const hostname = rawHostname.trim() || "unknown"
const isSSH = Boolean(process.env.SSH_CONNECTION || process.env.SSH_CLIENT || process.env.SSH_TTY)

function colorForHost(name: string): string {
  const lower = name.toLowerCase()
  if (lower.includes("abigail")) return "#FF8FAB" // Abigail — cinnamonroll rose, pastel pink princess
  if (lower.includes("lynn")) return "#CBA6F7" // Lynn — hello kitty lilac, pastel lavender princess
  // fallback: stable hash — full pastel princess palette
  let hash = 0
  for (let i = 0; i < name.length; i++) hash = (hash * 31 + name.charCodeAt(i)) >>> 0
  const palette = ["#FF8FAB", "#CBA6F7", "#FFB5E8", "#FFC8D6", "#F8BBD0", "#E0BBFF", "#FF9EC6"]
  return palette[hash % palette.length]
}

const accent = colorForHost(hostname)
const label = `@${hostname}`
const BRANCH_LABEL_FG = "#9E9E9E"
const BRANCH_FG = "#FF9E9E"

function formatPath(raw: string): string {
  if (!raw) return ""
  const home = os.homedir()
  if (raw === home) return "~"
  if (raw.startsWith(home + "/")) return "~" + raw.slice(home.length)
  return raw
}

function getBranchForDir(dir: string): string | null {
  if (!dir) return null
  let cwd = dir
  if (cwd === "~") cwd = os.homedir()
  else if (cwd.startsWith("~/")) cwd = os.homedir() + cwd.slice(1)
  try {
    const branch = execSync("git rev-parse --abbrev-ref HEAD", {
      cwd,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim()
    if (!branch) return null
    if (branch === "HEAD") {
      try {
        const hash = execSync("git rev-parse --short HEAD", {
          cwd,
          encoding: "utf8",
          stdio: ["ignore", "pipe", "ignore"],
        }).trim()
        return hash || null
      } catch {
        return null
      }
    }
    return branch
  } catch {
    return null
  }
}

const tui: TuiPlugin = async (api) => {
  const [tick, setTick] = createSignal(0)
  const interval = setInterval(() => setTick((t) => t + 1), 700)
  try {
    onCleanup(() => clearInterval(interval))
  } catch {}
  // lifecycle cleanup for opencode (solid onCleanup may not fire in plugin root)
  // @ts-ignore
  if (api.lifecycle?.onDispose) {
    // @ts-ignore
    api.lifecycle.onDispose(() => clearInterval(interval))
  }

  const getRawGlobalDir = () => api.state.path.directory || api.state.path.worktree || ""
  const getRawSessionDir = (sessionId: string) => {
    const s = api.state.session.get(sessionId)
    const raw = s?.directory || api.state.path.directory || api.state.path.worktree || ""
    return raw
  }
  const getGlobalDir = () => formatPath(getRawGlobalDir())
  const getSessionDir = (sessionId: string) => formatPath(getRawSessionDir(sessionId))

  api.slots.register({
    id,
    order: 5,
    slots: {
      // Home screen footer — always visible when no session
      home_footer() {
        return (
          <box flexDirection="column" alignItems="center" paddingTop={1} gap={0}>
            <box flexDirection="row" justifyContent="center" gap={1}>
              <text fg={accent} bold>
                ● {label}
              </text>
              {isSSH ? <text fg="#9E9E9E">· ssh</text> : <text fg="#5A5A5A">· local</text>}
              <text fg="#5A5A5A">· {isSSH ? "estás en remoto" : "sesión local"}</text>
            </box>
            <text fg="#6B7280">{getGlobalDir()}</text>
          </box>
        )
      },
      // Right side of the input prompt — no path (removed per user request - red box)
      home_prompt_right() {
        return (
          <box flexDirection="row" gap={1}>
            <text fg={accent} bold>
              ● {label}
            </text>
            {isSSH ? <text fg="#7A7A7A">ssh</text> : <text fg="#7A7A7A">local</text>}
          </box>
        )
      },
      session_prompt_right(props: { session_id: string }) {
        return (
          <box flexDirection="row" gap={1}>
            <text fg={accent} bold>
              ● {label}
            </text>
            {isSSH ? <text fg="#7A7A7A">ssh</text> : <text fg="#7A7A7A">local</text>}
          </box>
        )
      },
      // Sidebar footer — visible inside a session (your red box in screenshot)
      sidebar_footer(props: { session_id: string }) {
        const branchMemo = createMemo(() => {
          tick()
          return getBranchForDir(getRawSessionDir(props.session_id))
        })
        const branch = branchMemo()
        return (
          <box flexDirection="column" paddingLeft={1} paddingRight={1} paddingBottom={1} gap={0}>
            <box flexDirection="row" gap={1}>
              <text fg={accent} bold>
                ● {label}
              </text>
              {isSSH ? <text fg="#7A7A7A">ssh</text> : <text fg="#7A7A7A">local</text>}
            </box>
            {branch ? (
              <box flexDirection="row" gap={0}>
                <text fg={BRANCH_LABEL_FG}>branch: </text>
                <text fg={BRANCH_FG}>[{branch}]</text>
              </box>
            ) : null}
            <text fg="#6B7280">{getSessionDir(props.session_id)}</text>
          </box>
        )
      },
    },
  })
}

const plugin = { id, tui }
export default plugin
