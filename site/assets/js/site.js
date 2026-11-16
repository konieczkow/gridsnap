(function () {
  const GS = window.GS;
  const reduced = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const repo = "konieczkow/gridsnap";

  const nav = document.querySelector(".nav");
  const stick = () => nav.classList.toggle("is-stuck", window.scrollY > 8);
  window.addEventListener("scroll", stick, { passive: true });
  stick();

  const toggle = nav.querySelector(".nav-toggle");
  const menu = (open) => {
    nav.classList.toggle("is-open", open);
    toggle.setAttribute("aria-expanded", String(open));
  };
  toggle.addEventListener("click", () => menu(!nav.classList.contains("is-open")));
  nav.querySelectorAll(".nav-links a").forEach((a) => a.addEventListener("click", () => menu(false)));
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && nav.classList.contains("is-open")) {
      menu(false);
      toggle.focus();
    }
  });
  document.addEventListener("pointerdown", (e) => {
    if (nav.classList.contains("is-open") && !nav.contains(e.target)) menu(false);
  });

  document.querySelectorAll("[data-copy]").forEach((box) => {
    const button = box.querySelector("button");
    const label = button.getAttribute("aria-label");
    let timer;
    button.addEventListener("click", async () => {
      const text = box.dataset.copy;
      try {
        await navigator.clipboard.writeText(text);
      } catch {
        const area = document.createElement("textarea");
        area.value = text;
        area.style.cssText = "position:fixed;opacity:0";
        document.body.appendChild(area);
        area.select();
        document.execCommand("copy");
        area.remove();
      }
      box.classList.add("is-copied");
      button.setAttribute("aria-label", "Copied");
      clearTimeout(timer);
      timer = setTimeout(() => {
        box.classList.remove("is-copied");
        button.setAttribute("aria-label", label);
      }, 1800);
    });
  });

  const reveals = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window && !reduced) {
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((e) => {
          if (!e.isIntersecting) return;
          e.target.classList.add("is-in");
          io.unobserve(e.target);
        });
      },
      { rootMargin: "0px 0px -8% 0px", threshold: 0.08 },
    );
    reveals.forEach((el, i) => {
      el.style.transitionDelay = `${(i % 3) * 70}ms`;
      io.observe(el);
    });
  } else reveals.forEach((el) => el.classList.add("is-in"));

  function watch(el, fn) {
    let on = true;
    if ("IntersectionObserver" in window) {
      on = false;
      new IntersectionObserver((entries) => (on = entries[0].isIntersecting), { threshold: 0.2 }).observe(el);
    }
    return () => on && !document.hidden && fn();
  }

  const mbarClock = document.querySelector(".mbar-clock");
  if (mbarClock) {
    const d = new Date();
    mbarClock.textContent = `${d.toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short" }).replace(/,/g, "")}\u2002${d.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" })}`;
  }

  const keysHost = document.getElementById("keys-panel");
  if (keysHost && GS) {
    const panel = new GS.Panel(keysHost, { header: false, list: false, fluid: true, interactive: false, aspect: 0.6 });
    const caps = Object.fromEntries(Array.from(document.querySelectorAll("#keys-row kbd")).map((k) => [k.dataset.k, k]));
    const moves = { left: [-1, 0], right: [1, 0], up: [0, 1], down: [0, -1] };
    const script = [
      null,
      ["right"],
      ["right"],
      ["shift", "right"],
      ["shift", "right"],
      ["shift", "up"],
      ["shift", "up"],
      ["left"],
      ["down"],
      ["shift", "left"],
      ["return"],
      null,
      null,
    ];
    let i = 0;
    const begin = () => {
      panel.ghosts = [];
      panel.start = [1, 3];
      panel.end = [3, 5];
      panel.pending = true;
      panel.draw();
    };
    const press = (keys) => {
      keys.forEach((k) => caps[k].classList.add("is-down"));
      setTimeout(() => keys.forEach((k) => caps[k].classList.remove("is-down")), 260);
    };
    begin();
    if (reduced) {
      panel.pending = false;
      panel.end = [6, 6];
      panel.draw();
    } else {
      setInterval(
        watch(keysHost, () => {
          const keys = script[i];
          i = (i + 1) % script.length;
          if (i === 1) begin();
          if (!keys) return;
          press(keys);
          if (keys[0] === "return") {
            const f = panel.selectionFraction;
            panel.ghosts = f ? [f] : [];
            panel.start = null;
            panel.end = null;
            panel.draw();
            return;
          }
          const m = moves[keys[keys.length - 1]];
          panel.step(m[0], m[1], keys[0] === "shift");
        }),
        640,
      );
    }
  }

  const presetsArt = document.getElementById("presets-art");
  if (presetsArt && GS) {
    presetsArt.innerHTML = GS.presets
      .map((p, i) => {
        const pad = 5;
        const style = `left:calc(${p.x * 100}% + ${pad}px);top:calc(${(1 - p.y - p.h) * 100}% + ${pad}px);width:calc(${p.w * 100}% - ${pad * 2}px);height:calc(${p.h * 100}% - ${pad * 2}px)`;
        return `<div class="preset" data-i="${i}"><div class="preset-screen"><i style="${style}"></i></div><div class="preset-name"><kbd>${i + 1}</kbd><span>${p.name}</span></div></div>`;
      })
      .join("");
    const tiles = Array.from(presetsArt.children);
    let current = 0;
    let hover = false;
    const show = (n) => {
      current = n;
      tiles.forEach((t, j) => t.classList.toggle("is-on", j === n));
    };
    show(1);
    tiles.forEach((t, j) => {
      t.addEventListener("pointerenter", () => {
        hover = true;
        show(j);
      });
      t.addEventListener("pointerleave", () => (hover = false));
    });
    if (!reduced)
      setInterval(
        watch(presetsArt, () => {
          if (!hover) show((current + 1) % tiles.length);
        }),
        1500,
      );
  }

  const sizeHost = document.getElementById("size-panel");
  if (sizeHost && GS) {
    const values = { cols: 12, rows: 8, gap: 8 };
    const panel = new GS.Panel(sizeHost, { header: false, list: false, fluid: true, interactive: false, aspect: 0.6 });
    const screen = document.getElementById("size-screen");
    const apply = () => {
      const { cols, rows } = values;
      panel.o.cols = cols;
      panel.o.rows = rows;
      panel.start = [0, 0];
      panel.end = [Math.max(Math.ceil(cols / 2) - 1, 0), rows - 1];
      panel.ghosts =
        cols > 1 && rows > 1
          ? [
              {
                x: Math.ceil(cols / 2) / cols,
                y: Math.floor(rows / 2) / rows,
                w: 1 - Math.ceil(cols / 2) / cols,
                h: 1 - Math.floor(rows / 2) / rows,
              },
            ]
          : [];
      panel.draw();
      screen.style.setProperty("--g", `${(values.gap / 560) * 100}cqw`);
    };
    document.querySelectorAll(".stepper").forEach((s) => {
      const key = s.dataset.key;
      const min = +s.dataset.min;
      const max = +s.dataset.max;
      const step = +s.dataset.step;
      const out = s.querySelector("output");
      const [less, more] = s.querySelectorAll("button");
      const set = (v) => {
        values[key] = Math.min(Math.max(v, min), max);
        out.textContent = values[key];
        less.disabled = values[key] <= min;
        more.disabled = values[key] >= max;
        apply();
      };
      const hold = (button, dir) => {
        let timer;
        let repeat;
        const stop = () => {
          clearTimeout(timer);
          clearInterval(repeat);
        };
        button.addEventListener("click", (e) => {
          if (e.detail === 0) set(values[key] + dir * step);
        });
        button.addEventListener("pointerdown", (e) => {
          if (e.button) return;
          set(values[key] + dir * step);
          timer = setTimeout(() => (repeat = setInterval(() => set(values[key] + dir * step), 70)), 380);
        });
        ["pointerup", "pointerleave", "pointercancel"].forEach((n) => button.addEventListener(n, stop));
      };
      hold(less, -1);
      hold(more, 1);
      set(values[key]);
    });
  }

  document.querySelectorAll(".card, .way").forEach((card) => {
    card.addEventListener("pointermove", (e) => {
      const r = card.getBoundingClientRect();
      card.style.setProperty("--mx", `${e.clientX - r.left}px`);
      card.style.setProperty("--my", `${e.clientY - r.top}px`);
    });
  });

  const format = (n) => (n >= 1000 ? (n / 1000).toFixed(n >= 10000 ? 0 : 1).replace(/\.0$/, "") + "k" : String(n));

  function showRelease(r) {
    if (!r || typeof r.url !== "string" || r.url.indexOf(`https://github.com/${repo}/releases/download/`) !== 0) return;
    document.querySelectorAll("[data-release]").forEach((a) => {
      a.href = r.url;
      a.setAttribute("download", "");
    });
    const v = document.querySelector("[data-version]");
    if (v && /^[\w.-]+$/.test(r.version)) v.textContent = `Version ${r.version}`;
    const size = document.querySelector("[data-size]");
    if (size && r.size > 0) size.textContent = `The download is ${(r.size / 1e6).toFixed(1)} MB. `;
  }

  function showStars(n) {
    const el = document.querySelector("[data-stars]");
    if (!el || typeof n !== "number" || n < 1) return;
    el.querySelector("b").textContent = format(n);
    el.hidden = false;
  }

  function cached(key, url, pick, show) {
    try {
      const hit = JSON.parse(sessionStorage.getItem(key) || "null");
      if (hit) return show(hit.v);
    } catch {
      sessionStorage.removeItem(key);
    }
    fetch(url, { headers: { Accept: "application/vnd.github+json" } })
      .then((r) => (r.ok ? r.json() : null))
      .then((j) => {
        if (!j) return;
        const v = pick(j);
        if (v === null || v === undefined) return;
        try {
          sessionStorage.setItem(key, JSON.stringify({ v }));
        } finally {
          show(v);
        }
      })
      .catch(() => {});
  }

  if (window.fetch && location.protocol !== "file:") {
    cached(
      "gs-release",
      `https://api.github.com/repos/${repo}/releases/latest`,
      (j) => {
        const asset = (j.assets || []).find((a) => /\.zip$/.test(a.name));
        return asset ? { version: String(j.tag_name || "").replace(/^v/, ""), url: asset.browser_download_url, size: asset.size } : null;
      },
      showRelease,
    );
    cached("gs-stars", `https://api.github.com/repos/${repo}`, (j) => j.stargazers_count, showStars);
  }
})();
