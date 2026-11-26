"""Figures and tables for the algorithm comparison (quick run)."""
import os
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy import stats

RUNS, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)

ORDER = ["beam_search", "multi_start", "block_building", "brkga", "single_start", "wall_building"]
LABEL = {"beam_search": "Beam Search", "multi_start": "Multi-Start EP", "block_building": "Block-Building",
         "brkga": "BRKGA", "single_start": "Single-Start EP", "wall_building": "Wall-Building (manual-style)"}
COLOR = {"beam_search": "#2a78d6", "multi_start": "#eb6834", "block_building": "#1baf7a",
         "brkga": "#eda100", "single_start": "#e87ba4", "wall_building": "#6250d6"}
INK, INK2, GRID, SURF = "#262624", "#5e5d59", "#e6e5e0", "#fcfcfb"

plt.rcParams.update({
    "font.family": "DejaVu Sans", "font.size": 10, "axes.edgecolor": GRID, "axes.labelcolor": INK2,
    "xtick.color": INK2, "ytick.color": INK2, "axes.titlecolor": INK, "axes.titleweight": "bold",
    "axes.titlesize": 12, "axes.titlelocation": "left", "figure.facecolor": "white", "axes.facecolor": "white",
    "axes.spines.top": False, "axes.spines.right": False, "legend.frameon": False,
})

r = pd.read_csv(RUNS)
r["family"] = np.where(r.group.str.startswith("MD"), "MD-" + r.group.str[-2:],
                       r.group.str.replace(r"\d.*", "", regex=True))
med = (r.groupby(["case_id", "family", "group", "algorithm"])
       .agg(util=("utilization_pct", "median"), inv=("priority_inversion_pct", "median"),
            t=("runtime_s", "median"), placed=("boxes_placed", "median"), total=("boxes_total", "first"),
            ref=("reference_ratio_pct", "first"))
       .reset_index())

FAM = ["BR", "WT", "MD-D2", "MD-D5", "REAL"]
FAM_LABEL = {"BR": "BR\n(70 cases)", "WT": "WT\n(70)", "MD-D2": "MD 2 stops\n(21)", "MD-D5": "MD 5 stops\n(21)",
             "REAL": "Real cases\n(13)"}


def save(fig, name):
    fig.savefig(f"{OUT}/{name}.png", dpi=220, bbox_inches="tight")
    fig.savefig(f"{OUT}/{name}.pdf", bbox_inches="tight")
    plt.close(fig)


# ---- Table 1 + Figure 1: mean utilisation per family
t1 = med.pivot_table(index="family", columns="algorithm", values="util", aggfunc="mean").loc[FAM + ["SCN"], ORDER]
t1.round(2).rename(columns=LABEL).to_csv(f"{OUT}/table1_utilization_by_family.csv")
fig, ax = plt.subplots(figsize=(9, 4.2))
w = 0.135
x = np.arange(len(FAM))
for i, a in enumerate(ORDER):
    vals = t1.loc[FAM, a].values
    bars = ax.bar(x + (i - (len(ORDER) - 1) / 2) * w, vals, w - 0.02, color=COLOR[a], label=LABEL[a], zorder=3)
    for b, v in zip(bars, vals):
        ax.text(b.get_x() + b.get_width() / 2, v + 0.6, f"{v:.1f}", ha="center", va="bottom", fontsize=6.5,
                color=INK2, rotation=90)
ax.set_xticks(x, [FAM_LABEL[f] for f in FAM])
ax.set_ylabel("Mean volume utilisation (%)")
ax.set_ylim(0, 100)
ax.yaxis.grid(True, color=GRID, zorder=0)
ax.set_title("Mean volume utilisation by case family (2 s budget)")
ax.legend(ncol=3, loc="upper center", bbox_to_anchor=(0.5, -0.2), fontsize=8.5)
save(fig, "fig1_utilization_by_family")

