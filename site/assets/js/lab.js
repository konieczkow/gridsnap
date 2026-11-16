(function () {
  const GS = window.GS;
  const root = document.getElementById("lab");
  if (!root) return;

  const T = GS.themes;
  const store = GS.store;
  const all = T.builtin.concat([T.example]);
  const list = root.querySelector("[data-themes]");
  const input = root.querySelector("[data-input]");
  const hl = root.querySelector("[data-hl]");
  const note = root.querySelector("[data-note]");
  const file = root.querySelector("[data-file]");
  const accents = root.querySelector("[data-accents]");
  const isBuiltin = (name) => T.builtin.some((t) => t.name === name);
  const fileName = () => (isBuiltin(store.name) ? `${store.name} copy.json` : `${store.name}.json`);

  list.innerHTML = all
    .map((t) => {
      const d = T.looks[t.name].dark;
      const accent = T.accents[0].dark;
      const panelFill = d.panel.fill ? T.css(d.panel.fill, accent) : "transparent";
      const cell = d.cell.fill && d.cell.fill.a > 0 ? T.css(d.cell.fill, accent) : "transparent";
      const sel = T.css(d.selection.fill, accent);
      const edge = d.selection.stroke && d.selection.stroke.a > 0 ? `;box-shadow:inset 0 0 0 1px ${T.css(d.selection.stroke, accent)}` : "";
      return `<button class="theme" type="button" data-name="${t.name}" aria-pressed="false"><span class="theme-sw"><i style="background:linear-gradient(${cell},${cell}),linear-gradient(${panelFill},${panelFill}),#2d303c"></i><i style="background:${sel}${edge}"></i></span>${t.name}${t === T.example ? "<em>Example</em>" : ""}</button>`;
    })
    .join("");

  accents.innerHTML = T.accents
    .map((a, i) => `<button type="button" style="--c:${a.dark}" aria-label="${a.name}" aria-pressed="false" data-accent="${i}"></button>`)
    .join("");

  const panels = ["dark", "light"].map((mode) => {
    const p = new GS.Panel(root.querySelector(`[data-panel="${mode}"]`), {
      fluid: true,
      aspect: 0.6,
      app: { name: "Notes", icon: "app-notes" },
    });
    p.mode = mode;
    p.active = true;
    p.ghosts = [{ x: 0.5, y: 0.5, w: 0.5, h: 0.5 }];
    p.start = [1, 1];
    p.end = [4, 5];
    return p;
  });

  const mirror = (from) => {
    for (const p of panels) {
      if (p === from) continue;
      p.start = from.start;
      p.end = from.end;
      p.pending = from.pending;
      p.drawSelection();
    }
  };

  for (const p of panels) {
    p.on.preview = () => mirror(p);
    p.on.commit = () => {
      if (!p.selection) {
        p.start = [1, 1];
        p.end = [4, 5];
        p.drawSelection();
      }
      mirror(p);
    };
    p.on.cancel = () => mirror(p);
    p.on.preset = (preset) => {
      const x = GS.cellRange(preset.x, preset.x + preset.w, p.o.cols);
      const y = GS.cellRange(preset.y, preset.y + preset.h, p.o.rows);
      p.start = [x[0], y[0]];
      p.end = [x[1], y[1]];
      p.drawSelection();
      mirror(p);
    };
  }

  function paint() {
    for (const p of panels) {
      const dark = p.mode === "dark";
      p.setLook(dark ? store.looks.dark : store.looks.light, dark, store.accentColour(dark));
    }
  }

  function render() {
    list.querySelectorAll(".theme").forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.name === store.name)));
    accents.querySelectorAll("button").forEach((b) => b.setAttribute("aria-pressed", String(+b.dataset.accent === store.accent)));
    if (input.value !== store.text) input.value = store.text;
    hl.innerHTML = T.highlight(store.text, store.accentColour(true)) + "\n";
    file.textContent = fileName();
    const problem = T.problem(store.text);
    note.classList.toggle("is-bad", !!problem);
    note.textContent = problem
      ? `Not in use: ${problem} The grids show the Default theme.`
      : "This theme has no mistakes. Both grids use it.";
    paint();
  }

  input.addEventListener("input", () => {
    const text = input.value;
    let looks = T.looks.Default;
    try {
      looks = T.load(text);
    } catch (error) {
      looks = T.looks.Default;
    }
    store.set({ text, looks, touched: true });
  });

  list.addEventListener("click", (e) => {
    const b = e.target.closest(".theme");
    if (b) store.pick(b.dataset.name, true);
  });

  accents.addEventListener("click", (e) => {
    const b = e.target.closest("button");
    if (b) store.set({ accent: +b.dataset.accent, touched: true });
  });

  root.querySelector('[data-act="reset"]').addEventListener("click", () => store.pick(store.name, true));

  root.querySelector('[data-act="save"]').addEventListener("click", () => {
    const url = URL.createObjectURL(new Blob([store.text.replace(/\n?$/, "\n")], { type: "application/json" }));
    const a = document.createElement("a");
    a.href = url;
    a.download = fileName();
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  });

  store.sub(render);
  render();
})();
