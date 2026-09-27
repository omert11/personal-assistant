// Port of hooks/hooks.json PreToolUse[Bash] -> scripts/heavy-guard.sh.
//
// The script speaks Claude's PreToolUse protocol, so the omp bash input is translated to
// Claude's Bash input (timeout s -> ms, async -> run_in_background) and the returned
// `updatedInput` is translated back. Runs for every agent (Claude applies PreToolUse to
// subagents too). Fail-open like Claude: timeouts, crashes and unparsable output leave the
// call untouched.
import type { ExtensionAPI, ExtensionContext, ToolCallEvent } from "@oh-my-pi/pi-coding-agent";
import { parseHookJson, run, SCRIPTS_DIR } from "../lib/exec.ts";

const GUARD_TIMEOUT_MS = 10_000;
// heavy-guard raises queued commands to Claude's Bash ceiling (600000 ms) so a command
// waiting for a slot is not killed in line. omp's equivalent ceiling is 3600 s.
const CLAUDE_BASH_MAX_MS = 600_000;
const OMP_BASH_MAX_S = 3600;

interface ClaudeBashInput {
	command: string;
	timeout?: number;
	run_in_background?: boolean;
}

interface HookSpecificOutput {
	permissionDecision?: string;
	permissionDecisionReason?: string;
	updatedInput?: Partial<ClaudeBashInput>;
	additionalContext?: string;
}

export default function paHeavyGuard(pi: ExtensionAPI): void {
	// `async` exists in the bash schema only while the async.enabled setting is on;
	// asking for it otherwise makes the tool throw.
	const asyncSupported = (): boolean => {
		try {
			const params = pi.getAllTools().find(tool => tool.name === "bash")?.parameters as
				| { json?: unknown }
				| undefined;
			if (!params) return true;
			return JSON.stringify(params.json ?? params).includes('"async"');
		} catch {
			return true;
		}
	};

	pi.on("tool_call", async (event: ToolCallEvent, ctx: ExtensionContext) => {
		if (event.toolName !== "bash") return;
		try {
			const input = event.input as Record<string, unknown>;
			const command = typeof input.command === "string" ? input.command : "";
			if (!command) return;

			const claudeInput: ClaudeBashInput = { command };
			if (typeof input.timeout === "number") claudeInput.timeout = input.timeout * 1000;
			if (typeof input.async === "boolean") claudeInput.run_in_background = input.async;

			const payload = {
				session_id: ctx.sessionManager.getSessionId(),
				cwd: typeof input.cwd === "string" ? input.cwd : ctx.cwd,
				hook_event_name: "PreToolUse",
				tool_name: "Bash",
				tool_input: claudeInput,
			};
			const result = await run("bash", [`${SCRIPTS_DIR}/heavy-guard.sh`], {
				cwd: ctx.cwd,
				input: JSON.stringify(payload),
				timeoutMs: GUARD_TIMEOUT_MS,
			});
			if (result.timedOut) return;
			// Claude semantics: exit 2 blocks and feeds stderr to the model.
			if (result.code === 2) {
				return { block: true, reason: result.stderr.trim() || "Blocked by heavy-guard" };
			}
			if (result.code !== 0) return;

			const output = parseHookJson(result.stdout);
			if (!output) return;
			if (output.decision === "block") {
				return { block: true, reason: String(output.reason ?? "Blocked by heavy-guard") };
			}
			const specific = (output.hookSpecificOutput ?? {}) as HookSpecificOutput;
			if (specific.permissionDecision === "deny") {
				return { block: true, reason: specific.permissionDecisionReason ?? "Blocked by heavy-guard" };
			}
			const additionalContext = specific.additionalContext || undefined;
			const updated = specific.updatedInput;
			if (!updated || typeof updated.command !== "string") {
				return additionalContext ? { additionalContext } : undefined;
			}

			const next: Record<string, unknown> = { ...input, command: updated.command };
			// Service launches (`name`) reject async/timeout; only the command may change.
			if (input.name === undefined) {
				if (updated.run_in_background === true && input.async !== true && asyncSupported()) {
					next.async = true;
				}
				if (typeof updated.timeout === "number" && updated.timeout !== claudeInput.timeout) {
					// 0 disables the deadline in omp; never shorten it to a ceiling.
					if (input.timeout !== 0) {
						next.timeout =
							updated.timeout >= CLAUDE_BASH_MAX_MS ? OMP_BASH_MAX_S : Math.ceil(updated.timeout / 1000);
					}
				}
			}
			return additionalContext ? { input: next, additionalContext } : { input: next };
		} catch {
			return;
		}
	});
}