# ---- Figure 2: quality vs time (benchmark families only)
bench = med[med.family.isin(["BR", "WT", "MD-D2", "MD-D5"])]
qt = bench.groupby("algorithm").agg(util=("util", "mean"), t=("t", "median"))
fig, ax = plt.subplots(figsize=(6.4, 4))
for a in ORDER:
    ax.scatter(qt.loc[a, "t"], qt.loc[a, "util"], s=90, color=COLOR[a], edgecolor=SURF, linewidth=2, zorder=3)
    ax.annotate(LABEL[a], (qt.loc[a, "t"], qt.loc[a, "util"]), xytext=(8, 4), textcoords="offset points",
                fontsize=9, color=INK)
ax.set_xscale("log")
ax.set_xlim(0.001, 6)
ax.set_xlabel("Median run time per case (s, log scale)")
ax.set_ylabel("Mean utilisation, 182 benchmark cases (%)")
ax.grid(True, color=GRID, zorder=0)
ax.set_title("Plan quality against computation time")
save(fig, "fig2_quality_vs_time")

# ---- Figure 3: BR heterogeneity (3 -> 20 box types)
types = {"BR1": 3, "BR2": 5, "BR3": 8, "BR4": 10, "BR5": 12, "BR6": 15, "BR7": 20}
br = med[med.family == "BR"].pivot_table(index="group", columns="algorithm", values="util", aggfunc="mean")
fig, ax = plt.subplots(figsize=(7.4, 4))
xs = list(range(len(br.index)))
ends = sorted(((br[a].values[-1], a) for a in ORDER), reverse=True)
label_y, last = {}, None
for v, a in ends:  # dodge end labels so they never collide
    y = v if last is None else min(v, last - 0.55)
    label_y[a] = y
    last = y
for a in ORDER:
    ax.plot(xs, br[a].values, color=COLOR[a], linewidth=2, marker="o", markersize=5, zorder=3)
    ax.annotate(LABEL[a], (xs[-1], br[a].values[-1]), xytext=(xs[-1] + 0.25, label_y[a]), textcoords="data",
                va="center", fontsize=8.5, color=INK)
ax.set_xticks(xs, [f"{g}\n{types[g]} types" for g in br.index], fontsize=8)
ax.set_xlim(-0.3, len(xs) + 1.3)
ax.set_ylabel("Mean utilisation (%)")
ax.grid(True, axis="y", color=GRID, zorder=0)
ax.set_title("BR classes: utilisation as box variety grows")
save(fig, "fig3_br_heterogeneity")

# ---- Figure 4: unloading-priority inversions on MD
t4 = med[med.family.isin(["MD-D2", "MD-D5"])].pivot_table(index="family", columns="algorithm", values="inv",
                                                            aggfunc="mean").loc[["MD-D2", "MD-D5"], ORDER]
t4.round(2).rename(columns=LABEL).to_csv(f"{OUT}/table4_priority_inversions.csv")
fig, ax = plt.subplots(figsize=(7, 3.6))
x = np.arange(2)
for i, a in enumerate(ORDER):
    vals = t4[a].values
    bars = ax.bar(x + (i - (len(ORDER) - 1) / 2) * w, vals, w - 0.02, color=COLOR[a], label=LABEL[a], zorder=3)
    for b, v in zip(bars, vals):
        ax.text(b.get_x() + b.get_width() / 2, v + 0.3, f"{v:.1f}", ha="center", va="bottom", fontsize=7,
                color=INK2)
ax.set_xticks(x, ["MD, 2 stops", "MD, 5 stops"])
ax.set_ylabel("Inverted pairs (% of pairs)")
ax.yaxis.grid(True, color=GRID, zorder=0)
ax.set_title("Unloading-priority inversions (lower is better)")
ax.legend(ncol=3, loc="upper center", bbox_to_anchor=(0.5, -0.12), fontsize=8)
save(fig, "fig4_priority_inversions")

