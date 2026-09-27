// Shared helpers for the personal-assistant omp hooks.
// Lives outside hooks/pre|post so the hook loader never treats it as a factory.
import { type ChildProcess, spawn } from "node:child_process";

/** Absolute repo root; the build substitutes the placeholder. */
export const PA_ROOT = "@PA_ROOT@";
export const SCRIPTS_DIR = `${PA_ROOT}/scripts`;

// The Claude-side scripts locate their siblings through CLAUDE_PLUGIN_ROOT
// (e.g. heavy-guard falls back to scripts/heavy.sh when ~/.local/bin/heavy is missing).
const SCRIPT_ENV: NodeJS.ProcessEnv = { ...process.env, CLAUDE_PLUGIN_ROOT: PA_ROOT };

export interface RunResult {
	/** Exit code; null when the process could not start, was killed, or timed out. */
	code: number | null;
	stdout: string;
	stderr: string;
	timedOut: boolean;
}

export interface RunOptions {
	cwd?: string;
	/** Written to stdin, then stdin is closed. */
	input?: string;
	timeoutMs: number;
}

/** Run a command to completion. Never rejects: failures surface as `code: null`. */
export function run(command: string, args: string[], options: RunOptions): Promise<RunResult> {
	let child: ChildProcess;
	try {
		child = spawn(command, args, { cwd: options.cwd, env: SCRIPT_ENV, stdio: ["pipe", "pipe", "pipe"] });
	} catch {
		return Promise.resolve({ code: null, stdout: "", stderr: "", timedOut: false });
	}

	const { promise, resolve } = Promise.withResolvers<RunResult>();
	let stdout = "";
	let stderr = "";
	let timedOut = false;
	let settled = false;
	const timer = setTimeout(() => {
		timedOut = true;
		child.kill("SIGKILL");
		finish(null);
	}, options.timeoutMs);
	const finish = (code: number | null) => {
		if (settled) return;
		settled = true;
		clearTimeout(timer);
		resolve({ code, stdout, stderr, timedOut });
	};

	child.stdout?.setEncoding("utf8").on("data", chunk => {
		stdout += chunk;
	});
	child.stderr?.setEncoding("utf8").on("data", chunk => {
		stderr += chunk;
	});
	child.on("error", () => finish(null));
	child.on("close", code => finish(code));
	// A script that exits without reading stdin makes the write fail with EPIPE.
	child.stdin?.on("error", () => {});
	child.stdin?.end(options.input ?? "");
	return promise;
}

/** Start a command and forget it; output is discarded and errors are swallowed. */
export function runDetached(command: string, args: string[], cwd: string): void {
	try {
		const child = spawn(command, args, { cwd, env: SCRIPT_ENV, stdio: "ignore", detached: true });
		child.on("error", () => {});
		child.unref();
	} catch {
		// Fire-and-forget: a missing interpreter must never break the session.
	}
}

/** Claude hooks print either JSON or plain text; return the parsed object, else undefined. */
export function parseHookJson(stdout: string): Record<string, unknown> | undefined {
	const text = stdout.trim();
	if (!text.startsWith("{")) return undefined;
	try {
		const parsed: unknown = JSON.parse(text);
		return parsed && typeof parsed === "object" ? (parsed as Record<string, unknown>) : undefined;
	} catch {
		return undefined;
	}
}
