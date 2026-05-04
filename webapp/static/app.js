let driversChart;
let constructorsChart;
let driverIdsForChart = [];
let constructorIdsForChart = [];

const state = {
  circuitsLoaded: false,
  constructorProfilesLoaded: false,
  currentLoaded: false
};

async function getJson(url) {
  const response = await fetch(url);
  if (!response.ok) {
    const err = await response.json().catch(() => ({}));
    throw new Error(err.error || `Request failed: ${url}`);
  }
  return response.json();
}

function fmtNum(v, digits = 0) {
  if (v === null || v === undefined || Number.isNaN(Number(v))) return "—";
  return Number(v).toLocaleString(undefined, {
    maximumFractionDigits: digits,
    minimumFractionDigits: digits
  });
}

function statGrid(pairs) {
  const cells = pairs
    .map(
      ([label, value]) =>
        `<div class="stat-tile"><span class="stat-label">${label}</span><span class="stat-value">${value ?? "—"}</span></div>`
    )
    .join("");
  return `<div class="stat-grid">${cells}</div>`;
}

function deriveDriverCareerFromHistory(history, fallbackName) {
  if (!history.length) {
    return { full_name: fallbackName };
  }
  const years = history.map((h) => h.season_year);
  const champs = history.filter((h) => Number(h.championship_position) === 1).length;
  const totalRaces = history.reduce((s, h) => s + Number(h.races_entered || 0), 0);
  const totalWins = history.reduce((s, h) => s + Number(h.wins || 0), 0);
  const totalPodiums = history.reduce((s, h) => s + Number(h.podiums || 0), 0);
  let weightedFin = 0;
  let finW = 0;
  history.forEach((h) => {
    const n = Number(h.races_entered || 0);
    const af = Number(h.avg_finish_position);
    if (n && !Number.isNaN(af)) {
      weightedFin += af * n;
      finW += n;
    }
  });
  return {
    full_name: history[0].full_name || fallbackName,
    nationality: history[0].nationality,
    career_start_year: Math.min(...years),
    career_end_year: Math.max(...years),
    seasons_active: years.length,
    total_races: totalRaces,
    total_wins: totalWins,
    total_podiums: totalPodiums,
    total_poles: history.reduce((s, h) => s + Number(h.poles || 0), 0),
    total_dnfs: history.reduce((s, h) => s + Number(h.dnfs || 0), 0),
    total_points: history.reduce((s, h) => s + Number(h.points_scored || 0), 0),
    win_rate_pct: totalRaces ? Math.round((totalWins / totalRaces) * 10000) / 100 : null,
    podium_rate_pct: totalRaces ? Math.round((totalPodiums / totalRaces) * 10000) / 100 : null,
    avg_finish_position: finW ? Math.round((weightedFin / finW) * 100) / 100 : null,
    championships: champs
  };
}

function setTabs() {
  document.querySelectorAll(".tab").forEach((btn) => {
    btn.addEventListener("click", () => {
      document.querySelectorAll(".tab").forEach((b) => {
        b.classList.remove("active");
        b.setAttribute("aria-selected", "false");
      });
      btn.classList.add("active");
      btn.setAttribute("aria-selected", "true");

      document.querySelectorAll(".panel").forEach((p) => {
        p.classList.remove("active");
        p.hidden = true;
      });
      const panel = document.getElementById(`panel-${btn.dataset.tab}`);
      panel.classList.add("active");
      panel.hidden = false;

      if (btn.dataset.tab === "circuits") loadCircuitsOnce();
      if (btn.dataset.tab === "constructors") loadConstructorProfilesOnce();
      if (btn.dataset.tab === "current") loadCurrentStandingsOnce();
    });
  });
}

function createOrUpdateChart(currentChart, elementId, labels, values, label, color, onClick) {
  if (currentChart) currentChart.destroy();
  const ctx = document.getElementById(elementId);
  const chart = new Chart(ctx, {
    type: "bar",
    data: {
      labels,
      datasets: [{ label, data: values, backgroundColor: color }]
    },
    options: {
      responsive: true,
      onClick: onClick || undefined,
      plugins: { legend: { display: false } },
      scales: {
        x: { ticks: { color: "#9da7b3" }, grid: { color: "#30363d" } },
        y: { ticks: { color: "#9da7b3" }, grid: { color: "#30363d" } }
      }
    }
  });
  return chart;
}

