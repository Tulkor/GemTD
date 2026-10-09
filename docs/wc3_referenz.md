# Gem TD (Warcraft III) - Tower Data Summary

Data was extracted directly from the map files (object data and scripts), not from wikis:
- **BK v3.1** = [BK's] Gem Tower Defense v3.1 by Bryvx. This is the last official Bryvx version, preserved in github.com/nvs/gem history.
- **TD+** = Gem TD+ 1.6.14 by NVS. This is the maintained continuation, and gemtd.top is based on it.

The primary numbers below are BK v3.1. All TD+ values are in `wc3_towers.json` under `gemtd_plus_1_6_14` / `abilities_gemtd_plus`.

## Basic gems (damage / cooldown s / range), BK v3.1 = TD+ unless noted

| Gem | Chipped | Flawed | Normal | Flawless | Perfect | Great | Targets / ability |
|---|---|---|---|---|---|---|---|
| Amethyst | 10-15 / 0.8 / 1000 | 20-27 / 1.0 / 1200 | 30-45 / 1.0 / 1300 | 60-80 / 1.0 / 1350 | 140-170 / 1.0 / 1600 | 350-400 / 1.0 / 1650 | air only; Great: -3 armor aura 1000 |
| Aquamarine | 6-8 / 0.5 / 350 | 12-15 / 0.5 / 365 | 24-30 / 0.5 / 380 | 48-55 / 0.5 / 400 | 100-120 / 0.5 / 550 | 280 / 0.5 / 600 | fast; Great: +10% AS aura 1500 |
| Diamond | 8-12 / 0.8 / 500 | 16-18 / 1.0 / 550 | 30-37 / 1.0 / 600 | 58-65 / 1.0 / 650 | 140-150 / 1.0 / 750 | 300-350 / 1.0 / 850 | ground only; 25% crit x2 (Great x5) |
| Emerald | 4-7 / 0.8 / 500 | 10-13 / 1.0 / 550 | 15-25 / 1.0 / 600 | 30-37 / 1.0 / 700 | 80-95 / 1.0 / 900 | 275 / 1.0 / 900 | poison+slow (BK 2/3/5/8/16/50 dps; TD+ 2/4/8/16/40/100 dps, 6 s) |
| Opal | 5 / 0.8 / 600 | 10 / 1.0 / 700 | 20 / 1.0 / 800 | 40 / 1.0 / 900 | 85 / 1.0 / 1000 | 180 / 1.0 / 1500 | AS aura +10/15/20/25/35/50% @600/700/800/900/1000/1500 |
| Ruby | 8-9 / 1.0 / 800 | 13-16 / 1.0 / 800 | 20-25 / 1.0 / 800 | 38-45 / 1.0 / 800 | 80-100 / 1.0 / 900 | 140 / 0.5 / 900 | splash (Great: 3 targets, no splash) |
| Sapphire | 5-8 / 0.8 / 550 | 10-14 / 1.0 / 750 | 16-22 / 1.0 / 800 | 30-40 / 1.0 / 850 | 60-80 / 1.0 / 1400 | 200-250 / 1.0 / 2000 | slow 20% 5 s |
| Topaz | 4 / 0.8 / 500 | 8 / 1.0 / 500 | 14 / 1.0 / 500 | 25 / 1.0 / 500 | 75 / 1.0 / 600 | 250 / 1.0 / 700 | multishot 3/4/5/6/9/9 targets |

## Special towers

| Special | Recipe | Dmg / CD / Range (BK) | Upgrades (gold BK / TD+) |
|---|---|---|---|
| Silver | Chipped Diamond, Chipped Sapphire, Chipped Topaz | 20-21 / 1.0 / 550 | Sterling Silver (25/25): 40 / 1.0 / 650; Silver Knight (290/190): 150 / 1.0 / 750 |
| Malachite | Chipped Aquamarine, Chipped Emerald, Chipped Opal | 6 / 0.5 / 750 | Vivid Malachite (25/25): 11 / 0.5 / 800; Mighty Malachite (280/180): 45 / 0.55 / 800 |
| Star Ruby | Flawed Ruby, Chipped Amethyst, Chipped Ruby | no attack (aura/burn) | Blood Star (30/30): no attack (aura/burn); Fire Star (290/190): 65 / 0.5 / 600 |
| Jade | Normal Emerald, Normal Opal, Flawed Sapphire | 30-35 / 0.5 / 800 | China Jade (45/45): 50 / 0.5 / 800; Lucky China Jade (250/250): 55 / 0.35 / 850 |
| Red Crystal | Flawless Emerald, Normal Ruby, Flawed Amethyst | 50-75 / 0.8 / 1300 | Red Facet (100/100): 75-100 / 0.8 / 1400; Rose Quartz Crystal (150/150): 100-125 / 0.8 / 1500 |
| Dark Emerald | Perfect Emerald, Flawless Sapphire, Flawed Topaz | 90-150 / 0.8 / 550 | Enchanted Emerald (225/185): 100-200 / 0.7 / 700 |
| Gold | Perfect Amethyst, Flawless Amethyst, Flawed Diamond | 160-190 / 1.0 / 800 | Egyptian Gold (205/205): 160-200 / 0.75 / 800 |
| Uranium 238 | Perfect Topaz, Normal Sapphire, Flawed Opal | no attack (aura/burn) | Uranium 235 (190/190): 14 / 0.2 / 900 |
| Pink Diamond | Perfect Diamond, Normal Diamond, Normal Topaz | 150-175 / 0.75 / 800 | Great Pink Diamond (175/175): 175-225 / 0.65 / 850 |
| Paraiba Tourmaline | Perfect Aquamarine, Flawless Opal, Flawed Aquamarine, Flawed Emerald | 10-400 / 0.75 / 850 | Paraiba Tourmaline Facet (275/275): 30-420 / 0.75 / 875 |
| Black Opal | Perfect Opal, Flawless Diamond, Normal Aquamarine | 25 / 1.0 / 800 | Mystic Black Opal (275/275): 50 / 1.0 / 1000 |
| Blood Stone | Perfect Ruby, Flawless Aquamarine, Normal Amethyst | 115 / 1.5 / 700 | Ancient Blood Stone (225/225): 160-240 / 0.8 / 700 |
| Yellow Sapphire | Perfect Sapphire, Flawless Ruby, Flawless Topaz | 100 / 1.0 / 800 | Star Yellow Sapphire (180/180): 180 / 0.8 / 850 |
| Stone of Bryvx | Combine past Great: 4 identical Perfects (BK); in TD+ also 2 identical Greats or 3 Perfects | 500 / 0.8 / 850 | - |

Special abilities in short (BK; TD+ differs, see JSON):
- **Silver**: Splash damage with frost slow (20%/5 s), splash radius ~250 (BK v3.1). Attacks air+ground (splash only vs ground).
  - Sterling Silver: Splash ~250 + frost slow. 40 dmg, 1 s, 650 range.
  - Silver Knight: Splash ~250 + frost slow. 150 dmg, 1 s, 750 range.
- **Malachite**: Multishot: hits 3 targets, 750 range (BK v3.1). 6 dmg, 0.5 s.
  - Vivid Malachite: Hits 4 targets within 800 range. 11 dmg, 0.5 s.
  - Mighty Malachite: Hits all targets within 800 range. 45 dmg, 0.55 s.
- **Star Ruby**: No attack. Burn (permanent immolation): 40 dmg/s to enemies within 265 range (BK v3.1). Scales with kills (+10% per 10 kills, ability level 1-11).
  - Blood Star: No attack. Burn 50 dmg/s within 500 range, scales with kills.
  - Fire Star: Attacks ALL enemies within 600 range: 65 dmg every 0.5 s (BK v3.1).
- **Jade**: Stacking poison 5 dmg/s + 50% slow for 2 s.
  - China Jade: Poison 10 dmg/s + 50% slow for 3 s.
  - Lucky China Jade: Poison 10 dmg/s + 50% slow 4 s. Lucky charm: 1% chance per attack to give gold = half the current level number; 1% chance to stun 2 s; 5% chance for 4x damage.
- **Red Crystal**: Air only. Aura: -4 armor to enemy air units within 1300 range (stacks with Red Facet/Rose Quartz).
  - Red Facet: Air only. -5 armor aura to air units within 1400.
  - Rose Quartz Crystal: Air only. -6 armor aura to air within 1500; immolation 50 dmg/s within 1500 range.
- **Dark Emerald**: 12.5% chance per attack to stun 1.5 s.
  - Enchanted Emerald: 12.5% stun 1.5 s; 15% chance for 4x damage. Dmg 100-200.
- **Gold**: 25% chance for 2x damage; attacked units lose 5 armor (Desolate/Corruption).
  - Egyptian Gold: 30% chance 2x damage; -8 armor on attacked units.
- **Uranium 238**: No attack. Burns 200 dmg/s within 500 range; slows units within 500 by 50% (object data -75%, tooltip 50%).
  - Uranium 235: Adds gamma rays: 14 dmg every 0.2 s to all enemies within 900 (=70 dps) + 200 dps burn 500 + 50% slow 500.
- **Pink Diamond**: Ground only. 10% chance for 5x damage.
  - Great Pink Diamond: Ground only. 10% chance for 8x damage.
- **Paraiba Tourmaline**: -4 armor aura to ground units within 600; 20% chance per attack to cast a 250-damage Frost Nova (costs 5 mana). Dmg 10-400.
  - Paraiba Tourmaline Facet: -6 armor to ground within 650; 20% chance 350-damage Frost Nova. Dmg 30-420.
- **Black Opal**: +30% damage aura to towers within 1000 range. Has "Swap" (200 gold: swap position with another gem or rock).
  - Mystic Black Opal: +40% damage aura within 1200 (stacks with Black Opal). Swap.
- **Blood Stone**: 400 splash attack; immolation 60 dmg/s to enemies within 500. 115 dmg, 1.5 s.
  - Ancient Blood Stone: 10% chance 3x damage (crit multiplier grows 3.0-5.5 with kill level); 10% chance to cast 350-damage Blood Lightning (5 mana). 160-240 dmg.
- **Yellow Sapphire**: Splash 400 radius with frost slow. 100 dmg, 1.0 s.
  - Star Yellow Sapphire: 400 splash slow; +5% damage aura to towers within 1200. 180 dmg.
- **Stone of Bryvx**: +50% damage aura to towers within 1500 (BK v3.1, stacks with Black Opal).

## Slates (traps). Creeps walk over them; they never block the path

| Slate | Recipe | Effect (BK v3.1) |
|---|---|---|
| Air Slate | Normal Amethyst + one of Flawed Emerald/Opal/Ruby | BK v3.1: 40 dmg every 0.5 s to ground units stepping on/next to it (melee 130, small splash 100) AND ranged air attack 40 dmg / 0.5 s at 850 range. |
| Hold Slate | Normal Topaz + one of Flawed Amethyst/Sapphire | Grabs a ground enemy that walks over it, stuns 1.5 s; deals 160 + 20 x kills damage; 2 s cooldown after a hold. |
| Ancient Slate | Hold Slate + Air Slate | Grabs ground OR air enemy for 2.5 s, -12 armor on grabbed unit, damage [(kills x 5..120) + (level x 50)]; 2.5 s cooldown. |
| Slow Slate | Normal Sapphire + one of Flawed Diamond/Emerald/Aquamarine | 100 dmg / 0.5 s to ground units on/next to it; attacked units permanently lose 15% base move speed (not damage tests). |
| Opal Vein Slate | Normal Opal + one of Flawed Topaz/Ruby | 80 dmg / 0.5 s melee ground; +10% attack speed aura within 700 (stacks with Opals). |
| Wraith Slate | Opal Vein Slate + Slow Slate | 200 dmg / 0.3 s melee ground; +10% attack speed aura 1000 (not stacking with Opal Vein); Incinerate: +35 stacking dmg per hit (35, 70, 105 ...), unit dying under effect explodes for 500 within 750; lasts 5 s. |
| Spell Slate | Normal Aquamarine + one of Flawed Diamond/Amethyst | 30-40 dmg 0.5 s melee (air+ground). Per attack: 5% Frost Nova (100), 5% Fan of Knives (80), 5% Lightning (85), 5% Carrion Swarm (125), 5% -5 armor (15 s), 5% +3 gold. |
| Poison Slate | Normal Emerald + one of Flawed Topaz/Opal/Aquamarine | Poison: 20 dmg every 2 s for 20 s, 25% slow; does not stack; hits air+ground. Scales with kills (20->40 dmg, 20->40 s). |
| Elder Slate | Spell Slate + Poison Slate | 100 dmg 0.33 s. Per attack (level 1): 5% Frost Nova 300, 5% Thunder Clap 150, 5% Fan of Knives 150, 7% -7 armor 25 s, 5% Shockwave 200, 5% gold shot (5 + kills/10 gold), 5% Forked Lightning 200, 8% Poison shot 40/2 s. Grows per 10 kills up to level 11 (FN 600, TC 300, FoK 300, -27 armor 35 s, SW 700, FL 400, poison 80). |
| Range Slate | Normal Ruby + one of Flawed Topaz/Amethyst/Ruby | 15 dmg 0.5 s, hits ALL targets within 600 (air+ground). |
| Damage Slate | Normal Diamond + one of Flawed Sapphire/Opal | Deals (kills x 10 + level x 20) dmg every 1 s to a close ground unit; +10% damage aura within 250 (stacks with Black Opal). |
| Viper Slate | Damage Slate + Range Slate | 30 dmg 0.5 s hits all targets within 750; burn 50 dmg/s within 400; +10% damage aura within 400 (+5% per 10 kills up to 60%; not stacking with Damage Slate). |

## Rules

- **placement**: Each round the builder (Miner) places 5 random gems ("Random Gem", costs 1 lumber each; you get 5 lumber per round). After the 5th gem you choose ONE to keep (Keep). All other placed gems of that round turn into Mazing Rocks (walls). Gems are 2x2 structures that block pathing; creeps must path through your maze from spawn via checkpoints to your mine.
- **combining_same_gems**: Among the 5 gems of the current round: 2 identical gems (same type & quality) -> Combine x2 = +1 quality; Gem TD+ also 3 (x3) or 4 (x4) identical = +2 qualities (BK v3.1: "4 Perfect of the same" combine). Going beyond Great creates the Stone of Bryvx. The combined gem is the one kept.
- **special_combination**: Special recipe: all ingredient gems must be owned at the same time, either all within this round's 5 placed gems ("one-hit": one of them can be turned into the special directly) OR spread over kept gems from previous rounds anywhere on your field plus this round. A "Combine Special" button appears on the ingredient; the special is created at that ingredient's position, the other ingredients turn into rocks (slates are just removed). Kills of all ingredients are summed into the special.
- **special_upgrades**: Specials are upgraded like WC3 buildings for gold (no extra gems needed). Upgrade cost = gold cost of the target tower (see recipe.gold_cost_*). Upgrade refunds 100% if cancelled (Gem TD+).
- **rocks**: Unchosen gems become Mazing Rocks (10 HP structures, gold value 3). Each rock has a free "Remove Rock" ability (no gold cost, no mana) usable at any time; no wave/round restriction found in script. Combining specials leaves rocks where the ingredients stood.
- **slates**: Basic slates only from the round placement (Normal + Flawed recipe) or Extra Chance (Slate). Slates do not block creeps (creeps walk over them). BK: each slate can teleport once anywhere within 2000 range. Gem TD+: base slates may stack on other base slates of a different type.
- **Gem quality research**: 8 levels costing [20, 50, 80, 110, 140, 170, 200, 230] gold. Chances per level are in the JSON; the max level gives 0/30/30/30/10 % (Chipped/Flawed/Normal/Flawless/Perfect).
- **Extra chance**: Extra Chance (175 gold): choose a Perfect gem type; next round each of the 5 placed gems has a higher chance to become it. Extra Chance Slate (125 gold): same for a chosen slate. Once per round. Normal chance ~1.25%/gem; with Extra Chance 5.95%/gem (v2.2); "Increase Extra Chances" research (5 levels, from 50 gold) raises it 3/83 ... 8/88 per gem placed. Requires max Gem Quality? (not verified for BK). TD+: Gem TD+: Extra Chance (175 gold for a Perfect type, 125 for a slate) only available after Gem Quality level 8; active for the whole placement round; bonus multiplier grows (up to 10x) when used repeatedly in the same class; weights: total 80, slate initial 18.75, type initial 25.
- **Waves**: 42 levels in Classic mode; damage tests (bosses) at levels 14, 28 (150,000 HP) and 42 (final, 700,000 HP). Race mode: 50 levels, level 25 "ReRunner" boss, final damage test 1.5 M HP. TD+: 50 levels; 10 creeps per level spawned every 1.61 s; level 50: 10 minions (85,000 HP) + boss "Damage Test" 500,000 HP. Air levels: Every 4th level is air: 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48 (Gem TD+ list; BK classic same up to 40).
- **Lives**: Mine has 50 max HP = lives; game starts with 15 lives (30%). A leaking creep removes as many lives as its gold bounty. Buy Life at the mine: 10 gold per life, max 50. TD+: Max lives reduced to 30 in 1.5.4; lives removed entirely in 1.6.0 (leaks only cost time/gold).
- **Kill ranks**: Every tower gains +10% damage per 10 kills (Valued 10, Prized 20, Meaningful 30, Adored 40, Recognized 50, Cherished 60, Honored 70 ... Worshipped 120+: +120%). Immolation/spell levels of Star Ruby line, Uranium, Viper/Elder/Poison slates grow 1 level per 10 kills (Gem TD+: +10% per 10 kills, cap 100 kills).

## Uncertain / estimated

- Primary damage/cooldown/range values are from [BK's] Gem TD v3.1 object data (exact); "gemtd_plus_1_6_14" sub-objects hold the Gem TD+ values (exact). Earlier Bryvx versions (v1.x-v2.x, the very first "Gem TD" by Bryvx) may differ and were not checked.
- Damage ranges computed as base+dice .. base+dice*sides using WC3 defaults of the base unit (Guard Tower/Cannon Tower/Ancient Protector) where a field was not overridden; this matches the Gem TD+ in-game tooltips.
- Sapphire/Silver/Yellow Sapphire slow duration 5 s and amount 20% come from the WC3 Frost Attack default + map constant FrostMoveSpeedDecrease=0.2 (Gem TD+ tooltip confirms 20%/5 s; for BK assumed identical since constant is the same).
- BK v3.1 Emerald Normal duration (5 s) and Perfect/Great slow (50%) partly from WC3 Slow Poison defaults/tooltips, not explicit fields.
- BK Uranium 238 slow: object data says -75% but in-game tooltip says 50%; actual in-game value capped by minimum speed 220.
- BK Ancient Slate damage formula "(kills x 5-120) + (level x 50)" is quoted from the in-game tooltip; exact trigger formula not verified.
- Ruby splash: WC3 splash uses full/medium/small radii with damage factors (default 100%/50%/25%); factors not extracted.
- Rock removal: no cost found in either version (ability without gold/mana cost). Some other Gem TD variants (e.g. Dota 2 Gem TD) charge gold for rock removal - not WC3.
- Extra Chance for BK: whether it needs max Gem Quality is not verified (Gem TD+ requires level 8).
- German names (name_de) are my own translations, not official.
- Dota 2 Gem TD uses different names (Asian Jade, Lucky Asian Jade, Uranium 238->235 etc.) and different numbers; not used except for name mapping.
- Gem TD+ 1.6.x removed lives and some BK features (race mode, gamble machines, classic mode); rule text above notes this.
- Stone of Bryvx in BK v3.1: confirmed via 4 identical Perfects; whether 2 Greats also work in BK is not verified.
- Creep HP in the JSON is TD+ base data. Difficulty and changelog adjustments are not applied.
