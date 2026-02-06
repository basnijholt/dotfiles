import type { Plugin } from "@opencode-ai/plugin"

export const BlockGitRewrites: Plugin = async ({ $ }) => {
  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool !== "bash") return
      const command = output.args.command
      if (!command) return

      // Format input like Claude Code's protocol and call the existing hook
      const hookInput = JSON.stringify({
        tool_name: "Bash",
        tool_input: { command },
      })

      try {
        await $`echo ${hookInput} | python3 ~/.claude/hooks/block-git-rewrites.py`.quiet()
      } catch (e: any) {
        // Exit code 2 means blocked (Claude protocol)
        if (e.exitCode === 2) {
          throw new Error(
            e.stderr?.toString().trim() || "Blocked by git safety hook",
          )
        }
      }
    },
  }
}
