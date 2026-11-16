(function () {
  const GS = window.GS;
  const clamp = (v, lo, hi) => Math.min(Math.max(v, lo), hi);
  const f = (v) => +v.toFixed(3);

  GS.presets = [
    { name: "Full screen", x: 0, y: 0, w: 1, h: 1, key: "⌃⌥F" },
    { name: "Left half", x: 0, y: 0, w: 0.5, h: 1 },
    { name: "Right half", x: 0.5, y: 0, w: 0.5, h: 1 },
    { name: "Left two thirds", x: 0, y: 0, w: 2 / 3, h: 1 },
    { name: "Right third", x: 2 / 3, y: 0, w: 1 / 3, h: 1 },
    { name: "Centre", x: 1 / 6, y: 0.125, w: 2 / 3, h: 0.75 },
    { name: "Top right quarter", x: 0.5, y: 0.5, w: 0.5, h: 0.5 },
    { name: "Bottom half", x: 0, y: 0, w: 1, h: 0.5 },
    { name: "Top half", x: 0, y: 0.5, w: 1, h: 0.5 },
  ];

  GS.cellRange = function (lo, hi, n) {
    const a = Math.round(lo * n);
    const b = Math.round(hi * n) - 1;
    const c = clamp(Math.floor(((lo + hi) / 2) * n), 0, n - 1);
    return a <= b ? [Math.max(a, 0), Math.min(b, n - 1)] : [c, c];
  };

  class Panel {
    constructor(host, options) {
      this.o = Object.assign(
        {
          cols: 12,
          rows: 8,
          aspect: 0.6,
          header: true,
          list: true,
          marks: true,
          presets: GS.presets,
          width: 480,
          app: null,
          grace: 1,
          ring: false,
          interactive: true,
          fluid: false,
        },
        options,
      );
      this.look = GS.themes.looks.Default.dark;
      this.dark = true;
      this.accent = GS.themes.accents[0].dark;
      this.start = null;
      this.end = null;
      this.pending = false;
      this.pressed = null;
      this.ghosts = [];
      this.leftAt = null;
      this.lapse = null;
      this.dragging = false;
      this.active = false;
      this.on = { preview() {}, commit() {}, preset() {}, cancel() {} };
      this.el = document.createElement("div");
      this.el.className = "gs-panel";
      this.el.innerHTML =
        '<div class="gs-glass"></div><svg class="gs-svg" xmlns="http://www.w3.org/2000/svg" aria-hidden="true" focusable="false"><g class="gs-base"></g><rect class="gs-selection"></rect><g class="gs-over"></g></svg>';
      this.svg = this.el.querySelector("svg");
      this.base = this.el.querySelector(".gs-base");
      this.sel = this.el.querySelector(".gs-selection");
      this.over = this.el.querySelector(".gs-over");
      host.appendChild(this.el);
      this.draw();
      if (this.o.interactive) this.bind();
    }

    layout() {
      const o = this.o;
      this.W = o.width;
      this.headerH = o.header && o.app ? 52 : 0;
      this.list = o.list ? o.presets.slice(0, 9) : [];
      this.listH = this.list.length ? Math.floor((this.list.length + 2) / 3) * 20 + 8 : 0;
      this.H = this.W * o.aspect + this.listH + this.headerH;
      this.grid = { x: 10, y: 10 + this.listH, w: this.W - 20, h: this.H - 20 - this.listH - this.headerH };
      this.svg.setAttribute("viewBox", `0 0 ${f(this.W)} ${f(this.H)}`);
      this.el.style.aspectRatio = `${f(this.W)} / ${f(this.H)}`;
      this.el.style.width = o.fluid ? "100%" : this.W + "px";
      const r = Math.max(this.look.panel.radius || 0, 0);
      this.el.style.borderRadius = `${f((r / this.W) * 100)}% / ${f((r / this.H) * 100)}%`;
      this.el.dataset.mode = this.dark ? "dark" : "light";
    }

    set(options) {
      Object.assign(this.o, options);
      this.draw();
    }

    setLook(look, dark, accent) {
      this.look = look;
      this.dark = dark;
      if (accent) this.accent = accent;
      this.draw();
    }

    css(p) {
      return GS.themes.css(p, this.accent);
    }

    box(x, y, w, h, s, extra) {
      const r = Math.min(Math.max(s.radius || 0, 0), w / 2, h / 2);
      const lw = s.lineWidth === undefined ? 1 : s.lineWidth;
      const stroke = s.stroke && lw > 0 ? ` stroke="${this.css(s.stroke)}" stroke-width="${f(lw)}"` : "";
      return `<rect x="${f(x)}" y="${f(this.H - y - h)}" width="${f(Math.max(w, 0))}" height="${f(Math.max(h, 0))}" rx="${f(Math.max(r, 0))}" fill="${s.fill ? this.css(s.fill) : "none"}"${stroke}${extra || ""}/>`;
    }

    rim(s, fill) {
      const i = s.stroke ? Math.max(s.lineWidth === undefined ? 1 : s.lineWidth, 0) / 2 : 0;
      const style = { fill: fill ? s.fill : null, stroke: s.stroke, lineWidth: s.lineWidth, radius: (this.look.panel.radius || 0) - i };
      return this.box(i, i, this.W - 2 * i, this.H - 2 * i, style);
    }

    cellRect(r, tolX, tolY) {
      const { cols, rows, marks } = this.o;
      const g = this.grid;
      const cw = g.w / cols;
      const ch = g.h / rows;
      const inset = Math.max(this.look.spacing, 0) / 2;
      const gap = (i, n) => (!marks || i === 0 || i === n ? 0 : (i * 2) % n === 0 ? 3 : (i * 3) % n === 0 || (i * 4) % n === 0 ? 1.5 : 0);
      const edge = (c, n, size, tol, sign) => {
        const i = Math.round(c);
        return Math.abs(c - i) <= tol ? i * size + sign * (inset + gap(i, n)) : c * size;
      };
      const x0 = g.x + edge(r.x, cols, cw, tolX || 0, 1);
      const x1 = g.x + edge(r.x + r.w, cols, cw, tolX || 0, -1);
      const y0 = g.y + edge(r.y, rows, ch, tolY || 0, 1);
      const y1 = g.y + edge(r.y + r.h, rows, ch, tolY || 0, -1);
      return { x: x0, y: y0, w: Math.max(x1 - x0, 0), h: Math.max(y1 - y0, 0) };
    }

    entryRect(i) {
      const w = this.grid.w / 3;
      return { x: this.grid.x + (i % 3) * w, y: 10 + (Math.floor((this.list.length - 1) / 3) - Math.floor(i / 3)) * 20, w, h: 20 };
    }

    get selection() {
      if (!this.start || !this.end) return null;
      const s = this.start;
      const e = this.end;
      return { x0: Math.min(s[0], e[0]), x1: Math.max(s[0], e[0]), y0: Math.min(s[1], e[1]), y1: Math.max(s[1], e[1]) };
    }

    get selectionFraction() {
      const s = this.selection;
      if (!s) return null;
      const { cols, rows } = this.o;
      return { x: s.x0 / cols, y: s.y0 / rows, w: (s.x1 - s.x0 + 1) / cols, h: (s.y1 - s.y0 + 1) / rows };
    }

    draw() {
      this.layout();
      const L = this.look;
      const { cols, rows } = this.o;
      const label = this.dark ? "rgba(255,255,255,0.85)" : "rgba(0,0,0,0.85)";
      const ink = (s) => (s.text ? this.css(s.text) : label);
      let base = this.rim(L.panel, true);
      if (this.headerH > 0) {
        const size = this.headerH - 16;
        const x = this.grid.x + 2;
        const top = this.headerH - size;
        base += `<use href="#${this.o.app.icon}" x="${x}" y="${top}" width="${size}" height="${size}"/>`;
        base += `<text class="gs-name" x="${x + size + 12}" y="${top + size / 2}" fill="${ink(L.header)}">${this.o.app.name}</text>`;
      }
      for (let x = 0; x < cols; x++) {
        for (let y = 0; y < rows; y++) {
          const c = this.cellRect({ x, y, w: 1, h: 1 });
          base += this.box(c.x, c.y, c.w, c.h, L.cell);
        }
      }
      const vw = this.o.screenWidth || 1280;
      const vh = vw * this.o.aspect;
      for (const u of this.ghosts) {
        const c = this.cellRect({ x: u.x * cols, y: u.y * rows, w: u.w * cols, h: u.h * rows }, (2 * cols) / vw, (2 * rows) / vh);
        base += this.box(c.x, c.y, c.w, c.h, L.ghost);
      }
      this.base.innerHTML = base;
      let over = "";
      this.list.forEach((p, i) => {
        const r = this.entryRect(i);
        const cap = { x: r.x + 2, y: r.y + r.h / 2 - 8, w: 16, h: 16 };
        if (this.pressed === i) over += this.box(r.x, r.y, r.w, r.h, L.preset);
        over += this.box(cap.x, cap.y, cap.w, cap.h, L.keycap);
        const mid = this.H - (r.y + r.h / 2);
        over += `<text class="gs-cap" x="${f(cap.x + 8)}" y="${f(mid)}" fill="${ink(L.keycap)}">${i + 1}</text>`;
        over += `<text class="gs-entry" x="${f(cap.x + 22)}" y="${f(mid)}" fill="${ink(L.preset)}">${p.name}</text>`;
      });
      if (this.o.ring) over += this.rim(L.focusRing, false);
      this.over.innerHTML = over;
      this.drawSelection();
    }

    drawSelection() {
      const s = this.selection;
      if (!s) {
        this.sel.style.display = "none";
        return;
      }
      const style = this.pending ? this.look.pending : this.look.selection;
      const c = this.cellRect({ x: s.x0, y: s.y0, w: s.x1 - s.x0 + 1, h: s.y1 - s.y0 + 1 });
      const r = Math.min(Math.max(style.radius || 0, 0), c.w / 2, c.h / 2);
      const lw = style.lineWidth === undefined ? 1 : style.lineWidth;
      const fresh = this.sel.style.display === "none";
      if (fresh) this.sel.style.transition = "none";
      this.sel.style.display = "";
      const box = { x: f(c.x), y: f(this.H - c.y - c.h), width: f(c.w), height: f(c.h) };
      for (const k of Object.keys(box)) {
        this.sel.setAttribute(k, box[k]);
        this.sel.style[k] = box[k] + "px";
      }
      this.sel.setAttribute("rx", f(r));
      this.sel.style.fill = style.fill ? this.css(style.fill) : "none";
      this.sel.style.stroke = style.stroke && lw > 0 ? this.css(style.stroke) : "none";
      this.sel.style.strokeWidth = f(lw) + "px";
      if (fresh) {
        this.sel.getBoundingClientRect();
        this.sel.style.transition = "";
      }
    }

    clear() {
      this.start = null;
      this.end = null;
      this.pending = false;
      this.pressed = null;
      this.onPanel();
      this.draw();
    }

    onPanel() {
      this.leftAt = null;
      clearTimeout(this.lapse);
      this.lapse = null;
    }

    local(e) {
      const b = this.el.getBoundingClientRect();
      return {
        x: ((e.clientX - b.left) / b.width) * this.W,
        y: this.H - ((e.clientY - b.top) / b.height) * this.H,
        inside: e.clientX >= b.left && e.clientX <= b.right && e.clientY >= b.top && e.clientY <= b.bottom,
      };
    }

    point(col, row, fx, fy) {
      const g = this.grid;
      return {
        x: g.x + ((col + (fx === undefined ? 0.5 : fx)) * g.w) / this.o.cols,
        y: g.y + ((row + (fy === undefined ? 0.5 : fy)) * g.h) / this.o.rows,
        inside: true,
      };
    }

    entryPoint(i) {
      const r = this.entryRect(i);
      return { x: r.x + 40, y: r.y + r.h / 2, inside: true };
    }

    toClient(p) {
      const b = this.el.getBoundingClientRect();
      return { x: b.left + (p.x / this.W) * b.width, y: b.top + ((this.H - p.y) / this.H) * b.height };
    }

    cell(p) {
      const g = this.grid;
      return [
        clamp(Math.floor(((p.x - g.x) / g.w) * this.o.cols), 0, this.o.cols - 1),
        clamp(Math.floor(((p.y - g.y) / g.h) * this.o.rows), 0, this.o.rows - 1),
      ];
    }

    entry(p) {
      for (let i = 0; i < this.list.length; i++) {
        const r = this.entryRect(i);
        if (p.x >= r.x && p.x < r.x + r.w && p.y >= r.y && p.y < r.y + r.h) return i;
      }
      return null;
    }

    down(p) {
      if (!this.active) return false;
      if (!p.inside || p.y > this.H - this.headerH) return false;
      if (this.list.length && p.y < this.grid.y - 4) {
        this.pressed = this.entry(p);
        this.draw();
        return true;
      }
      this.dragging = true;
      this.onPanel();
      this.start = this.cell(p);
      this.end = this.start;
      this.pending = false;
      this.drawSelection();
      return true;
    }

    track(p, t) {
      if (!this.active) return;
      const grace = this.o.grace * 1000;
      let next = this.cell(p);
      if (p.inside) this.onPanel();
      else if (this.leftAt !== null) {
        if (t - this.leftAt >= grace) next = null;
      } else if (grace > 0) {
        this.leftAt = t;
        this.lapse = setTimeout(() => {
          if (!this.dragging) return;
          this.leftAt = -Infinity;
          this.setEnd(null);
        }, grace);
      } else next = null;
      this.setEnd(next);
    }

    setEnd(next) {
      if (!this.active) return;
      const e = this.end;
      if ((next === null && e === null) || (next && e && next[0] === e[0] && next[1] === e[1])) return;
      this.end = next;
      this.drawSelection();
      this.on.preview();
    }

    up(p, t, shift) {
      if (this.pressed !== null) {
        const i = this.pressed;
        const hit = this.entry(p) === i;
        this.pressed = null;
        this.draw();
        if (hit) this.on.preset(this.list[i]);
      }
      if (!this.dragging) return;
      this.dragging = false;
      this.track(p, t);
      this.onPanel();
      this.on.commit(!!shift);
    }

    key(e) {
      if (!this.active) return false;
      if (e.key === "Escape") {
        this.on.cancel();
        return true;
      }
      if (!e.metaKey && !e.ctrlKey && !e.altKey && /^(Digit|Numpad)[1-9]$/.test(e.code)) {
        const i = +e.code.slice(-1) - 1;
        if (i < this.o.presets.length) this.on.preset(this.o.presets[i]);
        return true;
      }
      if (e.key === "Enter") {
        this.on.commit(e.shiftKey);
        return true;
      }
      const arrows = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowDown: [0, -1], ArrowUp: [0, 1] };
      if (arrows[e.key]) {
        this.step(arrows[e.key][0], arrows[e.key][1], e.shiftKey);
        return true;
      }
      return false;
    }

    step(dx, dy, resize) {
      const { cols, rows } = this.o;
      let lo = [0, 0];
      let hi = [cols - 1, rows - 1];
      const s = this.selection;
      if (s) {
        lo = [s.x0, s.y0];
        hi = [s.x1, s.y1];
        if (resize) hi = [clamp(hi[0] + dx, lo[0], cols - 1), clamp(hi[1] + dy, lo[1], rows - 1)];
        else {
          const mx = clamp(dx, -lo[0], cols - 1 - hi[0]);
          const my = clamp(dy, -lo[1], rows - 1 - hi[1]);
          lo = [lo[0] + mx, lo[1] + my];
          hi = [hi[0] + mx, hi[1] + my];
        }
        if (!this.pending && lo[0] === s.x0 && lo[1] === s.y0 && hi[0] === s.x1 && hi[1] === s.y1) return;
      }
      this.start = lo;
      this.end = hi;
      this.pending = false;
      this.drawSelection();
      this.on.preview();
    }

    bind() {
      const el = this.el;
      el.addEventListener("pointerdown", (e) => {
        if (e.button || !this.active || this.dragging || this.pressed !== null) return;
        if (this.down(this.local(e))) {
          el.setPointerCapture(e.pointerId);
          e.preventDefault();
        }
      });
      el.addEventListener("pointermove", (e) => {
        if (this.dragging) this.track(this.local(e), performance.now());
      });
      el.addEventListener("pointerup", (e) => {
        if (this.dragging || this.pressed !== null) this.up(this.local(e), performance.now(), e.shiftKey);
      });
      el.addEventListener("pointercancel", () => {
        if (this.dragging) {
          this.dragging = false;
          this.on.cancel();
        }
        this.pressed = null;
      });
    }
  }

  GS.Panel = Panel;
})();