function renderWinnersTable(rows, season) {
  const tbody = document.querySelector("#winnersTable tbody");
  tbody.innerHTML = "";
  rows.forEach((row) => {
    const tr = document.createElement("tr");
    tr.className = "click-row";
    tr.dataset.raceId = row.race_id;
    tr.dataset.season = season;
    tr.innerHTML = `
      <td>${row.round}</td>
      <td>${row.race_name}</td>
      <td><button type="button" class="link js-driver" data-driver-id="${row.winner_driver_id}">${row.winner_name}</button></td>
      <td>${constructorLink(row.winner_constructor_id, row.constructor_name)}</td>
    `;
    tr.addEventListener("click", (e) => {
      const dbtn = e.target.closest(".js-driver");
      if (dbtn) {
        e.stopPropagation();
        const id = Number(dbtn.dataset.driverId);
        if (id) openDriverModal(id, dbtn.textContent.trim());
        return;
      }
      const cbtn = e.target.closest(".js-constructor");
      if (cbtn) {
        e.stopPropagation();
        const cid = Number(cbtn.dataset.constructorId);
        if (cid) openConstructorModal(cid, cbtn.textContent.trim());
        return;
      }
      openRaceModal(season, row.race_id, row.race_name);
    });
    tbody.appendChild(tr);
  });
}

async function loadOverview(season) {
  const [drivers, constructors, winners] = await Promise.all([
    getJson(`/api/driver-standings?season=${season}`),
    getJson(`/api/constructor-standings?season=${season}`),
    getJson(`/api/race-winners?season=${season}`)
  ]);

  driverIdsForChart = drivers.map((d) => d.driver_id);

  driversChart = createOrUpdateChart(
    driversChart,
    "driversChart",
    drivers.slice(0, 10).map((d) => d.driver_name),
    drivers.slice(0, 10).map((d) => Number(d.points)),
    "Points",
    "#e10600",
    (_evt, elements) => {
      if (!elements.length) return;
      const idx = elements[0].index;
      const id = driverIdsForChart[idx];
      const name = drivers[idx]?.driver_name;
      if (id) openDriverModal(id, name);
    }
  );

  constructorIdsForChart = constructors.map((c) => c.constructor_id);

  constructorsChart = createOrUpdateChart(
    constructorsChart,
    "constructorsChart",
    constructors.map((c) => c.constructor_name),
    constructors.map((c) => Number(c.points)),
    "Points",
    "#3fb950",
    (_evt, elements) => {
      if (!elements.length) return;
      const idx = elements[0].index;
      const id = constructorIdsForChart[idx];
      const name = constructors[idx]?.constructor_name;
      if (id) openConstructorModal(id, name);
    }
  );

  renderWinnersTable(winners, season);
}

function driverLink(driverId, name) {
  return `<button type="button" class="link js-driver" data-driver-id="${driverId}">${name}</button>`;
}

function constructorLink(constructorId, name) {
  if (constructorId == null || constructorId === "") return name ?? "—";
  return `<button type="button" class="link js-constructor" data-constructor-id="${constructorId}">${name ?? "—"}</button>`;
}

