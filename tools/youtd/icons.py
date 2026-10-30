#!/usr/bin/env python3
"""Icons für YouTD: ordnet jedem Item ein Modell aus den Paketen zu (Stichwörter im Namen) und jeder Tower-Familie ihr
Tower-Modell, schreibt data/youtd/icons.json und rendert jedes Modell einmal nach assets/youtd/icons/<key>.png.

    python3 -I tools/youtd/icons.py [--nur-json] [--neu]

--nur-json: nur die Zuordnung schreiben. --neu: auch vorhandene Bilder neu rendern (sonst nur fehlende).
Modelle: "paket/name" (assets/models/pakete/), "res://…" oder "kristall:<farbe>" (Kristall in Farbe).
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_JSON = os.path.join(ROOT, "data", "youtd", "icons.json")
OUT_DIR = os.path.join(ROOT, "assets", "youtd", "icons")
N = "res://assets/models/nature/%s.glb"

# Erstes passendes Stichwort gewinnt (Groß/klein egal, Wortanfang).
ITEM_RULES = [
    (r"oil of sharpness|arcane oil of sharpness|divine oil of sharpness", "q_fantasy_props/potion_1"),
    (r"oil of magic", "q_fantasy_props/potion_2"),
    (r"oil of accuracy|seeker", "q_fantasy_props/potion_4"),
    (r"oil of swiftness", "kk_dungeon/bottle_a_green_gltf"),
    (r"oil of sorcery", "kk_dungeon/bottle_b_brown_gltf"),
    (r"oil of exuberance|oil of lore", "kk_dungeon/bottle_c_green_gltf"),
    (r"tears of the gods|pure aether|wizard's soul|magic vial|void vial|liquid gold|aqueous|toxic|love potion|wine",
     "q_fantasy_props/small_bottle"),
    (r"keg", "kk_dungeon/keg_decorated_gltf"),
    (r"chicken", "q_suesse_monster/chicken"),
    (r"piggy", "q_suesse_monster/pig"),
    (r"sheep", "q_bauernhof/sheep"),
    (r"rabbit|bunny", "q_monster/big_bunny"),
    (r"frog", "q_monster/big_frog"),
    (r"horseshoe|equus", "q_tiere/horse"),
    (r"dragon|phoenix", "q_monster/flying_dragon"),
    (r"mine cart", "q_fantasy_props/stall_cart_empty"),
    (r"consumable plant|magic flower|shimmerweed|gift of the wild", "q_feldfruechte/flower_1"),
    (r"hobbit|troll|commander|old hunter|arms dealer|morgul", "q_figuren/knight_male"),
    (r"egg", "k_essen/egg"),
    (r"meat", "k_essen/meat_cooked"),
    (r"recipe", "k_essen/pot_stew"),
    (r"book|tome|libram|manual|ledger|stories|calculus|knowledge|spellbook", "kk_abenteurer/spellbook_closed"),
    (r"scroll|script|map|list|bark|mark of|sign of", "q_fantasy_props/scroll_1"),
    (r"skull|head|face|bones|trophy", "kk_halloween/skull"),
    (r"excalibur|sword|blade|bastardo|reckoning", "kk_abenteurer/sword_2handed_color"),
    (r"dagger|knives|glaive|bane", "kk_abenteurer/dagger"),
    (r"pick|mining tools|pillage", "q_fantasy_props/pickaxe_bronze"),
    (r"axe|scythe", "kk_abenteurer/axe_2handed"),
    (r"hammer|maul|club|fist", "q_fantasy_props/anvil"),
    (r"spear|trident|naga", "q_zombie/spear"),
    (r"crossbow", "kk_abenteurer/crossbow_2handed"),
    (r"arrow|quiver", "kk_abenteurer/arrow_bow_bundle"),
    (r"bow|elune", "kk_abenteurer/bow_with_string"),
    (r"sniper|sharp shooter|railgun", "q_waffen/sniper_rifle_2"),
    (r"rifle|blunderbuss|gun|shot|round|ammunition|shells", "q_waffen/revolver_2"),
    (r"rocket|grenade|bomb|mine|stunner", "k_blaster/grenade_a"),
    (r"tank", "q_cyberpunk/tank"),
    (r"wand|rod|zap", "kk_abenteurer/wand"),
    (r"staff|scepter|branch|stick", "kk_abenteurer/staff"),
    (r"shield|armor|suit|helm|crown|circlet|halo|mask|hood|cloak|mantle|shroud|dress|sleeve", "kk_abenteurer/shield_spikes_color"),
    (r"glove|gauntlet|claw|hand|touch", "kk_abenteurer/shield_round_color"),
    (r"boots|leg|wheel|chrono|shackles", "kk_gemischt/chain_shackle"),
    (r"key|doorkey", "q_fantasy_props/key_gold"),
    (r"dice|luck|chance|fortune|coin|currency|greed|opulence|emporium", "q_fantasy_props/coin_pile"),
    (r"lamp|torch|lights|lantern", "kk_dungeon/torch_lit_gltf"),
    (r"drum|flute|pipe", "q_fantasy_props/mug"),
    (r"flag|ensign|banner|allegiance", "k_fantasy_stadt/banner_red"),
    (r"figurine|idol|doll|toy|statue|voodoo", "kk_gemischt/idol_a"),
    (r"backpack|kit|bag|pocket", "q_fantasy_props/bag"),
    (r"dumpster", "kk_stadt/dumpster"),
    (r"trap|tombstone", "q_ruinen/bear_trap_open"),
    (r"workbench|gear|disk|generator|column|polarisator|periscope|telescope|monocle|conductor|field|current", "q_fantasy_props/anvil_log"),
    (r"chalice|grail|cup", "q_fantasy_props/chalice"),
]
CRYSTAL_RULES = [  # Edelsteine, Kugeln, Ringe, Amulette, Essenzen: Kristall in Farbe
    (r"sapphire|lunar|moon|mana|arcane|aether", "kristall:4f7bff"),
    (r"emerald|wild|rot|acorn|tree", "kristall:4fd35a"),
    (r"blood|ruin|rage|demon|fury|vampir|brimstone|fire|flaming", "kristall:e8504a"),
    (r"shadow|void|dark|soul|doom|lich|death|insanity", "kristall:8a5ad0"),
    (r"lightning|thunder|storm|energy|electri|ball", "kristall:ffe060"),
]
FALLBACK = "kristall:d8c8a0"


def item_key(name: str) -> str:
    low = name.lower()
    for pat, model in ITEM_RULES + CRYSTAL_RULES:
        if re.search(r"\b(" + pat + r")", low):
            return model
    return FALLBACK


def tower_models() -> dict:
    """Familie -> Modell wie YoutdTower._look (tower_models.json, sonst LOOKS je Element)."""
    tm = json.load(open(os.path.join(ROOT, "data", "tower_models.json")))["youtd"]
    src = open(os.path.join(ROOT, "scripts", "youtd", "youtd_tower.gd")).read()
    looks = {}
    for el, body in re.findall(r'"(\w+)": \[(.*?)\]\],?\n', src, re.S):
        looks[el] = re.findall(r'\["(\w+)", (true|false)', body + "]")
    colors = json.load(open(os.path.join(ROOT, "data", "youtd", "rules.json")))["elements"]["colors"]
    towers = json.load(open(os.path.join(ROOT, "data", "youtd", "towers.json")))
    out = {}
    for t in towers.values():
        fam = str(int(t.get("family", 0)))
        if fam in out:
            continue
        v = tm.get(fam)
        if isinstance(v, dict):
            v = v.get("m") if "fehlt" not in v else None
        if v and v not in ("haus", "kristall"):
            out[fam] = v
            continue
        lst = looks.get(t["element"], [])
        if not lst:
            out[fam] = "kristall:" + colors.get(t["element"], "#cccccc").lstrip("#")
            continue
        name, solid = lst[int(fam) % len(lst)]
        if name.startswith("crystal"):
            out[fam] = "kristall:" + colors.get(t["element"], "#cccccc").lstrip("#") + ":" + name
        else:
            out[fam] = N % name
    return out


# Rollen-Symbole an den Tower-Icons: Angriff (Fadenkreuz = Einzelziel, Explosion = Masse, Vogel = gegen Flieger)
# und Unterstützung (Blitz: violett = Kontrolle, grün = Aura, gelb = Ökonomie). Nach Werten und Fähigkeitsnamen.
MASS = (r"splash|nova|storm|chain|bounce|multishot|barrage|explo|blast|grenade|frag|shrapnel|rain|wave|spread|field|"
        r"bombard|landslide|smash|hail|cleave|glaive|burst|eruption|breath|blizzard|plague|vapor|swarm|twister|spray|"
        r"badaboom|bomb|mist|thunderstorm|split|omnislash|earthquake")
ECO = (r"gold|greed|rich|bounty|treasure|loot|item|knowledge|wisdom|learn|experience|hoard|fortune|luck|steal|"
       r"excavation|mining|reimbursement|reward|charity|customer|purchase|teachings|research|script reading|exchange")
CC = (r"slow|stun|freez|frost|ice|icy|cold|entangl|root|silence|banish|fear|panic|net|grapple|cripple|maim|time|chill|"
      r"sleep|snare|curse|frozen|bash|crush|glare|planeshift|absolute zero|hangover|drunk|speed down|fright|calming|"
      r"restriction|maledict|atrophy|torture")
ECO_MODS = ("MOD_BOUNTY_RECEIVED", "MOD_EXP_RECEIVED", "MOD_ITEM_QUALITY_ON_KILL", "MOD_ITEM_CHANCE_ON_KILL")


def tower_roles(towers: dict) -> dict:
    ab = json.load(open(os.path.join(ROOT, "data", "youtd", "abilities.json")))
    out = {}
    for tid, t in towers.items():
        names = []
        for kind in ("abilities", "auras", "autocasts"):
            for i in t.get(kind, []):
                a = ab.get(kind, {}).get(str(i), {})
                if not a.get("hidden"):
                    names.append(str(a.get("name", "")).lower())
        text = " | ".join(names)
        mods = {m[0]: float(m[1]) for m in t.get("mods", [])}
        if t.get("targets") == "air" or mods.get("MOD_DMG_TO_AIR", 0) > 0:
            attack = "air"
        elif t.get("splash") or t.get("bounce") or t.get("multishot") or mods.get("MOD_DMG_TO_MASS", 0) > 0 \
                or re.search(MASS, text):
            attack = "mass"
        else:
            attack = "single"
        util = ""
        if any(mods.get(k, 0) > 0 for k in ECO_MODS) or re.search(ECO, text):
            util = "eco"
        elif re.search(CC, text):
            util = "cc"
        elif any(not ab.get("auras", {}).get(str(i), {}).get("hidden") for i in t.get("auras", [])):
            util = "aura"
        out[tid] = {"attack": attack, "util": util} if util else {"attack": attack}
    return out


def key_of(model: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", model.replace("res://assets/models/", "").replace(".glb", "").lower()).strip("_")


def main() -> None:
    items = json.load(open(os.path.join(ROOT, "data", "youtd", "items.json")))
    models = {}
    out = {"_info": "Erzeugt von tools/youtd/icons.py; Bilder unter res://assets/youtd/icons/<key>.png",
           "items": {}, "towers": {}, "models": models}
    for iid, it in items.items():
        m = item_key(it["name"])
        models[key_of(m)] = m
        out["items"][iid] = key_of(m)
    out["roles"] = tower_roles(json.load(open(os.path.join(ROOT, "data", "youtd", "towers.json"))))
    for fam, m in tower_models().items():
        models[key_of(m)] = m
        out["towers"][fam] = key_of(m)
    with open(OUT_JSON, "w") as f:
        json.dump(out, f, indent="\t", ensure_ascii=False, sort_keys=True)
        f.write("\n")
    print(f"{len(out['items'])} Items, {len(out['towers'])} Familien, {len(models)} Modelle -> {OUT_JSON}")
    if "--nur-json" in sys.argv:
        return
    os.makedirs(OUT_DIR, exist_ok=True)
    todo = [k for k in sorted(models) if "--neu" in sys.argv or not os.path.exists(os.path.join(OUT_DIR, k + ".png"))]
    if not todo:
        print("Alle Bilder vorhanden.")
        return
    subprocess.run([os.path.join(ROOT, "tools", "godot_import.sh")], cwd=ROOT, capture_output=True)
    args = []
    for k in todo:
        args += [k, models[k]]
    env = dict(os.environ, PATH=os.path.expanduser("~/.local/bin") + ":" + os.environ.get("PATH", ""))
    r = subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 256x256x24", "godot", "--rendering-driver", "opengl3",
                        "--resolution", "256x256", "--path", ROOT, "-s", "tools/youtd/icons.gd", "--", OUT_DIR] + args,
                       env=env, capture_output=True, text=True)
    bad = [l for l in r.stdout.splitlines() if l.startswith("FEHLER")]
    print(f"{len(todo) - len(bad)} Bilder gerendert" + (", Fehler: " + "; ".join(bad) if bad else ""))


if __name__ == "__main__":
    main()
