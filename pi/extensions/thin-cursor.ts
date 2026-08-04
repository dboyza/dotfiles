import { CustomEditor, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

const INVERSE_VIDEO = "\x1b[7m";
const NORMAL_VIDEO = "\x1b[27m";

class ThinCursorEditor extends CustomEditor {
	override render(width: number): string[] {
		// Pi draws a full-cell cursor using inverse video. Disable that styling
		// and let the terminal render its native cursor at Pi's cursor marker.
		return super.render(width).map((line) => line.replace(INVERSE_VIDEO, NORMAL_VIDEO));
	}
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		ctx.ui.setEditorComponent((tui, theme, keybindings) =>
			new ThinCursorEditor(tui, theme, keybindings),
		);
	});
}
