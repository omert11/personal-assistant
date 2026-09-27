// Port of hooks/hooks.json SessionStart (except load-rules.sh: omp loads rules natively).
//
// session_start  -> rebuild targets/omp in the background (edits apply next session),
//                   link ~/.local/bin/heavy, run django-detect in the session cwd.
// session_switch -> /new, /resume, /fork start a fresh conversation: re-run django-detect.
// before_agent_start -> inject the django skill body with the first prompt when detected
//                   (omp has no SessionStart stdout channel; this is the earliest model-visible point).
import type { ExtensionAPI, ExtensionContext } from "@oh-my-pi/pi-coding-agent";
import { PA_ROOT, run, runDetached, SCRIPTS_DIR } from "../lib/exec.ts";

const SCRIPT_TIMEOUT_MS = 10_000;

export default function paSessionStart(pi: ExtensionAPI): void {
	// Factories are rebound per session, so this is per-session state.
	let pending: string | undefined;

	const detectDjango = async (ctx: ExtensionContext) => {
		const result = await run("sh", [`${SCRIPTS_DIR}/django-detect.sh`], {
			cwd: ctx.cwd,
			timeoutMs: SCRIPT_TIMEOUT_MS,
		});
		pending = result.stdout.trim() || undefined;
	};

	pi.on("session_start", async (_event, ctx) => {
		if (ctx.agent.kind !== "main") return;
		runDetached("python3", [`${PA_ROOT}/scripts/build-omp.py`, "--quiet"], PA_ROOT);
		await run("bash", [`${SCRIPTS_DIR}/install-heavy.sh`], { cwd: ctx.cwd, timeoutMs: SCRIPT_TIMEOUT_MS });
		await detectDjango(ctx);
	});

	pi.on("session_switch", async (_event, ctx) => {
		if (ctx.agent.kind !== "main") return;
		await detectDjango(ctx);
	});

	pi.on("before_agent_start", (_event, ctx) => {
		if (!pending || ctx.agent.kind !== "main") return;
		return { message: { customType: "pa-session-start", content: pending, display: false } };
	});

	// Cleared only once the turn really starts: before_agent_start may be re-run for the
	// same prompt (policy retries), and every attempt must still carry the message.
	pi.on("agent_start", () => {
		pending = undefined;
	});
}
