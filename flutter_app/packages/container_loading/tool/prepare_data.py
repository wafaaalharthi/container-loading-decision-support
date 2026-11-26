"""Convert Sea_Container_Loading_Data.xlsx into the JSON case format read by the Dart engine.

Usage: python3 -I prepare_data.py <workbook.xlsx> <out_dir>
Writes cases_quick.json, cases_full.json and scenarios.json.
"""
import json
import math
import sys
from itertools import permutations

import pandas as pd

WB, OUT = sys.argv[1], sys.argv[2]

# Hapag-Lloyd published equipment profiles (internal L x W x H, door W x H, max payload).
HL_URL = "https://www.hapag-lloyd.com/en/services-information/cargo-fleet/container/"
PROFILES = {
    "20GP": dict(size=[5900, 2352, 2395], door=[2340, 2292], payload=28130, ref=HL_URL + "20-standard.html"),
    "40GP": dict(size=[12032, 2352, 2395], door=[2340, 2292], payload=28750, ref=HL_URL + "40-standard.html"),
    "40HC": dict(size=[12032, 2350, 2700], door=[2340, 2597], payload=28600, ref=HL_URL + "40-standard-high-cube.html"),
}
ALL_ROT = [list(p) for p in permutations(range(3))]


def rd(sheet):
    d = pd.read_excel(WB, sheet_name=sheet, header=3)
    d.columns = [str(c).split("\n")[-1].strip() for c in d.columns]
    return d


def val(x):
    if x is None or (isinstance(x, float) and math.isnan(x)):
        return None
    return x


def flag(x):
    x = val(x)
    return None if x is None else bool(int(x))


def mm(x):
    x = val(x)
    return None if x is None else int(math.floor(float(x) + 0.5))


def rotations_from_upright(flags):
    """flags = (length upright, width upright, height upright). perm[2] is the source axis that becomes vertical."""
    if all(f is None for f in flags):
        allowed = {2}  # documented default: original height stays vertical
    else:
        allowed = {i for i, f in enumerate(flags) if f}
    return [r for r in ALL_ROT if r[2] in allowed]


def profile_for(ctype):
    t = str(ctype)
    if "High Cube" in t or "40HQ" in t or "40HC" in t:
        return "40HC"
    if "40" in t:
        return "40GP"
    if "20" in t:
        return "20GP"
    return None


def build_box(row, rule, fragile_blocks):
    upright = tuple(flag(rule.get(f"{a} upright 1/0")) for a in ("Length", "Width", "Height"))
    pressure = [val(rule.get(f"Pressure, {a} upright (kg/cm²)")) for a in ("length", "width", "height")]
    w = val(row.get("Unit weight (kg)"))
    return {
        "type": row["Box record ID"],
        "qty": int(row["Quantity"]),
        "size": [mm(row["Length (mm)"]), mm(row["Width (mm)"]), mm(row["Height (mm)"])],
        "weight": None if w is None else round(float(w), 4),
        "rotations": rotations_from_upright(upright),
        "floorOnly": flag(rule.get("Floor only 1/0")) is True,
        "stackable": flag(rule.get("Can stack above 1/0")),
        "similarAbove": flag(rule.get("Similar box above 1/0")),
        "differentAbove": flag(rule.get("Different box above 1/0")),
        "fragile": flag(rule.get("Fragile 1/0")),
        "pressure": None if any(p is None for p in pressure) else [float(p) for p in pressure],
        "priority": None if val(rule.get("Derived door priority")) is None else int(rule["Derived door priority"]),
        "contents": val(row.get("Contents in English")),
    }