async function loadSeasonGold(season) {
  const [dss, css, sched, teams] = await Promise.all([
    getJson(`/api/gold/driver-season-stats?season=${season}`).catch(e => { console.error('driver-season-stats failed:', e); return []; }),
    getJson(`/api/gold/constructor-season-stats?season=${season}`).catch(e => { console.error('constructor-season-stats failed:', e); return []; }),
    getJson(`/api/gold/season-schedule?season=${season}`).catch(e => { console.error('season-schedule failed:', e); return []; }),
    getJson(`/api/gold/constructors-in-season?season=${season}`).catch(e => { console.error('constructors-in-season failed:', e); return []; })
  ]);

  const dBody = document.querySelector("#driverSeasonTable tbody");
  dBody.innerHTML = "";
  dss.forEach((r) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${driverLink(r.driver_id, r.full_name)}</td>
      <td>${constructorLink(r.last_constructor_id, r.constructor_name)}</td>
      <td>${r.races_entered}</td>
      <td>${r.wins}</td>
      <td>${r.podiums}</td>
      <td>${r.poles}</td>
      <td>${r.dnfs}</td>
      <td>${fmtNum(r.points_scored, 1)}</td>
      <td>${fmtNum(r.avg_finish_position, 1)}</td>
      <td>${fmtNum(r.avg_grid_position, 1)}</td>
      <td>${r.fastest_laps}</td>
      <td>${r.championship_position ?? "—"}</td>
      <td>${fmtNum(r.championship_points, 1)}</td>
    `;
    dBody.appendChild(tr);
  });

  const cBody = document.querySelector("#constructorSeasonTable tbody");
  cBody.innerHTML = "";
  css.forEach((r) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${constructorLink(r.constructor_id, r.constructor_name)}</td>
      <td>${r.races_entered}</td>
      <td>${r.wins}</td>
      <td>${r.podiums}</td>
      <td>${r.poles}</td>
      <td>${r.dnfs}</td>
      <td>${fmtNum(r.points_scored, 1)}</td>
      <td>${r.drivers_used}</td>
      <td>${r.championship_position ?? "—"}</td>
      <td>${fmtNum(r.championship_points, 1)}</td>
    `;
    cBody.appendChild(tr);
  });

  const sBody = document.querySelector("#scheduleTable tbody");
  sBody.innerHTML = "";
  sched.forEach((r) => {
    const tr = document.createElement("tr");
    tr.className = "click-row";
    tr.dataset.raceId = r.race_id;
    tr.innerHTML = `
      <td>${r.round}</td>
      <td>${r.race_name}</td>
      <td>${r.circuit_name ?? "—"}</td>
      <td>${r.race_date ?? "—"}</td>
      <td>${r.race_status}</td>
      <td>${r.winner_name ?? "—"}</td>
      <td>${r.is_sprint_weekend ? "Yes" : "No"}</td>
    `;
    tr.addEventListener("click", () => openRaceModal(season, r.race_id, r.race_name));
    sBody.appendChild(tr);
  });

  const h2hSel = document.getElementById("h2hConstructor");
  const currentVal = h2hSel.value;
  h2hSel.innerHTML = '<option value="">All teams</option>';
  teams.forEach((t) => {
    const opt = document.createElement("option");
    opt.value = t.constructor_id;
    opt.textContent = t.constructor_name;
    h2hSel.appendChild(opt);
  });
  if ([...h2hSel.options].some((o) => o.value === String(currentVal))) {
    h2hSel.value = currentVal;
  }

  await refreshH2h(season);
}

async function refreshH2h(season) {
  const sel = document.getElementById("h2hConstructor");
  const id = sel.value;
  const url = id
    ? `/api/gold/head-to-head?season=${season}&constructor_id=${id}`
    : `/api/gold/head-to-head?season=${season}`;
  const rows = await getJson(url);
  const tbody = document.querySelector("#h2hTable tbody");
  tbody.innerHTML = "";
  rows.forEach((r) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${constructorLink(r.constructor_id, r.constructor_name)}</td>
      <td>${driverLink(r.driver_a_id, r.driver_a_name)}</td>
      <td>${driverLink(r.driver_b_id, r.driver_b_name)}</td>
      <td>${r.races_compared}</td>
      <td>${r.driver_a_finished_ahead_count}</td>
      <td>${r.driver_b_finished_ahead_count}</td>
      <td>${r.quali_races_compared}</td>
      <td>${r.driver_a_quali_ahead_count}</td>
      <td>${r.driver_b_quali_ahead_count}</td>
      <td>${fmtNum(r.driver_a_team_points, 1)}</td>
      <td>${fmtNum(r.driver_b_team_points, 1)}</td>
    `;
    tbody.appendChild(tr);
  });
}

async function loadCircuitsOnce() {
  if (state.circuitsLoaded) return;
  const rows = await getJson("/api/gold/circuit-stats");
  const tbody = document.querySelector("#circuitTable tbody");
  tbody.innerHTML = "";
  rows.forEach((r) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${r.circuit_name}</td>
      <td>${r.country ?? "—"}</td>
      <td>${r.total_races_held}</td>
      <td>${r.first_race_year ?? "—"}</td>
      <td>${r.last_race_year ?? "—"}</td>
      <td>${r.most_wins_driver ?? "—"}</td>
      <td>${r.most_wins_count ?? "—"}</td>
      <td>${fmtNum(r.avg_pit_stops_per_race, 2)}</td>
      <td>${r.avg_lap_time_ms != null ? Math.round(r.avg_lap_time_ms) : "—"}</td>
    `;
    tbody.appendChild(tr);
  });
  state.circuitsLoaded = true;
}

