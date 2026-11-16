(function () {
  const GS = window.GS;
  const host = document.getElementById("desk");
  if (!host) return;

  const reduced = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const MENU = 26;
  const STOP = {};
  const layouts = [
    { min: 760, w: 1280, h: 800 },
    { min: 500, w: 1000, h: 700 },
    { min: 0, w: 700, h: 620, list: false },
  ];
  const apps = [
    { id: "code", name: "Editor", icon: "app-editor", title: "Amber.json", at: [0.535, 0.545, 0.42, 0.4] },
    { id: "term", name: "Terminal", icon: "app-terminal", title: "Terminal", at: [0.47, 0.075, 0.4, 0.385] },
    { id: "notes", name: "Notes", icon: "app-notes", title: "Notes", at: [0.17, 0.26, 0.4, 0.56] },
  ];
  const cycle = ["Default", "Sunset", "Nord", "Blueprint", "Tiles"];
  const state = { dark: true, gap: 8 };
  const store = GS.store;

  const body = {
    code:
      '<div class="code-tabs"><span class="is-on"><i></i>Amber.json</span><span>Nord.json</span></div><pre>' +
      GS.themes.example.json
        .split("\n")
        .map((l) => `<span class="ln">${GS.themes.highlight(l, "#0A84FF").replace(/ style="[^"]*"/g, "") || " "}</span>`)
        .join("") +
      "</pre>",
    term: '<pre><span class="tp">~</span> <span class="ta">❯</span> brew install --cask konieczkow/tap/gridsnap\n<span class="tb"><span class="ta">==&gt;</span> Installing Cask gridsnap</span>\n<span class="tb"><span class="ta">==&gt;</span> Moving App \'GridSnap.app\' to \'/Applications/GridSnap.app\'</span>\n🍺  gridsnap was successfully installed!\n<span class="tp">~</span> <span class="ta">❯</span> open -a GridSnap\n<span class="tp">~</span> <span class="ta">❯</span> <span class="tcur"></span></pre>',
    notes:
      '<div class="notes-side"><div class="is-sel"><b>Snap a window</b><span>09:41&ensp;Press ⌃⌥D</span></div><div><b>Presets</b><span>Yesterday&ensp;Hold Shift</span></div><div><b>Themes</b><span>Friday&ensp;Ten are built in</span></div><div><b>Keyboard</b><span>Thursday&ensp;Arrow keys</span></div></div>' +
      '<div class="notes-main"><time>Today at 09:41</time><strong>Snap a window</strong><ol><li>Press <kbd>⌃</kbd><kbd>⌥</kbd><kbd>D</kbd>.</li><li>Drag across the cells you want.</li><li>Release.</li></ol><p>To undo the last snap, press <kbd>⌃</kbd><kbd>⌥</kbd><kbd>Z</kbd>.</p><p>To save the area as a preset, hold Shift when you release.</p></div>',
  };

  host.innerHTML =
    '<div class="stage" data-mode="dark"><div class="wall wall-dark"></div><div class="wall wall-light"></div>' +
    '<div class="menubar"><b data-app></b><span>File</span><span>Edit</span><span>View</span><span>Window</span><span>Help</span><span class="mb-space"></span><span class="mb-status" data-status title="GridSnap"><svg><use href="#i-status"/></svg></span><span class="mb-clock" data-clock></span></div>' +
    apps
      .map(
        (a) =>
          `<div class="win ${a.id}-win" data-win="${a.id}"><div class="win-bar"><span class="lights"><i></i><i></i><i></i></span><span class="win-title">${a.title}</span></div><div class="win-body">${body[a.id]}</div></div>`,
      )
      .join("") +
    '<div class="panel-host"></div><div class="hud"></div><div class="fake-cursor"><svg><use href="#i-cursor"/></svg></div></div>';

  const stage = host.querySelector(".stage");
  const panelHost = host.querySelector(".panel-host");
  const hud = host.querySelector(".hud");
  const cursor = host.querySelector(".fake-cursor");
  const appLabel = host.querySelector("[data-app]");
  const clock = host.querySelector("[data-clock]");
  const status = host.querySelector("[data-status]");
  const hint = document.querySelector("[data-hint]");
  const steps = Array.from(document.querySelectorAll("#steps li"));
  const gridChip = document.querySelector('[data-act="grid"]');
  const select = document.querySelector("[data-theme-select]");
  const modeButtons = Array.from(document.querySelectorAll(".seg [data-mode]"));

  const wins = apps.map((a) => Object.assign({ el: host.querySelector(`[data-win="${a.id}"]`), frame: null, snap: null }, a));
  const byId = Object.fromEntries(wins.map((w) => [w.id, w]));
  let order = wins.slice();
  let L = layouts[0];
  let scale = 1;
  let gridActive = false;
  let target = null;
  let original = null;
  let moved = false;
  let lastSnap = null;
  let snapped = [];
  let auto = false;
  let run = 0;
  let visible = true;
  let pos = { x: 0, y: 0 };
  let hudTimer = null;
  let live = false;
  let touch = matchMedia("(hover: none) and (pointer: coarse)").matches;
  const invite = () => (touch ? "This demo is live. Tap the screen to try it." : "This demo is live. Drag across the grid.");

  function setLive(on) {
    live = on;
    host.classList.toggle("is-live", on);
  }

  const panel = new GS.Panel(panelHost, { aspect: (L.h - MENU) / L.w, screenWidth: L.w, app: { name: "Notes", icon: "app-notes" } });

  const vis = () => ({ x: 0, y: MENU, w: L.w, h: L.h - MENU });
  const focused = () => order[order.length - 1];

  function screenFrame(r) {
    const g = Math.max(state.gap, 0) / 2;
    const v = vis();
    const fw = v.w - 2 * g;
    const fh = v.h - 2 * g;
    const w = r.w * fw - 2 * g;
    const h = r.h * fh - 2 * g;
    return { x: 2 * g + r.x * fw, y: v.y + v.h - (2 * g + r.y * fh) - h, w, h };
  }

  function screenFraction(fr) {
    const g = Math.max(state.gap, 0) / 2;
    const v = vis();
    const fw = v.w - 2 * g;
    const fh = v.h - 2 * g;
    if (fw <= 0 || fh <= 0) return null;
    const x0 = Math.max((fr.x - 2 * g) / fw, 0);
    const y0 = Math.max((v.y + v.h - fr.y - fr.h - 2 * g) / fh, 0);
    const x1 = Math.min((fr.x - 2 * g + fr.w + 2 * g) / fw, 1);
    const y1 = Math.min((v.y + v.h - fr.y - 2 * g + 2 * g) / fh, 1);
    return x1 > x0 && y1 > y0 ? { x: x0, y: y0, w: x1 - x0, h: y1 - y0 } : null;
  }

  function setFrame(w, fr) {
    w.frame = { x: fr.x, y: fr.y, w: fr.w, h: fr.h };
    const s = w.el.style;
    s.left = fr.x + "px";
    s.top = fr.y + "px";
    s.width = fr.w + "px";
    s.height = fr.h + "px";
  }

  const near = (a, b) => Math.abs(a.x - b.x) <= 2 && Math.abs(a.y - b.y) <= 2 && Math.abs(a.w - b.w) <= 2 && Math.abs(a.h - b.h) <= 2;

  function focus(w) {
    order = order.filter((o) => o !== w).concat([w]);
    order.forEach((o, i) => {
      o.el.style.zIndex = 10 + i;
      o.el.classList.toggle("is-active", o === w);
    });
    appLabel.textContent = w.name;
  }

  function remember(w) {
    w.snap = Object.assign({}, w.frame);
    if (!snapped.includes(w)) snapped.push(w);
  }

  function applyLook() {
    stage.dataset.mode = state.dark ? "dark" : "light";
    const look = state.dark ? store.looks.dark : store.looks.light;
    const accent = store.accentColour(state.dark);
    panel.setLook(look, state.dark, accent);
    const fill = look.selection.fill;
    if (fill) host.style.setProperty("--glow", GS.themes.css(Object.assign({}, fill, { a: 0.5 }), accent));
    place();
  }

  function place() {
    panelHost.style.left = (L.w - panel.W) / 2 + "px";
    panelHost.style.top = MENU + (L.h - MENU - panel.H) / 2 + "px";
  }

  function setStep(n) {
    steps.forEach((li) => li.classList.toggle("is-on", +li.dataset.step === n));
  }

  function say(text) {
    if (hint && hint.textContent !== text) hint.textContent = text;
  }

  function cue() {
    if (auto) return;
    gridChip.classList.toggle("is-cue", !gridActive);
    status.classList.toggle("is-on", gridActive);
    setStep(gridActive ? (panel.dragging ? 3 : 2) : 1);
  }

  function showGrid() {
    target = focused();
    original = Object.assign({}, target.frame);
    moved = false;
    panel.o.app = { name: target.name, icon: target.icon };
    panel.start = null;
    panel.end = null;
    panel.pending = false;
    panel.pressed = null;
    panel.dragging = false;
    panel.onPanel();
    panel.ghosts = snapped
      .filter((w) => w !== target && w.snap && near(w.frame, w.snap))
      .map((w) => screenFraction(w.frame))
      .filter(Boolean);
    const u = screenFraction(original);
    if (u) {
      const x = GS.cellRange(u.x, u.x + u.w, panel.o.cols);
      const y = GS.cellRange(u.y, u.y + u.h, panel.o.rows);
      panel.start = [x[0], y[0]];
      panel.end = [x[1], y[1]];
      panel.pending = true;
    }
    applyLook();
    panel.active = true;
    gridActive = true;
    panelHost.classList.add("is-open");
    status.classList.add("is-on");
    if (!auto) say(touch ? "Drag across the cells, then lift your finger." : "Drag across the cells, or use the arrow keys and Return.");
    cue();
  }

  function hideGrid() {
    panel.active = false;
    panelHost.classList.remove("is-open");
    status.classList.remove("is-on");
    cue();
  }

  function preview() {
    if (!target) return;
    const r = panel.selectionFraction;
    if (r) {
      setFrame(target, screenFrame(r));
      moved = true;
    } else if (moved && original) setFrame(target, original);
    if (!auto) setStep(panel.dragging ? 3 : 2);
  }

  function commitGrid() {
    if (!gridActive) return;
    gridActive = false;
    preview();
    const done = panel.selection && target;
    if (done) {
      remember(target);
      lastSnap = { win: target, frame: original };
    }
    hideGrid();
    if (!auto)
      say(
        !done
          ? "Cancelled. The window is back where it was."
          : touch
            ? "Snapped. Tap Show grid to snap again, or Undo to go back."
            : "Snapped. Press Z to undo, or click another window and press D.",
      );
  }

  function commitPreset(p) {
    if (!gridActive) return;
    gridActive = false;
    if (target) {
      setFrame(target, screenFrame(p));
      remember(target);
      lastSnap = { win: target, frame: original };
    }
    hideGrid();
    if (!auto) say(touch ? `Snapped to ${p.name}.` : `Snapped to ${p.name}. Press Z to undo.`);
  }

  function cancelGrid(quiet) {
    if (!gridActive) return;
    gridActive = false;
    panel.start = null;
    panel.end = null;
    panel.dragging = false;
    panel.onPanel();
    preview();
    hideGrid();
    if (!auto && !quiet) say(touch ? "Cancelled. Tap Show grid to open the grid again." : "Cancelled. Press D to show the grid again.");
  }

  function undoSnap() {
    cancelGrid(true);
    if (!lastSnap) {
      if (!auto) say("There is no snap to undo yet.");
      return;
    }
    const now = Object.assign({}, lastSnap.win.frame);
    const redo = !!lastSnap.undone;
    setFrame(lastSnap.win, lastSnap.frame);
    lastSnap = { win: lastSnap.win, frame: now, undone: !redo };
    if (!auto)
      say(
        redo
          ? "Redone. The window is snapped again."
          : touch
            ? "Undone. Tap Undo again to redo the snap."
            : "Undone. Press Z again to redo the snap.",
      );
  }

  function applyPreset(p) {
    cancelGrid(true);
    const w = focused();
    lastSnap = { win: w, frame: Object.assign({}, w.frame) };
    setFrame(w, screenFrame(p));
    remember(w);
    if (!auto) say(`Snapped to ${p.name}.`);
  }

  panel.on.preview = preview;
  panel.on.commit = commitGrid;
  panel.on.preset = commitPreset;
  panel.on.cancel = () => cancelGrid();

  function home(w) {
    const v = vis();
    return { x: w.at[0] * v.w, y: MENU + w.at[1] * v.h, w: w.at[2] * v.w, h: w.at[3] * v.h };
  }

  function reset(slow) {
    cancelGrid(true);
    wins.forEach((w) => {
      w.el.classList.toggle("is-slow", !!slow);
      setFrame(w, home(w));
      w.snap = null;
    });
    snapped = [];
    lastSnap = null;
    order = wins.slice();
    focus(byId.notes);
    if (slow) setTimeout(() => wins.forEach((w) => w.el.classList.remove("is-slow")), 700);
  }

  function fit() {
    const width = host.clientWidth;
    if (!width) return;
    const next = layouts.find((l) => width >= l.min);
    if (next !== L || !wins[0].frame) {
      L = next;
      host.style.aspectRatio = `${L.w} / ${L.h}`;
      stage.style.width = L.w + "px";
      stage.style.height = L.h + "px";
      panel.set({ aspect: (L.h - MENU) / L.w, screenWidth: L.w, list: L.list !== false });
      const was = auto;
      stopAuto();
      reset(false);
      applyLook();
      if (was && !reduced) play();
      else {
        showGrid();
        if (touch && !live) say("Tap the screen to try the demo.");
      }
    }
    scale = width / L.w;
    stage.style.transform = `scale(${scale})`;
  }

  function toStage(p) {
    return { x: parseFloat(panelHost.style.left) + p.x, y: parseFloat(panelHost.style.top) + panel.H - p.y };
  }

  function toPanel(s) {
    const x = s.x - parseFloat(panelHost.style.left);
    const top = s.y - parseFloat(panelHost.style.top);
    return { x, y: panel.H - top, inside: x >= 0 && x <= panel.W && top >= 0 && top <= panel.H };
  }

  function moveCursor(p) {
    pos = p;
    cursor.style.transform = `translate(${p.x}px, ${p.y}px)`;
  }

  function showKeys(keys, ms) {
    hud.innerHTML = keys.map((k) => `<kbd>${k}</kbd>`).join("");
    hud.classList.add("is-on");
    clearTimeout(hudTimer);
    hudTimer = setTimeout(() => hud.classList.remove("is-on"), ms || 900);
  }

  function stopAuto() {
    run++;
    auto = false;
    cursor.classList.remove("is-on", "is-down");
    hud.classList.remove("is-on");
  }

  function play() {
    const id = ++run;
    auto = true;
    gridChip.classList.remove("is-cue");
    say(invite());
    const tick = (fn) =>
      new Promise((resolve, reject) => {
        let last = performance.now();
        const loop = (now) => {
          if (id !== run) return reject(STOP);
          const dt = visible && !document.hidden ? Math.min(now - last, 50) : 0;
          last = now;
          if (fn(dt)) return resolve();
          requestAnimationFrame(loop);
        };
        loop(last);
      });
    const wait = (ms) => {
      let t = 0;
      return tick((dt) => (t += dt) >= ms);
    };
    const glide = (to, ms, each) => {
      const from = pos;
      const d = Math.hypot(to.x - from.x, to.y - from.y);
      const total = ms || Math.min(Math.max(d * 1.5, 380), 900);
      let t = 0;
      return tick((dt) => {
        t = Math.min(t + dt, total);
        const k = t / total;
        const e = k < 0.5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2;
        moveCursor({ x: from.x + (to.x - from.x) * e, y: from.y + (to.y - from.y) * e });
        if (each) each();
        return t >= total;
      });
    };
    const click = async (w) => {
      if (focused() === w) return;
      const f = w.frame;
      await glide({ x: f.x + Math.min(f.w * 0.5, 200), y: f.y + 19 });
      cursor.classList.add("is-down");
      await wait(140);
      focus(w);
      cursor.classList.remove("is-down");
      await wait(380);
    };
    const open = async () => {
      setStep(1);
      showKeys(["⌃", "⌥", "D"], 1000);
      await wait(420);
      showGrid();
      await wait(900);
    };
    const drag = async (w, from, to) => {
      await click(w);
      await open();
      await glide(toStage(panel.point(from[0], from[1])));
      await wait(160);
      cursor.classList.add("is-down");
      panel.down(panel.point(from[0], from[1]));
      setStep(2);
      await wait(260);
      await glide(toStage(panel.point(to[0], to[1])), 1150, () => panel.track(toPanel(pos), performance.now()));
      await wait(520);
      setStep(3);
      cursor.classList.remove("is-down");
      panel.up(toPanel(pos), performance.now(), false);
      await wait(1050);
    };
    const key = async (w, n) => {
      await click(w);
      await open();
      await wait(350);
      showKeys([String(n)], 900);
      setStep(2);
      await wait(300);
      panel.pressed = n - 1;
      panel.draw();
      await wait(220);
      setStep(3);
      panel.pressed = null;
      commitPreset(GS.presets[n - 1]);
      await wait(1100);
    };
    const rows = panel.o.rows - 1;
    (async () => {
      try {
        let turn = 0;
        moveCursor({ x: L.w * 0.78, y: L.h * 0.78 });
        await wait(500);
        cursor.classList.add("is-on");
        for (;;) {
          await wait(500);
          await drag(byId.notes, [0, rows], [5, 0]);
          await key(byId.term, 7);
          await drag(byId.code, [6, 3], [11, 0]);
          await glide({ x: L.w * 0.5, y: L.h * 0.56 }, 700);
          setStep(0);
          await wait(2600);
          turn++;
          if (!store.touched) store.pick(cycle[turn % cycle.length]);
          reset(true);
          await wait(1100);
        }
      } catch (error) {
        if (error !== STOP) throw error;
      }
    })();
  }

  function takeover() {
    if (!auto) return false;
    stopAuto();
    cancelGrid(true);
    return true;
  }

  host.addEventListener(
    "pointerdown",
    (e) => {
      if (e.button) return;
      touch = e.pointerType === "touch";
      if (touch && !live) {
        e.stopPropagation();
        return;
      }
      const first = takeover();
      const onPanel = panelHost.contains(e.target);
      if (document.activeElement !== host) host.focus({ preventScroll: true });
      const winEl = e.target.closest(".win");
      if (e.target.closest("[data-status]")) {
        if (first || !gridActive) showGrid();
        else cancelGrid();
        return;
      }
      if (onPanel && gridActive) return;
      if (winEl) {
        const w = byId[winEl.dataset.win];
        if (gridActive) cancelGrid(true);
        focus(w);
        if (first) adopt(e);
        else {
          say(touch ? "Tap Show grid to open the grid for this window." : "Press D to show the grid for this window.");
          if (e.target.closest(".win-bar")) startMove(w, e);
        }
        cue();
        return;
      }
      if (first || (onPanel && !gridActive)) adopt(e);
      else cancelGrid();
    },
    true,
  );

  host.addEventListener("click", () => {
    if (!touch || live) return;
    setLive(true);
    takeover();
    if (!gridActive) showGrid();
    cue();
  });

  function adopt(e) {
    showGrid();
    const p = panel.local(e);
    if (!p.inside || !panel.down(p)) return;
    panel.el.setPointerCapture(e.pointerId);
    e.preventDefault();
    cue();
  }

  function startMove(w, e) {
    const bar = e.target.closest(".win-bar");
    const sx = e.clientX;
    const sy = e.clientY;
    const f = Object.assign({}, w.frame);
    w.el.classList.add("is-loose");
    bar.setPointerCapture(e.pointerId);
    const move = (ev) => {
      const x = Math.min(Math.max(f.x + (ev.clientX - sx) / scale, 80 - f.w), L.w - 80);
      const y = Math.min(Math.max(f.y + (ev.clientY - sy) / scale, MENU), L.h - 40);
      setFrame(w, { x, y, w: f.w, h: f.h });
    };
    const end = () => {
      w.el.classList.remove("is-loose");
      bar.removeEventListener("pointermove", move);
      bar.removeEventListener("pointerup", end);
      bar.removeEventListener("pointercancel", end);
    };
    bar.addEventListener("pointermove", move);
    bar.addEventListener("pointerup", end);
    bar.addEventListener("pointercancel", end);
  }

  host.addEventListener("keydown", (e) => {
    const combo = e.ctrlKey && e.altKey && !e.metaKey;
    const plain = !e.ctrlKey && !e.altKey && !e.metaKey;
    if (e.code === "KeyD" && (combo || plain)) {
      const first = takeover();
      if (first || !gridActive) showGrid();
      else cancelGrid();
    } else if (e.code === "KeyZ" && (combo || plain)) {
      takeover();
      undoSnap();
      cue();
    } else if (e.code === "KeyF" && combo) {
      takeover();
      applyPreset(GS.presets[0]);
      cue();
    } else if (gridActive && !auto && panel.key(e)) {
      cue();
    } else return;
    e.preventDefault();
  });

  document.querySelectorAll(".demo-bar [data-act]").forEach((b) =>
    b.addEventListener("click", () => {
      const act = b.dataset.act;
      if (act === "replay") {
        stopAuto();
        reset(true);
        gridChip.classList.remove("is-cue");
        if (reduced) setTimeout(showGrid, 600);
        else play();
        return;
      }
      const first = takeover();
      setLive(true);
      if (act === "grid") {
        if (first || !gridActive) showGrid();
        else cancelGrid();
        host.focus({ preventScroll: true });
      } else {
        undoSnap();
        cue();
      }
    }),
  );

  const names = GS.themes.builtin.map((t) => t.name).concat([GS.themes.example.name]);
  select.innerHTML = names.map((n) => `<option value="${n}">${n === GS.themes.example.name ? `${n} (example)` : n}</option>`).join("");
  select.addEventListener("change", () => store.pick(select.value, true));
  modeButtons.forEach((b) =>
    b.addEventListener("click", () => {
      state.dark = b.dataset.mode === "dark";
      modeButtons.forEach((o) => o.setAttribute("aria-pressed", String(o === b)));
      applyLook();
    }),
  );
  store.sub(() => {
    select.value = store.name;
    applyLook();
  });

  function tickClock() {
    const d = new Date();
    const day = d.toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short" }).replace(/,/g, "");
    clock.textContent = `${day}\u2002${d.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" })}`;
  }
  tickClock();
  setInterval(tickClock, 20000);

  if ("IntersectionObserver" in window) {
    new IntersectionObserver(
      (entries) => {
        visible = entries[0].isIntersecting;
        if (!visible && live) {
          setLive(false);
          if (!auto) say("Tap the screen to use the demo again.");
        }
      },
      { threshold: 0.15 },
    ).observe(host);
  }
  if ("ResizeObserver" in window) new ResizeObserver(fit).observe(host);
  else window.addEventListener("resize", fit);

  auto = !reduced;
  fit();
})();