def make_cases(cont, boxes, rules, real):
    rules_by_id = {r["Box record ID"]: r for r in rules.to_dict("records")}
    by_case = {k: g for k, g in boxes.groupby("Case ID")}
    out = []
    for c in cont.to_dict("records"):
        cid = c["Case ID"]
        if cid not in by_case:
            continue
        rows = by_case[cid].to_dict("records")
        if any(mm(r["Length (mm)"]) is None for r in rows):
            continue  # range-only records (MAX-B) cannot be replayed exactly
        notes = []
        size = [mm(c["Inside length (mm)"]), mm(c["Inside width (mm)"]), mm(c["Inside height (mm)"])]
        door = [mm(c["Door width (mm)"]), mm(c["Door height (mm)"])]
        door = None if None in door else door
        payload = val(c["Payload limit (kg)"])
        prof = profile_for(c["Container type"]) if real else None
        if None in size and prof:
            p = PROFILES[prof]
            size = p["size"]
            door = door or p["door"]
            payload = payload or p["payload"]
            notes.append(f"Assumed Hapag-Lloyd {prof} profile: {p['ref']}")
        elif real and prof and door is None and cid != "MAX-D":
            door = PROFILES[prof]["door"]
            notes.append(f"Door from Hapag-Lloyd {prof} profile")
        if None in size:
            continue
        src = c["Source ID"]
        pressure = src in ("A-WT", "A-MD")
        fragile_blocks = src not in ("R-MAX-D",)  # MAX-D source: fragility does not imply a stacking ban
        bxs = [build_box(r, rules_by_id.get(r["Box record ID"], {}), fragile_blocks) for r in rows]
        if src == "A-BR":
            group = cid.split("-")[0]
        elif src == "A-MD":
            group = cid.split("-")[0] + "-" + cid.split("-")[-1]
        elif src == "A-WT":
            group = cid.split("-")[0]
        else:
            group = "REAL"
        ratio = val(c.get("Reported ratio"))
        ref_kind = {"R-MAX-E": "software", "R-MAX-D": "software"}.get(src)
        if src == "R-ATL":
            notes.append("Atlas ratio is shipment volume / capacity, not a packing result. Lid-bearing limits not modelled.")
        if src == "R-MAX-D":
            notes.append("Two-tier limits for SKU-08/09 not modelled.")
        out.append({
            "id": cid, "source": src, "group": group,
            "container": {"id": c["Container ID"], "size": size, "door": door,
                           "payload": None if payload is None else float(payload)},
            "options": {"support": True, "stacking": True, "pressure": pressure,
                        "fragileBlocksStacking": fragile_blocks},
            "boxes": bxs,
            "reference": {"ratio": ratio, "kind": ref_kind},
            "notes": notes,
        })
    return out


