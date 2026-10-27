"""Gemeinsame Umbenennung für Code aus YouTD 2 (MIT): Klassen und Singletons bekommen das Präfix Yt,
damit sie nicht mit TD-Hub-Klassen (Tower, Effects, Sfx …) zusammenstoßen."""
import re

# Klassen und Autoloads aus YouTD 2, die portierter Code benutzt
NAMES = """
Unit Tower Creep Buff BuffType Event Modifier Modification ModificationType TargetType Effect Projectile ProjectileType
Iterate TowerBehavior CombatLog Utils MultiboardValues CreepSize CreepCategory Globals SpellType SpellDummy InterpolatedSprite
CbStun CbSilence Element Constants AttackType ArmorType SfxPaths SFX Rarity Autocast Aura DummyUnit TowerDetails GroupManager
Experience VectorUtils ManualTimer BuffRangeArea Player Item ItemBehavior CreepCorpse Summoner ShardofSouls1 BuffGroupMode
TowerProperties ItemProperties WaveSpecial Messages GameMode Difficulty BuilderTier Builder ItemType UtilsStatic ItemDropCalc
""".split()

_RE = re.compile(r"\b(" + "|".join(sorted(NAMES, key=len, reverse=True)) + r")\b")


def rename(text: str) -> str:
    out = []
    # Zeichenketten (res://…) unverändert lassen
    for i, part in enumerate(re.split(r'("(?:[^"\\]|\\.)*")', text)):
        out.append(part if i % 2 else _RE.sub(lambda m: "Yt" + m.group(1), part))
    return "".join(out)
