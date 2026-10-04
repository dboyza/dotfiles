// Native Windows companion. The bridge contains window identities and tab IDs only.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;

// Section: Bridge payloads
internal sealed class Tab {
    public long id { get; set; }
    public int index { get; set; }
    public bool active { get; set; }
}
internal sealed class Snapshot {
    public string key { get; set; }
    public string title { get; set; }
    public double updated { get; set; }
    public Tab[] tabs { get; set; }
}
// Section: Windows APIs and frame styling
internal static class Native {
    internal delegate bool EnumCallback(IntPtr window, IntPtr data);
    [StructLayout(LayoutKind.Sequential)] internal struct Rect { public int left, top, right, bottom; }
    [DllImport("user32.dll")] internal static extern bool EnumWindows(EnumCallback callback, IntPtr data);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] internal static extern int GetWindowText(IntPtr window, StringBuilder text, int size);
    [DllImport("user32.dll")] internal static extern uint GetWindowThreadProcessId(IntPtr window, out uint pid);
    [DllImport("user32.dll")] internal static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] internal static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] internal static extern bool IsIconic(IntPtr window);
    [DllImport("user32.dll")] internal static extern bool IsZoomed(IntPtr window);
    [DllImport("user32.dll")] internal static extern bool GetWindowRect(IntPtr window, out Rect rect);
    [DllImport("user32.dll")] internal static extern bool SetForegroundWindow(IntPtr window);
    [DllImport("user32.dll")] internal static extern uint GetDpiForWindow(IntPtr window);
    [DllImport("user32.dll")] internal static extern bool SetProcessDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")] internal static extern bool SetWindowPos(IntPtr window, IntPtr after, int x, int y, int width, int height, uint flags);
    [DllImport("user32.dll")] internal static extern IntPtr GetWindow(IntPtr window, uint command);
    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW")] internal static extern IntPtr SetOwner64(IntPtr window, int index, IntPtr owner);
    [DllImport("user32.dll", EntryPoint = "SetWindowLongW")] internal static extern IntPtr SetOwner32(IntPtr window, int index, IntPtr owner);
    [DllImport("dwmapi.dll", EntryPoint = "DwmGetWindowAttribute")] internal static extern int Frame(IntPtr window, int attribute, out Rect rect, int size);
    [DllImport("dwmapi.dll", EntryPoint = "DwmGetWindowAttribute")] internal static extern int GetAttribute(IntPtr window, int attribute, out int value, int size);
    [DllImport("dwmapi.dll")] private static extern int DwmSetWindowAttribute(IntPtr window, int attribute, ref int value, int size);
    internal static bool StyleFrame(IntPtr window, bool focused) {
        // DWM draws a continuous outline around its own rounded window mask.
        // Client-side rectangular borders remain square inside that mask.
        int round = 2; // DWMWCP_ROUND; Windows keeps maximized/fullscreen edges square.
        int border = focused ? 0xAA8C90 : 0x523539; // COLORREF is 0x00BBGGRR, not RGB.
        return DwmSetWindowAttribute(window, 33, ref round, 4) == 0
            && DwmSetWindowAttribute(window, 34, ref border, 4) == 0;
    }
    internal static void Own(IntPtr panel, IntPtr owner) {
        if (IntPtr.Size == 8) SetOwner64(panel, -8, owner); else SetOwner32(panel, -8, owner);
    }
    internal static bool IsWezTerm(IntPtr window) {
        uint pid;
        GetWindowThreadProcessId(window, out pid);
        try { using (var process = Process.GetProcessById((int)pid)) return process.ProcessName == "wezterm-gui"; }
        catch (ArgumentException) { return false; }
        catch (System.ComponentModel.Win32Exception) { return false; }
    }
}
// Section: Validated state exchange
internal static class Bridge {
    // Keep limits aligned with config/protocol.lua and the shared fixtures.
    internal const double FreshnessSeconds = 3;
    internal const int MaximumSnapshotBytes = 65536;
    internal const double CleanupAfterSeconds = 30;
    internal static readonly string Root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".local", "state", "dotfiles", "wezterm-floating-tabs");
    internal static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = MaximumSnapshotBytes };
    internal static double Now { get { return (DateTime.UtcNow - new DateTime(1970, 1, 1)).TotalSeconds; } }
    internal static bool Valid(Snapshot snapshot, string file, double now) {
        return snapshot != null && snapshot.key != null && Regex.IsMatch(snapshot.key, "^[A-Za-z0-9]+-[0-9]+$")
            && Path.GetFileName(file) == "window-" + snapshot.key + ".json"
            && snapshot.title == "WezTerm [" + snapshot.key.Replace('-', ':') + "]"
            && Math.Abs(now - snapshot.updated) < FreshnessSeconds && snapshot.tabs != null && snapshot.tabs.Length > 0
            && snapshot.tabs.All(tab => tab != null && tab.index >= 0 && tab.id >= 0 && tab.id <= 9007199254740991)
            && snapshot.tabs.Select(tab => tab.id).Distinct().Count() == snapshot.tabs.Length
            && snapshot.tabs.Select(tab => tab.index).Distinct().Count() == snapshot.tabs.Length
            && snapshot.tabs.Count(tab => tab.active) == 1;
    }
    private static bool Integer(object value, double maximum) {
        if (!(value is int || value is long || value is decimal || value is double)) return false;
        double number = Convert.ToDouble(value);
        return number >= 0 && number <= maximum && Math.Floor(number) == number;
    }
    internal static Snapshot Decode(string text) {
        // JavaScriptSerializer otherwise fills missing value-type fields with zero.
        var value = Json.DeserializeObject(text) as Dictionary<string, object>;
        if (value == null || !value.ContainsKey("updated") ||
            !(value["updated"] is int || value["updated"] is long || value["updated"] is decimal || value["updated"] is double) ||
            !value.ContainsKey("tabs") || !(value["tabs"] is object[])) return null;
        foreach (var item in (object[])value["tabs"]) {
            var tab = item as Dictionary<string, object>;
            if (tab == null || !tab.ContainsKey("id") || !Integer(tab["id"], 9007199254740991) ||
                !tab.ContainsKey("index") || !Integer(tab["index"], Int32.MaxValue) ||
                !tab.ContainsKey("active") || !(tab["active"] is bool)) return null;
        }
        return Json.Deserialize<Snapshot>(text);
    }
    internal static Snapshot Read(string file) {
        // Allow WezTerm to replace the snapshot while a reader holds it open.
        using (var stream = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete)) {
            if (stream.Length > MaximumSnapshotBytes) return null;
            using (var reader = new StreamReader(stream)) return Decode(reader.ReadToEnd());
        }
    }
    internal static void Write(string root, string name, object reply) {
        var target = Path.Combine(root, name);
        var temporary = target + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try {
            File.WriteAllText(temporary, Json.Serialize(reply), new UTF8Encoding(false));
            if (File.Exists(target)) File.Replace(temporary, target, null); else File.Move(temporary, target);
        } finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
    internal static void Remove(string name) {
        try { File.Delete(Path.Combine(Root, name)); } catch (IOException) { } catch (UnauthorizedAccessException) { }
    }
}
// Section: DPI-aware geometry
internal sealed class Layout {
    internal Rectangle Bounds;
    internal readonly List<Rectangle> Tabs = new List<Rectangle>();
    internal Rectangle Clock;
    internal Rectangle NewTab;
    internal static Layout Create(Rectangle frame, Rectangle work, Tab[] tabs, float scale) {
        int height = (int)Math.Round(24 * scale), gap = (int)Math.Round(4 * scale);
        int inset = (int)Math.Round(6 * scale), y = frame.Top - height / 2;
        if (y < work.Top || frame.Left < work.Left || frame.Right > work.Right || frame.Width < inset * 2) return null;
        var result = new Layout { Bounds = new Rectangle(frame.Left, y, frame.Width, height) };
        int x = inset;
        foreach (var tab in tabs) {
            int width = (int)Math.Round(Math.Max(28, (tab.index + 1).ToString().Length * 10 + 14) * scale);
            if (x + width > frame.Width - inset) return null; // Keep all tabs accessible through the native bar.
            result.Tabs.Add(new Rectangle(x, 0, width, height));
            x += width + gap;
        }
        int newTabWidth = (int)Math.Round(28 * scale);
        if (x + newTabWidth > frame.Width - inset) return null;
        result.NewTab = new Rectangle(x, 0, newTabWidth, height);
        x += newTabWidth + gap;
        int clockWidth = (int)Math.Round(88 * scale);
        int clockX = (frame.Width - clockWidth) / 2;
        if (x + inset < clockX) result.Clock = new Rectangle(clockX, 0, clockWidth, height);
        return result;
    }
}
// Section: Nonactivating rendering and click requests
internal sealed class Overlay : Form {
    private static readonly Color Lavender = Color.FromArgb(196, 167, 231), Dark = Color.FromArgb(25, 23, 36), Muted = Color.FromArgb(57, 53, 82);
    private static readonly Color Subtle = Color.FromArgb(144, 140, 170), Surface = Color.FromArgb(35, 33, 54);
    internal Snapshot Snapshot;
    private readonly IntPtr parent;
    private Layout layout;
    private string signature;
    private string clock;
    private float scale;
    private double heartbeat;
    internal Overlay(IntPtr parent) {
        this.parent = parent;
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        StartPosition = FormStartPosition.Manual;
        AutoScaleMode = AutoScaleMode.None;
        BackColor = Dark;
        DoubleBuffered = true;
        Native.Own(Handle, parent);
    }
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override CreateParams CreateParams {
        get { var value = base.CreateParams; value.ExStyle |= 0x08000080; return value; } // NOACTIVATE | TOOLWINDOW
    }
    private static GraphicsPath Capsule(Rectangle rect, float radius) {
        var path = new GraphicsPath();
        float diameter = Math.Min(radius * 2, rect.Height);
        path.AddArc(rect.Left, rect.Top, diameter, diameter, 180, 90);
        path.AddArc(rect.Right - diameter, rect.Top, diameter, diameter, 270, 90);
        path.AddArc(rect.Right - diameter, rect.Bottom - diameter, diameter, diameter, 0, 90);
        path.AddArc(rect.Left, rect.Bottom - diameter, diameter, diameter, 90, 90);
        path.CloseFigure();
        return path;
    }
    internal void Refresh(Snapshot snapshot, Layout placement, float dpi) {
        Snapshot = snapshot;
        bool geometryChanged = layout == null || Bounds != placement.Bounds || scale != dpi
            || signature != Bridge.Json.Serialize(snapshot.tabs);
        layout = placement;
        scale = dpi;
        string nextClock = DateTime.Now.ToString("h:mm tt", System.Globalization.CultureInfo.InvariantCulture);
        if (geometryChanged) {
            signature = Bridge.Json.Serialize(snapshot.tabs);
            Bounds = layout.Bounds;
            var region = new Region();
            region.MakeEmpty();
            foreach (var rect in layout.Tabs) using (var path = Capsule(rect, 8 * scale)) region.Union(path);
            using (var path = Capsule(layout.NewTab, 8 * scale)) region.Union(path);
            if (!layout.Clock.IsEmpty) using (var path = Capsule(layout.Clock, 8 * scale)) region.Union(path);
            var previous = Region;
            Region = region;
            if (previous != null) previous.Dispose();
        }
        if (geometryChanged || clock != nextClock) { clock = nextClock; Invalidate(); }
        if (!Visible) Show();
        // Insert immediately above this owner without promoting it above other windows.
        IntPtr previousWindow = Native.GetWindow(parent, 3); // GW_HWNDPREV
        if (previousWindow != Handle) Native.SetWindowPos(Handle, previousWindow, 0, 0, 0, 0, 0x13); // NOSIZE | NOMOVE | NOACTIVATE
        if (Bridge.Now - heartbeat >= 0.5) {
            Bridge.Write(Bridge.Root, "ready-" + snapshot.key + ".json", new { title = snapshot.title, updated = Bridge.Now });
            heartbeat = Bridge.Now;
        }
    }
    internal void Suspend() {
        Hide();
        if (Snapshot != null) Bridge.Remove("ready-" + Snapshot.key + ".json");
        heartbeat = 0;
    }
    protected override void OnPaint(PaintEventArgs e) {
        if (layout == null) return;
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        using (var activeFont = new Font("Consolas", 13 * scale, FontStyle.Bold, GraphicsUnit.Pixel))
        using (var font = new Font("Consolas", 13 * scale, FontStyle.Regular, GraphicsUnit.Pixel))
        using (var clockFont = new Font("Consolas", 12 * scale, FontStyle.Regular, GraphicsUnit.Pixel)) {
            for (int i = 0; i < Snapshot.tabs.Length; i++) DrawBadge(e.Graphics, layout.Tabs[i], (Snapshot.tabs[i].index + 1).ToString(), Snapshot.tabs[i].active, Snapshot.tabs[i].active ? activeFont : font);
            DrawBadge(e.Graphics, layout.NewTab, "+", false, font);
            if (!layout.Clock.IsEmpty) DrawBadge(e.Graphics, layout.Clock, clock, false, clockFont, true);
        }
    }
    private void DrawBadge(Graphics graphics, Rectangle rect, string text, bool active, Font font, bool isClock = false) {
        using (var path = Capsule(rect, 8 * scale)) {
            using (var brush = new SolidBrush(active ? Lavender : (isClock ? Dark : Surface))) graphics.FillPath(brush, path);
            if (!active) using (var pen = new Pen(Muted, 1)) { pen.Alignment = PenAlignment.Inset; graphics.DrawPath(pen, path); }
        }
        TextRenderer.DrawText(graphics, text, font, rect, active ? Dark : Subtle, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
    }
    protected override void WndProc(ref Message message) {
        if (message.Msg == 0x21) { message.Result = new IntPtr(3); return; } // MA_NOACTIVATE, retain click
        base.WndProc(ref message);
    }
    protected override void OnMouseDown(MouseEventArgs e) {
        base.OnMouseDown(e);
        if (e.Button != MouseButtons.Left || layout == null) return;
        if (layout.NewTab.Contains(e.Location)) {
            try {
                Bridge.Write(Bridge.Root, "activate-" + Snapshot.key + ".json", new { title = Snapshot.title, updated = Bridge.Now, action = "new_tab" });
                Native.SetForegroundWindow(parent);
            } catch (IOException) { Suspend(); } catch (UnauthorizedAccessException) { Suspend(); }
            return;
        }
        for (int i = 0; i < layout.Tabs.Count; i++) if (layout.Tabs[i].Contains(e.Location)) {
            try {
                Bridge.Write(Bridge.Root, "activate-" + Snapshot.key + ".json", new { title = Snapshot.title, updated = Bridge.Now, tab_id = Snapshot.tabs[i].id });
                Native.SetForegroundWindow(parent);
            } catch (IOException) { Suspend(); } catch (UnauthorizedAccessException) { Suspend(); }
            return;
        }
    }
    protected override void Dispose(bool disposing) {
        if (disposing) Suspend();
        base.Dispose(disposing);
    }
}
// Section: Window discovery and snapshot reconciliation
internal sealed class Companion : ApplicationContext {
    private readonly Dictionary<IntPtr, Overlay> overlays = new Dictionary<IntPtr, Overlay>();
    private readonly Dictionary<string, Snapshot> snapshots = new Dictionary<string, Snapshot>();
    private readonly System.Windows.Forms.Timer timer = new System.Windows.Forms.Timer { Interval = 100 };
    private readonly Control dispatcher = new Control();
    private readonly FileSystemWatcher watcher;
    private bool refreshing;
    private int queued;
    private double lastFrameRefresh;
    private IntPtr lastForeground;
    internal Companion() {
        var handle = dispatcher.Handle;
        watcher = new FileSystemWatcher(Bridge.Root, "window-*.json") { NotifyFilter = NotifyFilters.FileName | NotifyFilters.LastWrite };
        watcher.Changed += delegate { QueueRefresh(); };
        watcher.Created += delegate { QueueRefresh(); };
        watcher.Renamed += delegate { QueueRefresh(); };
        watcher.EnableRaisingEvents = true;
        timer.Tick += delegate { Refresh(); };
        timer.Start();
        Refresh();
    }
    private void QueueRefresh() {
        if (Interlocked.Exchange(ref queued, 1) != 0) return;
        try { dispatcher.BeginInvoke((Action)delegate { Interlocked.Exchange(ref queued, 0); Refresh(); }); }
        catch (InvalidOperationException) { Interlocked.Exchange(ref queued, 0); }
    }
    private void Refresh() {
        if (refreshing) return;
        refreshing = true;
        try {
            IntPtr foreground = Native.GetForegroundWindow();
            bool showBadges = Native.IsWezTerm(foreground);
            bool refreshFrames = foreground != lastForeground || Bridge.Now - lastFrameRefresh >= 1;
            lastForeground = foreground;
            if (refreshFrames) lastFrameRefresh = Bridge.Now;
            if (!showBadges) {
                foreach (var overlay in overlays.Values) overlay.Suspend();
                // Window styling remains active while another app has focus.
                if (!refreshFrames) return;
            }
            // Windows Lua publication briefly removes the old destination before
            // renaming. Keep its last valid snapshot until the freshness deadline.
            foreach (var title in snapshots.Keys.Where(title => Math.Abs(Bridge.Now - snapshots[title].updated) >= Bridge.FreshnessSeconds).ToArray()) snapshots.Remove(title);
            foreach (var file in Directory.GetFiles(Bridge.Root, "window-*.json")) {
                try {
                    var snapshot = Bridge.Read(file);
                    if (Bridge.Valid(snapshot, file, Bridge.Now)) snapshots[snapshot.title] = snapshot;
                    else if (snapshot != null && Bridge.Valid(snapshot, file, snapshot.updated) && Bridge.Now - snapshot.updated > Bridge.CleanupAfterSeconds) {
                        foreach (var prefix in new[] { "window-", "ready-", "activate-" }) Bridge.Remove(prefix + snapshot.key + ".json");
                    }
                } catch (IOException) { } catch (UnauthorizedAccessException) { }
                catch (ArgumentException) { } catch (InvalidOperationException) { }
            }
            var live = new HashSet<IntPtr>();
            Native.EnumWindows(delegate(IntPtr window, IntPtr unused) {
                if (!Native.IsWindowVisible(window) || Native.IsIconic(window) || !Native.IsWezTerm(window)) return true;
                int cloaked;
                if (Native.GetAttribute(window, 14, out cloaked, 4) == 0 && cloaked != 0) return true;
                var title = new StringBuilder(512);
                Native.GetWindowText(window, title, title.Capacity);
                Snapshot snapshot;
                if (!snapshots.TryGetValue(title.ToString(), out snapshot)) return true;
                if (refreshFrames) Native.StyleFrame(window, window == foreground);
                if (!showBadges || Native.IsZoomed(window)) return true;
                Native.Rect rect;
                if (Native.Frame(window, 9, out rect, Marshal.SizeOf(typeof(Native.Rect))) != 0 && !Native.GetWindowRect(window, out rect)) return true;
                var frame = Rectangle.FromLTRB(rect.left, rect.top, rect.right, rect.bottom);
                float scale = Math.Max(96, Native.GetDpiForWindow(window)) / 96f;
                var layout = Layout.Create(frame, Screen.FromHandle(window).WorkingArea, snapshot.tabs, scale);
                if (layout == null) return true;
                Overlay overlay;
                if (!overlays.TryGetValue(window, out overlay)) { overlay = new Overlay(window); overlays.Add(window, overlay); }
                live.Add(window);
                overlay.Refresh(snapshot, layout, scale);
                return true;
            }, IntPtr.Zero);
            foreach (var window in overlays.Keys.Where(window => !live.Contains(window)).ToArray()) {
                overlays[window].Dispose();
                overlays.Remove(window);
            }
        } catch (IOException) { foreach (var overlay in overlays.Values) overlay.Suspend(); }
        catch (UnauthorizedAccessException) { foreach (var overlay in overlays.Values) overlay.Suspend(); }
        finally { refreshing = false; }
    }
    protected override void Dispose(bool disposing) {
        if (disposing) {
            timer.Dispose(); watcher.Dispose(); dispatcher.Dispose();
            foreach (var overlay in overlays.Values) overlay.Dispose();
        }
        base.Dispose(disposing);
    }
}
// Section: Native entry point and contract checks
internal static class Program {
    [STAThread] private static int Main(string[] args) {
        if (args.Length == 3 && args[0] == "--test") {
            try { TestContract(args[2]); Test(); File.WriteAllText(args[1], "Windows floating tabs checks passed\n"); return 0; }
            catch (Exception error) { File.WriteAllText(args[1], error.ToString()); return 1; }
        }
        bool created;
        string user = System.Security.Principal.WindowsIdentity.GetCurrent().User.Value;
        using (var mutex = new Mutex(true, "Local\\DotfilesWezTermFloatingTabs-" + user, out created)) {
            if (!created) return 0;
            try {
                Native.SetProcessDpiAwarenessContext(new IntPtr(-4)); // Per-monitor v2, before creating HWNDs.
                Application.EnableVisualStyles();
                using (var companion = new Companion()) Application.Run(companion);
            } finally { mutex.ReleaseMutex(); }
        }
        return 0;
    }
    private static void Require(bool value, string message) { if (!value) throw new Exception(message); }
    private static void TestContract(string path) {
        var fixtures = Bridge.Json.Deserialize<ContractFixtures>(File.ReadAllText(path));
        foreach (var fixture in fixtures.snapshots) {
            Snapshot snapshot = null;
            try { snapshot = Bridge.Decode(fixture.payload); } catch (ArgumentException) { } catch (InvalidOperationException) { }
            Require(Bridge.Valid(snapshot, fixture.file, fixture.now) == fixture.valid, "Snapshot contract: " + fixture.name);
        }
    }
    private sealed class ContractFixtures { public ContractCase[] snapshots { get; set; } }
    private sealed class ContractCase {
        public string name { get; set; }
        public string file { get; set; }
        public string payload { get; set; }
        public double now { get; set; }
        public bool valid { get; set; }
    }
    private static void Test() {
        using (var window = new Form()) {
            int preference;
            Require(Native.StyleFrame(window.Handle, true), "Windows must accept the rounded muted lavender frame");
            Require(Native.GetAttribute(window.Handle, 33, out preference, 4) == 0 && preference == 2,
                "Native corner preference must opt into rounded corners");
            Require(Native.GetAttribute(window.Handle, 34, out preference, 4) == 0 && preference == 0xAA8C90,
                "Focused frame color must use muted lavender");
            Require(Native.StyleFrame(window.Handle, false), "Frame styling must remain safe on refresh");
            Require(Native.GetAttribute(window.Handle, 34, out preference, 4) == 0 && preference == 0x523539,
                "Unfocused frame color must dim without changing the rounded corners");
        }
        var tabs = new[] { new Tab { id = 1, index = 0, active = true }, new Tab { id = 2, index = 1 } };
        var frame = new Rectangle(50, 80, 1400, 850);
        var work = new Rectangle(0, 0, 1920, 1040);
        foreach (float scale in new[] { 1f, 1.5f, 2f }) {
            var layout = Layout.Create(frame, work, tabs, scale);
            Require(layout != null && layout.Bounds.Top < frame.Top && layout.Bounds.Bottom > frame.Top, "Badges must straddle the top border");
            Require(layout.NewTab.Left > layout.Tabs.Last().Right && layout.NewTab.Right < layout.Clock.Left, "New-tab button must follow the last tab without overlapping the clock");
            Require(Math.Abs(layout.Clock.Left + layout.Clock.Width / 2 - frame.Width / 2) <= 1, "Clock must be centered");
        }
        Require(Layout.Create(work, work, tabs, 1) == null, "Fullscreen must retain native tabs");
        Require(Layout.Create(new Rectangle(50, 80, 50, 600), work, tabs, 1) == null, "Overflow must retain all native tabs");
        var secondary = Layout.Create(new Rectangle(-1850, 80, 1400, 850), new Rectangle(-1920, 0, 1920, 1040), tabs, 1.5f);
        Require(secondary != null && secondary.Bounds.Left == -1850, "Negative monitor coordinates must work");
        var snapshot = new Snapshot { key = "abc-42", title = "WezTerm [abc:42]", updated = Bridge.Now, tabs = tabs };
        Require(Bridge.Valid(snapshot, "window-abc-42.json", Bridge.Now), "Valid snapshot rejected");
        Require(!Bridge.Valid(snapshot, "window-other-42.json", Bridge.Now), "Foreign filename accepted");
        Require(!Bridge.Valid(snapshot, "window-abc-42.json", Bridge.Now + 10), "Stale snapshot accepted");
        snapshot.key = "../abc-42";
        Require(!Bridge.Valid(snapshot, "window-abc-42.json", Bridge.Now), "Unsafe key accepted");
        string fixture = Path.Combine(Path.GetTempPath(), "floating-tabs-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(fixture);
        try {
            Bridge.Write(fixture, "reply.json", new { title = "first", updated = Bridge.Now });
            Bridge.Write(fixture, "reply.json", new { title = "second", updated = Bridge.Now });
            Require(File.ReadAllText(Path.Combine(fixture, "reply.json")).Contains("second"), "Atomic replacement failed");
            Require(Directory.GetFiles(fixture).Length == 1, "Temporary file leaked");
        } finally { Directory.Delete(fixture, true); }
    }
}