def scenarios():
    up = [r for r in ALL_ROT if r[2] == 2]
    fixed = [[0, 1, 2]]
    p20 = PROFILES["20GP"]
    c20 = {"id": "HL-20GP", "size": p20["size"], "door": p20["door"], "payload": float(p20["payload"])}

    def box(t, q, s, w, rot=None, **kw):
        b = {"type": t, "qty": q, "size": s, "weight": w, "rotations": rot or ALL_ROT, "floorOnly": False,
             "stackable": None, "similarAbove": None, "differentAbove": None, "fragile": None,
             "pressure": None, "priority": None, "contents": None}
        b.update(kw)
        return b

    def case(cid, boxes, notes, cont=c20, pressure=False):
        return {"id": cid, "source": "SCENARIO", "group": "SCN", "container": cont,
                "options": {"support": True, "stacking": True, "pressure": pressure, "fragileBlocksStacking": True},
                "boxes": boxes, "reference": {"ratio": None, "kind": None}, "notes": [notes]}

    return [
        case("SC-01-DOOR", [box("WIDE", 2, [2000, 2345, 1000], 300, fixed), box("OK", 10, [1000, 1000, 1000], 100)],
             "WIDE fits inside (2352) but not through the 2340 door in its fixed orientation: expect 2 unplaced."),
        case("SC-02-PAYLOAD", [box("HEAVY", 40, [1000, 1000, 500], 1000)],
             "Space allows 40 boxes (5 x 2 x 4) but the payload of 28,130 kg allows only 28."),
        case("SC-03-FRAGILE", [box("GLASS", 10, [1200, 1000, 800], 60, up, fragile=True),
                                box("BOOKS", 30, [800, 600, 600], 90, up)],
             "Nothing may be placed on fragile GLASS boxes."),
        case("SC-04-FLOOR", [box("MACHINE", 6, [1500, 1100, 900], 900, up, floorOnly=True),
                              box("CARTON", 60, [600, 400, 400], 20, up)],
             "MACHINE boxes must stay on the floor (z = 0)."),
        case("SC-05-NOSTACK", [box("DRUM", 20, [600, 600, 900], 200, up, stackable=False),
                                box("CARTON", 40, [600, 400, 400], 20, up)],
             "No box may be placed on top of a DRUM."),
        case("SC-06-ORIENT", [box("FRIDGE", 8, [700, 700, 1800], 80, up),
                               box("PANEL", 12, [2000, 1000, 100], 30, ALL_ROT)],
             "FRIDGE must stay upright; PANEL may rotate freely."),
        case("SC-07-PRIORITY", [box("STOP1", 20, [800, 600, 600], 40, up, priority=1),
                                 box("STOP2", 20, [800, 600, 600], 40, up, priority=2),
                                 box("STOP3", 20, [800, 600, 600], 40, up, priority=3)],
             "Priority 1 unloads first and should be nearest the door."),
        case("SC-08-UNIFORM", [box("CARTON", 1200, [600, 400, 400], 12, up)],
             "Large quantity of identical cartons: more than the container holds."),
        case("SC-09-OVERSIZE", [box("TOO-LONG", 1, [6500, 1000, 1000], 500, up), box("OK", 20, [1000, 1000, 1000], 100)],
             "TOO-LONG exceeds the internal length in every allowed orientation: expect 1 unplaced."),
        case("SC-10-SAMPLE5", [
            box("BOX-D01", 1, [1000, 1300, 600], 80, fixed, stackable=False, fragile=True, priority=1, contents="Glass"),
            box("BOX-D02", 1, [1100, 1400, 700], 120, fixed, stackable=False, priority=2, contents="Books"),
            box("BOX-D03", 1, [900, 1300, 650], 95, fixed, stackable=False, priority=3, contents="Work equipment"),
            box("BOX-D04", 1, [1200, 1500, 650], 150, fixed, stackable=True, priority=4, contents="Supplies"),
            box("BOX-D05", 1, [800, 1250, 450], 50, fixed, stackable=False, priority=4, contents="Accessories")],
            "The team's original five-box sample (SAMPLE-05)."),
        case("SC-11-PRESSURE", [box("WEAK", 10, [1000, 1000, 500], 50, up, pressure=[0.01, 0.01, 0.01]),
                                 box("HEAVY", 10, [1000, 1000, 500], 400, up, pressure=[1.0, 1.0, 1.0])],
             "WEAK boxes carry at most 0.01 kg/cm2 x 10,000 cm2 = 100 kg: HEAVY must not sit on them.",
             pressure=True),
    ]


real_c, real_b, real_r = rd("حاويات حقيقية Real Containers"), rd("بوكسات حقيقية Real Boxes"), rd("قيود حقيقية Real Rules")
bench_c, bench_b, bench_r = rd("حاويات معيارية Bench Cases"), rd("بوكسات معيارية Bench Boxes"), rd("قيود معيارية Bench Rules")

real = make_cases(real_c, real_b, real_r, real=True)
bench = make_cases(bench_c, bench_b, bench_r, real=False)
scn = scenarios()


def quick_pick(c):
    cid = c["id"]
    if c["source"] in ("A-BR", "A-WT"):
        return int(cid.split("-")[1]) <= 10
    if c["source"] == "A-MD":
        return int(cid.split("-")[1]) <= 3
    return True


quick = [c for c in bench if quick_pick(c)] + real + scn
full = bench + real + scn
for name, data in (("cases_quick.json", quick), ("cases_full.json", full), ("scenarios.json", scn)):
    with open(f"{OUT}/{name}", "w", encoding="utf-8") as fh:
        json.dump({"version": 1, "cases": data}, fh, ensure_ascii=False, separators=(",", ":"))
from collections import Counter
print("real:", [c["id"] for c in real])
print("quick:", len(quick), Counter(c["group"] for c in quick))
print("full:", len(full))
