import { realpathSync, watchFile, unwatchFile } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { pathToFileURL } from "node:url";
import { getAgentDir, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { adapterStatus, renderStatusline } from "./render.mjs";

// Optional, isolated integration with the reviewed, pinned adapter's own readers.
// No copied authentication logic, provider payload inspection, or package patches.
async function loadAdapter(pi: ExtensionAPI) {
  const command = pi.getCommands().find((item) => item.name === "codex" && item.source === "extension");
  if (!command) return undefined;
  const dist = dirname(command.sourceInfo.path);
  const [config, usage] = await Promise.all([
    import(pathToFileURL(join(dist, "adapter/activation/config-store.js")).href),
    import(pathToFileURL(join(dist, "codex-usage/client.js")).href),
  ]);
  if (typeof config.readEffectiveCodexConversionConfig !== "function" || typeof usage.fetchCodexWeeklyUsageLeft !== "function") {
    throw new Error("Unsupported Codex adapter readers");
  }
  return {
    readConfig: config.readEffectiveCodexConversionConfig,
    globalPath: config.getCodexConversionConfigPath(getAgentDir()),
    projectPath: config.getProjectCodexConversionConfigPath,
    weeklyUsage: usage.fetchCodexWeeklyUsageLeft,
  };
}

export default function (pi: ExtensionAPI) {
  let enabled = true;
  let stop = () => {};
  let refreshModel = () => {};

  function install(ctx: ExtensionContext) {
    stop();
    if (ctx.mode !== "tui" || !enabled) return;
    let home = homedir();
    // process.cwd() is canonical on macOS, even when HOME uses /var or another symlink.
    try { home = realpathSync(home); } catch { /* Retain the original home if inaccessible. */ }
    ctx.ui.setFooter((tui, _theme, footerData) => {
      let disposed = false;
      let adapter: Awaited<ReturnType<typeof loadAdapter>>;
      let fast: boolean | undefined;
      let weekly: number | undefined;
      let quotaRequest: AbortController | undefined;
      let timer: ReturnType<typeof setInterval> | undefined;
      const watchers: Array<[string, () => void]> = [];
      const unsubscribe = footerData.onBranchChange(() => tui.requestRender());

      function refreshConfig() {
        if (disposed || !adapter) return;
        const config = adapter.readConfig({ cwd: ctx.cwd, projectTrusted: ctx.isProjectTrusted() });
        fast = config.openai.fast;
        tui.requestRender();
      }

      async function refreshQuota() {
        if (disposed || !adapter || quotaRequest) return;
        if (ctx.model?.provider !== "openai-codex") return;
        const request = new AbortController();
        quotaRequest = request;
        // Snapshot getters so a model switch cannot attach an old quota to a new model.
        const requestContext = { ...ctx, model: ctx.model, signal: request.signal };
        try {
          const value = await adapter.weeklyUsage(requestContext);
          if (!disposed && !request.signal.aborted) {
            weekly = value;
            tui.requestRender();
          }
        } catch {
          if (!disposed && !request.signal.aborted) {
            weekly = undefined;
            tui.requestRender();
          }
        } finally {
          if (quotaRequest === request) quotaRequest = undefined;
        }
      }

      refreshModel = () => {
        if (disposed) return;
        quotaRequest?.abort();
        quotaRequest = undefined;
        weekly = undefined;
        refreshConfig();
        void refreshQuota();
        tui.requestRender();
      };
      const dispose = () => {
        if (disposed) return;
        disposed = true;
        quotaRequest?.abort();
        if (timer) clearInterval(timer);
        for (const [path, listener] of watchers) unwatchFile(path, listener);
        unsubscribe();
      };
      stop = dispose;

      void loadAdapter(pi).then((loaded) => {
        if (disposed || !loaded) return;
        adapter = loaded;
        refreshConfig();
        const paths = [adapter.globalPath];
        if (ctx.isProjectTrusted()) paths.push(adapter.projectPath(ctx.cwd));
        for (const path of paths) {
          watchFile(path, { persistent: false, interval: 1_000 }, refreshConfig);
          watchers.push([path, refreshConfig]);
        }
        void refreshQuota();
        // The upstream reader also caches and deduplicates these read-only requests.
        timer = setInterval(() => void refreshQuota(), 5 * 60_000);
        timer.unref();
      }).catch(() => {
        if (!disposed) ctx.ui.notify("Statusline: Codex quota integration unavailable; other footer fields still work.", "warning");
      });

      return {
        dispose,
        invalidate() {},
        render(width: number) {
          const statuses = footerData.getExtensionStatuses();
          const status = adapterStatus(statuses.get("codex-adapter"));
          const details: string[] = [];
          const cache = statuses.get("codex-cache");
          if (cache) details.push(cache);
          if (status.detail) details.push(status.detail);
          for (const [key, text] of statuses) {
            if (key !== "codex-adapter" && key !== "codex-cache") details.push(text);
          }
          return renderStatusline({
            model: ctx.model?.id,
            thinking: ctx.model?.reasoning ? pi.getThinkingLevel() : undefined,
            cwd: ctx.cwd,
            home,
            codex: ctx.model?.provider === "openai-codex",
            fast,
            weekly: status.weekly ?? weekly,
            branch: footerData.getGitBranch(),
            details,
          }, width, { truncateToWidth, visibleWidth });
        },
      };
    });
  }

  pi.on("session_start", (_event, ctx) => install(ctx));
  pi.on("model_select", () => refreshModel());
  pi.on("session_shutdown", () => stop());
  pi.registerCommand("statusline", {
    description: "Toggle the compact Codex footer and the standard Pi footer",
    handler: async (_args, ctx) => {
      enabled = !enabled;
      stop();
      if (enabled) install(ctx);
      else ctx.ui.setFooter(undefined);
    },
  });
}