# ---- Figure 5: MAX-E / MAX-D against the published MAXCUBE plans
mx = med[med.case_id.isin(["MAX-E", "MAX-D"])].pivot_table(index="case_id", columns="algorithm", values="util")
refs = med[med.case_id.isin(["MAX-E", "MAX-D"])].groupby("case_id").ref.first()
fig, axes = plt.subplots(1, 2, figsize=(9.6, 3.4), sharex=True, sharey=True)
fig.subplots_adjust(wspace=0.12)
for ax, cid, title in zip(axes, ["MAX-E", "MAX-D"], ["MAX-E: office furniture, 40GP", "MAX-D: TVs, custom 40HQ"]):
    vals = [mx.loc[cid, a] for a in ORDER]
    y = np.arange(len(ORDER))[::-1]
    # dot plot: a zoomed axis is honest for dots, not for bars
    ax.scatter(vals, y, s=80, color=[COLOR[a] for a in ORDER], edgecolor=SURF, linewidth=2, zorder=4)
    for yy, v in zip(y, vals):
        right = v >= refs[cid]  # keep every label clear of the reference line
        ax.text(v + (0.7 if right else -0.7), yy, f"{v:.2f}%", va="center", ha="left" if right else "right",
                fontsize=8, color=INK2)
    ax.axvline(refs[cid], color=INK, linewidth=1.5, linestyle="--", zorder=3)
    ax.text(refs[cid] + 0.15, len(ORDER) - 0.4, f"MAXCUBE {refs[cid]:.2f}%", fontsize=8, color=INK)
    ax.set_yticks(y, [LABEL[a] for a in ORDER], fontsize=8.5)
    ax.tick_params(axis="y", length=0)
    ax.set_xlim(min(70, min(vals) - 3), 99)
    ax.set_ylim(-0.6, len(ORDER) - 0.1)
    ax.grid(True, color=GRID, zorder=0)
    ax.set_title(title, fontsize=10.5)
axes[0].set_xlabel("Volume utilisation (%)")
axes[1].set_xlabel("Volume utilisation (%)")
save(fig, "fig5_real_vs_maxcube")

# ---- Statistics
W = bench.pivot_table(index="case_id", columns="algorithm", values="util")[ORDER]
fr = stats.friedmanchisquare(*[W[a] for a in ORDER])
ranks = W.rank(axis=1, ascending=False).mean()
pairs = [("beam_search", a) for a in ORDER[1:]] + [("multi_start", "block_building"), ("multi_start", "brkga"),
                                                   ("block_building", "single_start"), ("multi_start", "single_start"),
                                                   ("block_building", "wall_building")]
rows = []
for a, b in pairs:
    d = W[a] - W[b]
    rows.append([LABEL[a], LABEL[b], d.mean(), int((d > 1e-9).sum()), int((d < -1e-9).sum()), int((d.abs() <= 1e-9).sum()),
                 stats.wilcoxon(W[a], W[b]).pvalue])
st = pd.DataFrame(rows, columns=["A", "B", "mean_diff_pp", "A_better", "B_better", "ties", "p_value"])
order = np.argsort(st.p_value.values)
m = len(st)
holm = np.empty(m)
running = 0.0
for k, i in enumerate(order):
    running = max(running, (m - k) * st.p_value.values[i])
    holm[i] = min(1.0, running)
st["p_holm"] = holm
st.to_csv(f"{OUT}/table2_wilcoxon_pairs.csv", index=False)
rk = pd.DataFrame({"algorithm": [LABEL[a] for a in ORDER], "mean_rank": [ranks[a] for a in ORDER],
                   "mean_util_pct": [W[a].mean() for a in ORDER],
                   "median_time_s": [bench[bench.algorithm == a].t.median() for a in ORDER]})
rk.to_csv(f"{OUT}/table3_ranking.csv", index=False)
with open(f"{OUT}/statistics.txt", "w") as fh:
    fh.write(f"Benchmark cases: {len(W)} (BR 70, WT 70, MD 42)\n")
    fh.write(f"Friedman chi2 = {fr.statistic:.1f}, df = {len(ORDER) - 1}, p = {fr.pvalue:.2e}\n\n")
    fh.write(rk.round(3).to_string(index=False) + "\n\n")
    fh.write(st.round(4).to_string(index=False) + "\n")
print(open(f"{OUT}/statistics.txt").read())
