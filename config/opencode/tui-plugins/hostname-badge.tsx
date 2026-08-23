// @ts-nocheck
/** @jsxImportSource @opentui/solid */
import type { TuiPlugin } from "@opencode-ai/plugin/tui"
import os from "node:os"

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

const CompactBadge = () => (
  <box flexDirection="row" gap={1}>
    <text fg={accent} bold>
      ● {label}
    </text>
    {isSSH ? <text fg="#7A7A7A">ssh</text> : null}
  </box>
)

const FooterBadge = () => (
  <box flexDirection="row" justifyContent="center" paddingTop={1} gap={1}>
    <text fg={accent} bold>
      ● {label}
    </text>
    {isSSH ? <text fg="#9E9E9E">· ssh</text> : <text fg="#5A5A5A">· local</text>}
    <text fg="#5A5A5A">· {isSSH ? "estás en remoto" : "sesión local"}</text>
  </box>
)

const tui: TuiPlugin = async (api) => {
  api.slots.register({
    id,
    order: 5,
    slots: {
      // Home screen footer — always visible when no session
      home_footer() {
        return <FooterBadge />
      },
      // Right side of the input prompt — visible on home and in sessions
      home_prompt_right() {
        return <CompactBadge />
      },
      session_prompt_right() {
        return <CompactBadge />
      },
      // Sidebar footer — visible inside a session
      sidebar_footer() {
        return (
          <box paddingLeft={1} paddingRight={1} paddingBottom={1}>
            <CompactBadge />
          </box>
        )
      },
    },
  })
}

const plugin = { id, tui }
export default plugin