let allConstructorProfiles = [];

async function loadConstructorProfilesOnce() {
  if (state.constructorProfilesLoaded) return;
  allConstructorProfiles = await getJson("/api/gold/constructor-profile");
  renderConstructorProfiles(allConstructorProfiles);
  state.constructorProfilesLoaded = true;
}

function renderConstructorProfiles(rows) {
  const tbody = document.querySelector("#constructorProfileTable tbody");
  tbody.innerHTML = "";
  rows.forEach((r) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${constructorLink(r.constructor_id, r.name)}</td>
      <td>${r.nationality ?? "—"}</td>
      <td>${r.seasons_raced ?? "—"}</td>
      <td>${r.total_race_entries ?? "—"}</td>
      <td>${r.total_wins ?? "—"}</td>
      <td>${r.total_podiums ?? "—"}</td>
      <td>${r.total_poles ?? "—"}</td>
      <td>${r.total_fastest_laps ?? "—"}</td>
      <td>${fmtNum(r.total_career_points, 1)}</td>
      <td>${r.total_drivers_fielded ?? "—"}</td>
    `;
    tbody.appendChild(tr);
  });
}

async function loadCurrentStandingsOnce() {
  if (state.currentLoaded) return;
  const data = await getJson("/api/gold/standings-current");
  const meta = document.getElementById("currentMeta");
  if (!data.last_race) {
    meta.textContent = "No standings data.";
    state.currentLoaded = true;
    return;
  }
  meta.textContent = `Season ${data.season} · After round ${data.last_race.round}: ${data.last_race.race_name} (${data.last_race.race_date})`;

  const dBody = document.querySelector("#currentDriversTable tbody");
  dBody.innerHTML = "";
  data.drivers.forEach((r) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${r.position}</td>
      <td>${driverLink(r.driver_id, r.full_name)}</td>
      <td>${constructorLink(r.constructor_id, r.constructor_name)}</td>
      <td>${fmtNum(r.points, 1)}</td>
      <td>${r.wins ?? "—"}</td>
    `;
    dBody.appendChild(tr);
  });

  const cBody = document.querySelector("#currentConstructorsTable tbody");
  cBody.innerHTML = "";
  data.constructors.forEach((r) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${r.standing_position}</td>
      <td>${constructorLink(r.constructor_id, r.constructor_name)}</td>
      <td>${fmtNum(r.points, 1)}</td>
      <td>${r.wins ?? "—"}</td>
    `;
    cBody.appendChild(tr);
  });
  state.currentLoaded = true;
}

function openModal(title, html) {
  document.getElementById("modalTitle").textContent = title;
  document.getElementById("modalBody").innerHTML = html;
  document.getElementById("modal").hidden = false;
  document.body.style.overflow = "hidden";
}

function closeModal() {
  document.getElementById("modal").hidden = true;
  document.getElementById("modalBody").innerHTML = "";
  document.body.style.overflow = "";
}

function bindModalClose() {
  document.getElementById("modalClose").addEventListener("click", closeModal);
  document.getElementById("modalBackdrop").addEventListener("click", closeModal);
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && !document.getElementById("modal").hidden) closeModal();
  });
}

function bindDelegatedClicks() {
  document.body.addEventListener("click", (e) => {
    const cbtn = e.target.closest(".js-constructor");
    if (cbtn) {
      e.preventDefault();
      const cid = Number(cbtn.dataset.constructorId);
      if (cid) openConstructorModal(cid, cbtn.textContent.trim());
      return;
    }
    const btn = e.target.closest(".js-driver");
    if (!btn) return;
    e.preventDefault();
    const id = Number(btn.dataset.driverId);
    const label = btn.textContent.trim();
    if (id) openDriverModal(id, label);
  });
}

async function openDriverModal(driverId, name) {
  const [career, history] = await Promise.all([
    getJson(`/api/gold/driver-career-stats?driver_id=${encodeURIComponent(driverId)}`),
    getJson(`/api/gold/driver-season-history?driver_id=${encodeURIComponent(driverId)}`)
  ]);
  let c = Array.isArray(career) && career.length ? career[0] : null;
  if (!c || (c.total_races == null && !c.career_start_year)) {
    c = deriveDriverCareerFromHistory(history, name);
  }
  const overview = statGrid([
    ["Nationality", c.nationality ?? "—"],
    ["Career", `${c.career_start_year ?? "—"} – ${c.career_end_year ?? "—"}`],
    ["Seasons active", c.seasons_active ?? "—"],
    ["Races", c.total_races ?? "—"],
    ["Wins", c.total_wins ?? "—"],
    ["Podiums", c.total_podiums ?? "—"],
    ["Poles", c.total_poles ?? "—"],
    ["DNFs", c.total_dnfs ?? "—"],
    ["Points", fmtNum(c.total_points, 1)],
    ["Win rate", c.win_rate_pct != null ? `${fmtNum(c.win_rate_pct, 2)}%` : "—"],
    ["Podium rate", c.podium_rate_pct != null ? `${fmtNum(c.podium_rate_pct, 2)}%` : "—"],
    ["Avg finish", fmtNum(c.avg_finish_position, 2)],
    ["Championships", c.championships ?? "—"]
  ]);
  const dl = `
    <p class="meta">Career summary <span class="tag">gold.driver_career_stats</span></p>
    ${overview}
    <h3 class="modal-section-title">By season <span class="tag">gold.driver_season_stats</span></h3>
    <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th>Year</th><th>Team</th><th>R</th><th>W</th><th>Pod</th><th>Pole</th><th>DNF</th><th>Pts</th><th>Ch</th>
          </tr>
        </thead>
        <tbody>
          ${history
            .map(
              (r) => `
            <tr>
              <td>${r.season_year}</td>
              <td>${constructorLink(r.last_constructor_id, r.constructor_name)}</td>
              <td>${r.races_entered}</td>
              <td>${r.wins}</td>
              <td>${r.podiums}</td>
              <td>${r.poles}</td>
              <td>${r.dnfs}</td>
              <td>${fmtNum(r.points_scored, 1)}</td>
              <td>${r.championship_position ?? "—"}</td>
            </tr>`
            )
            .join("")}
        </tbody>
      </table>
    </div>
  `;
  openModal(name || c.full_name || "Driver", dl);
}

async function openConstructorModal(constructorId, name) {
  const data = await getJson(
    `/api/gold/constructor-detail?constructor_id=${encodeURIComponent(constructorId)}`
  );
  const p = data.profile || {};
  const overview = statGrid([
    ["Nationality", p.nationality ?? "—"],
    ["First / last season", `${p.first_season_year ?? "—"} – ${p.last_season_year ?? "—"}`],
    ["Seasons raced", p.seasons_raced ?? "—"],
    ["Race entries", p.total_race_entries ?? "—"],
    ["Wins", p.total_wins ?? "—"],
    ["Podiums", p.total_podiums ?? "—"],
    ["Poles", p.total_poles ?? "—"],
    ["Fastest laps", p.total_fastest_laps ?? "—"],
    ["Career points", fmtNum(p.total_career_points, 1)],
    ["Drivers fielded", p.total_drivers_fielded ?? "—"],
    ["Wikipedia", p.wikipedia_url ? `<a href="${p.wikipedia_url}" target="_blank" rel="noopener">link</a>` : "—"]
  ]);
  const seasonRows = (data.seasons || [])
    .map(
      (r) => `
    <tr>
      <td>${r.season_year}</td>
      <td>${r.races_entered}</td>
      <td>${r.wins}</td>
      <td>${r.podiums}</td>
      <td>${r.poles}</td>
      <td>${r.dnfs}</td>
      <td>${fmtNum(r.points_scored, 1)}</td>
      <td>${r.drivers_used}</td>
      <td>${r.championship_position ?? "—"}</td>
    </tr>`
    )
    .join("");
  const html = `
    <p class="meta">Aligned with <span class="tag">gold.constructor_profile</span> and <span class="tag">gold.constructor_season_stats</span></p>
    ${overview}
    <h3 class="modal-section-title">By season</h3>
    <div class="table-wrap"><table><thead><tr>
      <th>Year</th><th>Races</th><th>W</th><th>Pod</th><th>Pole</th><th>DNF</th><th>Pts</th><th>Drivers</th><th>Ch</th>
    </tr></thead><tbody>${seasonRows}</tbody></table></div>
  `;
  openModal(name || p.name || "Constructor", html);
}

async function openRaceModal(season, raceId, raceName) {
  const [quali, results] = await Promise.all([
    getJson(`/api/gold/race-qualifying?race_id=${raceId}`),
    getJson(`/api/gold/race-results-detail?season=${season}&race_id=${raceId}`)
  ]);
  const qRows = quali
    .map(
      (r) => `
    <tr>
      <td>${r.qualifying_position}</td>
      <td>${driverLink(r.driver_id, r.driver_name)}</td>
      <td>${constructorLink(r.constructor_id, r.constructor_name)}</td>
      <td>${r.q1_time ?? "—"}</td>
      <td>${r.q2_time ?? "—"}</td>
      <td>${r.q3_time ?? "—"}</td>
      <td>${r.grid_position ?? "—"}</td>
    </tr>`
    )
    .join("");
  const rRows = results
    .map(
      (r) => `
    <tr>
      <td>${r.finish_position ?? "—"}</td>
      <td>${driverLink(r.driver_id, r.driver_name)}</td>
      <td>${constructorLink(r.constructor_id, r.constructor_name)}</td>
      <td>${r.grid_position ?? "—"}</td>
      <td>${fmtNum(r.points, 1)}</td>
      <td>${r.laps_completed ?? "—"}</td>
      <td>${r.is_dnf ? "DNF" : "OK"}</td>
      <td>${r.status_description ?? "—"}</td>
    </tr>`
    )
    .join("");
  const html = `
    <p class="meta">Season ${season} · <span class="tag">gold.race_qualifying</span> · <span class="tag">gold.race_results_detail</span></p>
    <h3 class="modal-section-title">Qualifying</h3>
    <div class="table-wrap"><table><thead><tr>
      <th>Pos</th><th>Driver</th><th>Constructor</th><th>Q1</th><th>Q2</th><th>Q3</th><th>Grid</th>
    </tr></thead><tbody>${qRows}</tbody></table></div>
    <h3 class="modal-section-title">Race results</h3>
    <div class="table-wrap"><table><thead><tr>
      <th>Fin</th><th>Driver</th><th>Constructor</th><th>Grid</th><th>Pts</th><th>Laps</th><th>Fin?</th><th>Status</th>
    </tr></thead><tbody>${rRows}</tbody></table></div>
  `;
  openModal(raceName || `Race ${raceId}`, html);
}

async function init() {
  setTabs();
  bindModalClose();
  bindDelegatedClicks();

  const seasonSelect = document.getElementById("seasonSelect");
  const seasons = await getJson("/api/seasons");
  seasons.forEach((season) => {
    const option = document.createElement("option");
    option.value = season;
    option.textContent = season;
    seasonSelect.appendChild(option);
  });
  const defaultSeason = String(seasons[0]);
  seasonSelect.value = defaultSeason;

  document.getElementById("h2hConstructor").addEventListener("change", () => {
    refreshH2h(seasonSelect.value).catch(console.error);
  });

  document.getElementById("constructorSearch").addEventListener("input", (e) => {
    const q = e.target.value.trim().toLowerCase();
    if (!state.constructorProfilesLoaded) return;
    const filtered = allConstructorProfiles.filter((r) => r.name.toLowerCase().includes(q));
    renderConstructorProfiles(filtered);
  });

  const load = async () => {
    const s = seasonSelect.value;
    await Promise.all([loadOverview(s), loadSeasonGold(s)]);
  };

  seasonSelect.addEventListener("change", () => load().catch(console.error));
  await load();
}

init().catch((error) => {
  console.error(error);
  alert("Could not load dashboard: " + error.message);
});
