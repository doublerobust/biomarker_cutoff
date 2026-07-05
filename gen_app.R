library(jsonlite)

d <- readRDS("plot_data.rds")
by_n <- d$by_n

auc_groups <- unique(by_n$auc_group)
output <- list()
for (ag in auc_groups) {
  scens <- unique(by_n$combo_label[by_n$auc_group == ag])
  sl <- list()
  for (sc in scens) {
    nd <- by_n[by_n$combo_label == sc, ]
    sl[[sc]] <- list(
      orr_label = nd$orr_label[1],
      n = nd$n,
      success = nd$success_rate
    )
  }
  output[[ag]] <- sl
}

json_str <- toJSON(output, auto_unbox = TRUE, pretty = FALSE)

template_before <- '
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Biomarker Cutoff Explorer</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.7/dist/chart.umd.min.js"></script>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  background: #f8fafc; color: #1e293b; padding: 24px;
}
.container { max-width: 1000px; margin: 0 auto; }
h1 { font-size: 24px; font-weight: 600; margin-bottom: 4px; }
.subtitle { color: #64748b; font-size: 14px; margin-bottom: 20px; }
.tabs { display: flex; gap: 4px; margin-bottom: 20px; flex-wrap: wrap; }
.tab-btn {
  padding: 10px 22px; border: none; border-radius: 8px 8px 0 0;
  font-size: 14px; font-weight: 500; cursor: pointer;
  background: #e2e8f0; color: #64748b; transition: all 0.3s ease;
}
.tab-btn:hover { background: #cbd5e1; color: #334155; }
.tab-btn.active {
  background: #fff; color: #1e40af; box-shadow: 0 -2px 6px rgba(0,0,0,0.06);
  position: relative;
}
.tab-btn.active::after {
  content: ""; position: absolute; bottom: -2px; left: 0; right: 0;
  height: 3px; background: #2563eb; border-radius: 0 0 2px 2px;
}
.tab-btn .auc-badge {
  display: inline-block; background: #dbeafe; color: #1e40af;
  border-radius: 4px; padding: 1px 7px; font-size: 11px; font-weight: 600;
  margin-left: 6px;
}
.tab-btn.active .auc-badge { background: #2563eb; color: #fff; }
.panel {
  display: none; background: #fff; border-radius: 0 12px 12px 12px;
  padding: 24px; box-shadow: 0 1px 4px rgba(0,0,0,0.06);
  animation: fadeIn 0.4s ease;
}
.panel.active { display: block; }
@keyframes fadeIn {
  from { opacity: 0; transform: translateY(8px); }
  to { opacity: 1; transform: translateY(0); }
}
.panel-header { margin-bottom: 16px; }
.panel-header h2 { font-size: 18px; font-weight: 600; }
.panel-header p { font-size: 13px; color: #64748b; margin-top: 4px; }
.chart-box {
  background: #fafbfc; border: 1px solid #e2e8f0; border-radius: 10px; padding: 16px;
}
.chart-box h3 { font-size: 14px; font-weight: 600; margin-bottom: 4px; color: #334155; }
.chart-box .chart-desc { font-size: 12px; color: #94a3b8; margin-bottom: 10px; }
.chart-box canvas { width: 100% !important; height: 380px !important; }
.insight-box {
  margin-top: 16px; background: #f0f7ff; border-left: 4px solid #2563eb;
  border-radius: 6px; padding: 12px 16px; font-size: 13px; line-height: 1.5;
}
.insight-box strong { color: #1e40af; }
.sim-badge {
  display: inline-block; background: #f1f5f9; color: #475569;
  border-radius: 4px; padding: 2px 8px; font-size: 11px; margin-left: 8px;
}
table { width: 100%; border-collapse: collapse; margin-top: 12px; font-size: 13px; }
th { background: #f0f7ff; text-align: left; padding: 6px 10px; color: #1e40af; font-weight: 600; }
td { padding: 5px 10px; border-bottom: 1px solid #e2e8f0; }
tr:last-child td { border-bottom: none; }
.calculator {
  background: #fff; border: 1px solid #dbe3ef; border-radius: 8px;
  padding: 16px; margin-bottom: 20px; box-shadow: 0 1px 4px rgba(0,0,0,0.04);
}
.calculator h2 { font-size: 16px; margin-bottom: 12px; }
.calc-grid { display: grid; grid-template-columns: repeat(4, minmax(120px, 1fr)); gap: 12px; align-items: end; }
.calc-field label { display: block; font-size: 12px; color: #64748b; margin-bottom: 4px; }
.calc-field input {
  width: 100%; border: 1px solid #cbd5e1; border-radius: 6px;
  padding: 8px 10px; font-size: 14px; color: #1e293b; background: #fff;
}
.calc-field button {
  width: 100%; border: none; border-radius: 6px; padding: 9px 12px;
  background: #2563eb; color: #fff; font-weight: 600; cursor: pointer;
}
.calc-result { margin-top: 12px; font-size: 14px; color: #1e293b; }
.calc-result strong { color: #1e40af; }
.calc-note { margin-top: 6px; font-size: 12px; color: #64748b; }
@media (max-width: 720px) {
  .calc-grid { grid-template-columns: 1fr 1fr; }
}
@media (max-width: 460px) {
  .calc-grid { grid-template-columns: 1fr; }
}
</style>
</head>
<body>
<div class="container">
  <h1>Biomarker Cutoff Precision</h1>
  <p class="subtitle">
    N = 40&ndash;240 &middot; <strong>50000 sims per scenario</strong> &middot; 4 AUC levels &times; 3 ORR levels &times; 14 N values &middot; min_enriched=5, min_fraction=0.20
  </p>
  <div class="calculator">
    <h2>Sample size calculator</h2>
    <div class="calc-grid">
      <div class="calc-field">
        <label for="calcAuc">AUC</label>
        <input id="calcAuc" type="number" min="0.60" max="0.75" step="0.01" value="0.65">
      </div>
      <div class="calc-field">
        <label for="calcOrr">All-comer ORR (%)</label>
        <input id="calcOrr" type="number" min="10" max="25" step="1" value="15">
      </div>
      <div class="calc-field">
        <label for="calcSuccess">Target success (%)</label>
        <input id="calcSuccess" type="number" min="1" max="99" step="1" value="60">
      </div>
      <div class="calc-field">
        <button type="button" onclick="runCalculator()">Calculate</button>
      </div>
    </div>
    <div class="calc-result" id="calcResult"></div>
    <div class="calc-note">Valid within the simulated grid: AUC 0.60-0.75, ORR 10%-25%, N 40-240. Success means estimated cutoff within &plusmn;10 biomarker points.</div>
  </div>
  <div class="tabs" id="tabContainer"></div>
  <div id="panelContainer"></div>
</div>
<script>
'

template_after <- '

const COLORS = ["#2563eb", "#d97706", "#16a34a"];
const DASHES = [[], [6,3], [2,4]];
const AUC_ORDER = ["0.60", "0.65", "0.70", "0.75"];
const AUC_DESC = { "0.60": "weak", "0.65": "moderate", "0.70": "good", "0.75": "strong" };
let charts = {};

function asNumber(x) { return Number.parseFloat(x); }

function scenarioPoints() {
  return AUC_ORDER.flatMap(a =>
    Object.keys(RAW[a]).map(k => ({
      auc: asNumber(a),
      orr: asNumber(RAW[a][k].orr_label.replace("%", "")) / 100,
      n: RAW[a][k].n,
      success: RAW[a][k].success.map(v => v / 100)
    }))
  );
}

function interp(xs, ys, x) {
  if (x < xs[0] || x > xs[xs.length - 1]) return NaN;
  for (let i = 1; i < xs.length; i++) {
    if (x <= xs[i]) {
      const t = (x - xs[i - 1]) / (xs[i] - xs[i - 1]);
      return ys[i - 1] + t * (ys[i] - ys[i - 1]);
    }
  }
  return ys[ys.length - 1];
}

function interpolatedCurve(auc, orr) {
  const points = scenarioPoints();
  const aucs = [...new Set(points.map(p => p.auc))].sort((a, b) => a - b);
  const orrs = [...new Set(points.map(p => p.orr))].sort((a, b) => a - b);
  const ns = points[0].n;
  if (auc < aucs[0] || auc > aucs[aucs.length - 1] || orr < orrs[0] || orr > orrs[orrs.length - 1]) return null;

  const success = ns.map((_, ni) => {
    const byAuc = aucs.map(a => {
      const row = orrs.map(o => points.find(p => p.auc === a && p.orr === o).success[ni]);
      return interp(orrs, row, orr);
    });
    return interp(aucs, byAuc, auc);
  });
  for (let i = 1; i < success.length; i++) success[i] = Math.max(success[i], success[i - 1]);
  return { n: ns, success };
}

function neededN(curve, target) {
  if (target <= curve.success[0]) return "<=" + curve.n[0];
  if (target > curve.success[curve.success.length - 1]) return ">" + curve.n[curve.n.length - 1];
  for (let i = 1; i < curve.n.length; i++) {
    if (curve.success[i] >= target) {
      return Math.ceil(interp([curve.success[i - 1], curve.success[i]], [curve.n[i - 1], curve.n[i]], target));
    }
  }
  return ">" + curve.n[curve.n.length - 1];
}

function runCalculator() {
  const auc = asNumber(document.getElementById("calcAuc").value);
  const orr = asNumber(document.getElementById("calcOrr").value) / 100;
  const target = asNumber(document.getElementById("calcSuccess").value) / 100;
  const result = document.getElementById("calcResult");
  const curve = interpolatedCurve(auc, orr);
  if (!curve || Number.isNaN(target) || target <= 0 || target >= 1) {
    result.innerHTML = "Enter values inside the simulated ranges.";
    return;
  }
  const n = neededN(curve, target);
  result.innerHTML = `<strong>Estimated N: ${n}</strong> for AUC ${auc.toFixed(2)}, ORR ${(100 * orr).toFixed(0)}%, ${(100 * target).toFixed(0)}% success`;
}

function buildTabs() {
  const tc = document.getElementById("tabContainer");
  tc.innerHTML = AUC_ORDER.map((a, i) =>
    `<button class="tab-btn${i===0?" active":""}" data-auc="${a}" onclick="switchTab(\'${a}\')">
       AUC = ${a} <span class="auc-badge">${AUC_DESC[a]}</span>
     </button>`
  ).join("");
}

function buildPanels() {
  const pc = document.getElementById("panelContainer");
  pc.innerHTML = AUC_ORDER.map((a) => {
    const scens = Object.keys(RAW[a]);
    const orrs = scens.map(s => RAW[a][s].orr_label).join(", ");
    return `<div class="panel" id="panel-${a}">
      <div class="panel-header">
        <h2>AUC = ${a} &mdash; ${AUC_DESC[a]} discrimination</h2>
        <p>ORR scenarios: ${orrs} <span class="sim-badge">50000 sims each</span></p>
      </div>
      <div class="chart-box">
        <h3>Success rate vs total sample size (N)</h3>
        <div class="chart-desc">At the same N, lower ORR gives lower success rate. Lower ORR needs larger N to reach the same precision.</div>
        <canvas id="chart-${a}"></canvas>
      </div>
      <div class="insight-box" id="insight-${a}"></div>
      <div style="margin-top:12px;font-size:11px;color:#94a3b8;border-top:1px solid #e2e8f0;padding-top:10px;">
        <strong>Success rate</strong> = fraction of simulations where the estimated cutoff is within
        &plusmn;10 biomarker points of the true population cutoff (computed from 200,000 patients
        with continuous response probabilities). A &ldquo;success&rdquo; means your trial&rsquo;s cutoff
        would select a subgroup with similar enrichment to the theoretically optimal threshold.
      </div>
    </div>`;
  }).join("");
}

function renderPanel(auc) {
  const scens = Object.keys(RAW[auc]);
  const labels = RAW[auc][scens[0]].n;

  const datasets = scens.map((s, i) => ({
    label: "ORR " + RAW[auc][s].orr_label,
    data: RAW[auc][s].success,
    borderColor: COLORS[i % COLORS.length],
    backgroundColor: COLORS[i % COLORS.length] + "15",
    borderWidth: 3, pointRadius: 3, pointHoverRadius: 6,
    tension: 0.3, borderDash: DASHES[i % DASHES.length]
  }));

  if (charts[auc]) charts[auc].destroy();
  const ctx = document.getElementById("chart-"+auc).getContext("2d");
  charts[auc] = new Chart(ctx, {
    type: "line",
    data: { labels, datasets },
    options: {
      responsive: true, maintainAspectRatio: false,
      animation: { duration: 500, easing: "easeOutQuart" },
      plugins: {
        legend: { position: "bottom", labels: { boxWidth: 16, padding: 16, font: { size: 13 } } },
        tooltip: {
          callbacks: {
            label: ctx => `${ctx.dataset.label}: ${ctx.parsed.y}% success`
          }
        }
      },
      scales: {
        x: { title: { display: true, text: "Total sample size (N)", font: { size: 13 } }, grid: { color: "#e8e8e8" }, ticks: { stepSize: 20 } },
        y: { title: { display: true, text: "Success rate (%)", font: { size: 13 } }, min: 0, max: 100, grid: { color: "#e8e8e8" } }
      }
    }
  });

  // Build insight table
  const sc0 = RAW[auc][scens[0]], sc1 = RAW[auc][scens[1]], sc2 = RAW[auc][scens[2]];
  const n50_0 = findN(sc0.n, sc0.success, 50);
  const n50_1 = findN(sc1.n, sc1.success, 50);
  const n50_2 = findN(sc2.n, sc2.success, 50);
  const n65_0 = findN(sc0.n, sc0.success, 65);
  const n65_1 = findN(sc1.n, sc1.success, 65);
  const n65_2 = findN(sc2.n, sc2.success, 65);

  document.getElementById("insight-"+auc).innerHTML =
    `<strong>N needed for target success rate:</strong>` +
    `<table>
      <tr><th>ORR</th><th>For 50% success</th><th>For 65% success</th></tr>
      <tr><td>${sc0.orr_label}</td><td><strong>N=${n50_0}</strong></td><td><strong>N=${n65_0}</strong></td></tr>
      <tr><td>${sc1.orr_label}</td><td><strong>N=${n50_1}</strong></td><td><strong>N=${n65_1}</strong></td></tr>
      <tr><td>${sc2.orr_label}</td><td><strong>N=${n50_2}</strong></td><td><strong>N=${n65_2}</strong></td></tr>
    </table>` +
    `<div style="margin-top:8px;font-size:12px;color:#64748b;">` +
    `Lower ORR &rarr; fewer responders at the same N &rarr; worse cutoff precision. ` +
    `Lower ORR trials need larger N to reach the same number of responders.` +
    `</div>`;
}

function findN(ns, succ, target) {
  if (!ns || !succ) return "?";
  for (let i = 0; i < ns.length; i++) {
    if (succ[i] >= target) return ns[i];
  }
  return ">" + ns[ns.length-1];
}

function switchTab(auc) {
  document.querySelectorAll(".tab-btn").forEach(b => b.classList.toggle("active", b.dataset.auc === auc));
  document.querySelectorAll(".panel").forEach(p => p.classList.toggle("active", p.id === "panel-"+auc));
  renderPanel(auc);
}

buildTabs();
buildPanels();
runCalculator();
renderPanel("0.60");
</script>
</body>
</html>'

writeLines(c(template_before, "const RAW = ", json_str, ";", template_after),
           "app.html")
cat("Written app.html\n")
