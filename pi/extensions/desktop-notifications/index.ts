import { execFile } from "node:child_process";
import { Buffer } from "node:buffer";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const LONG_TURN_MS = 10_000;
const EVENT_CHANNEL = "desktop-notification";
const WEZTERM_APP_ID = "org.wezfurlong.wezterm";

type DesktopNotification = {
	title: string;
	body: string;
};

type AssistantLike = {
	role: "assistant";
	stopReason?: string;
	errorMessage?: string;
};

function cleanField(value: string): string {
	return value.replace(/[\x00-\x1f\x7f;]/g, " ").replace(/\s+/g, " ").trim().slice(0, 300);
}

function powershellString(value: string): string {
	return `'${value.replace(/'/g, "''")}'`;
}

export function macToastScript(title: string, body: string): string {
	return [
		'ObjC.import("AppKit")',
		"const frontmost = $.NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier.js",
		'if (frontmost !== "com.github.wez.wezterm") {',
		"  const app = Application.currentApplication()",
		"  app.includeStandardAdditions = true",
		`  app.displayNotification(${JSON.stringify(body)}, { withTitle: ${JSON.stringify(title)} })`,
		"}",
	].join("; ");
}

export function windowsToastScript(title: string, body: string): string {
	const nativeMethods = [
		"using System;",
		"using System.Runtime.InteropServices;",
		"public static class PiNotificationNativeMethods {",
		'  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();',
		'  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);',
		"}",
	].join(" ");
	return [
		`Add-Type -TypeDefinition ${powershellString(nativeMethods)}`,
		"$foregroundPid = [uint32]0",
		"$foregroundWindow = [PiNotificationNativeMethods]::GetForegroundWindow()",
		"[PiNotificationNativeMethods]::GetWindowThreadProcessId($foregroundWindow, [ref]$foregroundPid) > $null",
		"$foregroundProcess = Get-Process -Id $foregroundPid -ErrorAction SilentlyContinue",
		"if ($foregroundProcess.ProcessName -like 'wezterm*') { exit 0 }",
		"Add-Type -AssemblyName System.Runtime.WindowsRuntime",
		"[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null",
		"$xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)",
		"$texts = $xml.GetElementsByTagName('text')",
		`$texts.Item(0).AppendChild($xml.CreateTextNode(${powershellString(title)})) > $null`,
		`$texts.Item(1).AppendChild($xml.CreateTextNode(${powershellString(body)})) > $null`,
		"$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)",
		`[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('${WEZTERM_APP_ID}').Show($toast)`,
	].join("; ");
}

function sendOSC777({ title, body }: DesktopNotification): void {
	process.stdout.write(`\x1b]777;notify;${title};${body}\x1b\\`);
}

function sendMacToast(notification: DesktopNotification): void {
	execFile("osascript", ["-l", "JavaScript", "-e", macToastScript(notification.title, notification.body)], (error) => {
		if (error) sendOSC777(notification);
	});
}

function sendWindowsToast(notification: DesktopNotification): void {
	const script = windowsToastScript(notification.title, notification.body);
	const encoded = Buffer.from(script, "utf16le").toString("base64");
	const args = ["-NoLogo", "-NoProfile", "-NonInteractive", "-EncodedCommand", encoded];
	const run = (executable: "pwsh.exe" | "powershell.exe") => {
		execFile(executable, args, { windowsHide: true }, (error) => {
			if (!error) return;
			if (executable === "pwsh.exe") run("powershell.exe");
			else sendOSC777(notification);
		});
	};
	run("pwsh.exe");
}

function sendNotification(value: DesktopNotification): void {
	const notification = {
		title: cleanField(value.title),
		body: cleanField(value.body),
	};
	if (!notification.title || !notification.body) return;
	if (process.platform === "win32" || process.env.WSL_DISTRO_NAME) {
		sendWindowsToast(notification);
	} else if (process.platform === "darwin") {
		sendMacToast(notification);
	} else {
		sendOSC777(notification);
	}
}

function isDesktopNotification(value: unknown): value is DesktopNotification {
	if (value === null || typeof value !== "object") return false;
	const candidate = value as Partial<DesktopNotification>;
	return typeof candidate.title === "string" && typeof candidate.body === "string";
}

function latestAssistant(messages: readonly unknown[]): AssistantLike | undefined {
	for (let index = messages.length - 1; index >= 0; index--) {
		const message = messages[index] as Partial<AssistantLike> | undefined;
		if (message?.role === "assistant") return message as AssistantLike;
	}
	return undefined;
}

export default function (pi: ExtensionAPI) {
	let runStartedAt: number | undefined;
	let lastRunFailed = false;
	let lastError: string | undefined;
	let tuiActive = false;

	const unsubscribe = pi.events.on(EVENT_CHANNEL, (value) => {
		if (tuiActive && isDesktopNotification(value)) sendNotification(value);
	});

	pi.on("project_trust", (event, ctx) => {
		if (ctx.mode === "tui") {
			sendNotification({
				title: "Pi needs approval",
				body: `Choose whether to trust ${event.cwd}`,
			});
		}
		return { trusted: "undecided" };
	});

	pi.on("session_start", (_event, ctx) => {
		tuiActive = ctx.mode === "tui";
	});

	pi.on("agent_start", () => {
		runStartedAt ??= Date.now();
	});

	pi.on("agent_end", (event) => {
		const assistant = latestAssistant(event.messages);
		lastRunFailed = assistant?.stopReason === "error";
		lastError = assistant?.errorMessage;
	});

	pi.on("agent_settled", (_event, ctx) => {
		const elapsedMs = runStartedAt === undefined ? 0 : Date.now() - runStartedAt;
		if (ctx.mode === "tui" && (lastRunFailed || elapsedMs >= LONG_TURN_MS)) {
			if (lastRunFailed) {
				sendNotification({
					title: "Pi request failed",
					body: lastError || "The agent stopped after an error",
				});
			} else {
				sendNotification({
					title: "Pi is ready",
					body: `Finished in ${Math.max(1, Math.round(elapsedMs / 1000))} seconds`,
				});
			}
		}
		runStartedAt = undefined;
		lastRunFailed = false;
		lastError = undefined;
	});

	pi.registerCommand("notify-test", {
		description: "Send a test desktop notification",
		handler: (_args, ctx) => {
			if (ctx.mode !== "tui") {
				ctx.ui.notify("Desktop notifications require TUI mode", "warning");
				return;
			}
			ctx.ui.notify("Test notification scheduled in 3 seconds; switch away from WezTerm", "info");
			setTimeout(() => {
				sendNotification({
					title: "Pi notification test",
					body: "Desktop notifications are working",
				});
			}, 3_000);
		},
	});

	pi.on("session_shutdown", () => {
		tuiActive = false;
		unsubscribe();
	});
}
