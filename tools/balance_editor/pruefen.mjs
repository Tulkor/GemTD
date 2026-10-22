// Prüft den Balance-Editor im echten Browser (Playwright, Chromium):
// 1. Jede eingebettete Datei kommt beim Schreiben Byte für Byte gleich heraus (Format bleibt).
// 2. Pfeile, Schritt-Auswahl, alle Stufen, Fähigkeiten, Änderungsliste und Export funktionieren.
// 3. Der Export lässt sich mit tools/balance_anwenden.py --probe ohne Konflikt übernehmen.
// Aufruf aus dem Projektordner: node tools/balance_editor/pruefen.mjs [--laut] [--bilder=ordner]
// (oder tools/run_tests.sh balanceeditor; läuft bei "geaendert" mit, wenn der Editor geändert wurde)
import { createRequire } from "module";
import { execFileSync } from "child_process";
import { mkdtempSync, readFileSync } from "fs";
import { tmpdir } from "os";
import path from "path";

const require = createRequire(import.meta.url);
let chromium;
try { ({ chromium } = require("playwright")); } catch (e) { ({ chromium } = createRequire("/opt/node22/lib/node_modules/")("playwright")); }

const tmp = mkdtempSync(path.join(tmpdir(), "balance-editor-"));
const html = path.join(tmp, "balance_editor.html");
execFileSync("python3", ["tools/balance_editor/bauen.py", "--ziel=" + html]);
const shots = (process.argv.find((a) => a.startsWith("--bilder=")) || "").split("=")[1];

let failed = 0;
const loud = process.argv.includes("--laut");
const check = (ok, text) => { if (!ok || loud) console.log((ok ? "OK     " : "FEHLER ") + text); if (!ok) failed++; };

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1280, height: 900 }, acceptDownloads: true });
const errors = [];
page.on("pageerror", (e) => errors.push(e.message));
page.on("dialog", (d) => d.accept());
await page.goto("file://" + html);

// 1. Format
const bad = await page.evaluate(() => Object.keys(FILES).filter((p) => fileText(p) !== EMBED.texts[p]));
check(bad.length === 0, "Format bleibt beim Schreiben gleich (" + (bad.length ? bad.slice(0, 5).join(", ") : "alle Dateien") + ")");

// 2. Bedienung: GemTD, Tower, Rubin
await page.click("text=GemTD");
await page.click("#kind >> text=Tower");
await page.selectOption("#pick", "data/towers/ruby.json");
await page.click("#pct >> text=10 %");
const before = await page.evaluate(() => FILES["data/towers/ruby.json"].cur.tiers[0].damage.slice());
await page.locator(".stat", { hasText: "Schaden" }).first().locator(".arrow.up").click();
const after = await page.evaluate(() => FILES["data/towers/ruby.json"].cur.tiers[0].damage.slice());
check(after[0] === Math.round(before[0] * 1.1) && after[1] === Math.round(before[1] * 1.1), `Schaden +10 %: ${before} -> ${after}`);

await page.click("#pct >> text=Custom");
await page.fill("#pct input", "20");
await page.dispatchEvent("#pct input", "change");
await page.check("text=Pfeile auf alle Stufen");
const cd = await page.evaluate(() => FILES["data/towers/ruby.json"].cur.tiers.map((t) => t.cooldown));
await page.locator(".stat", { hasText: "Abklingzeit" }).first().locator(".arrow.down").click();
const cd2 = await page.evaluate(() => FILES["data/towers/ruby.json"].cur.tiers.map((t) => t.cooldown));
check(cd2.every((v, i) => Math.abs(v - cd[i] * 0.8) < 1e-9), `Abklingzeit −20 % in allen Stufen: ${cd} -> ${cd2}`);
await page.uncheck("text=Pfeile auf alle Stufen");

// Fähigkeit: Radius ändern und eine neue hinzufügen
await page.click("#pct >> text=5 %");
const r0 = await page.evaluate(() => FILES["data/towers/ruby.json"].cur.tiers[0].abilities[0].radius);
await page.locator(".card .stat", { hasText: "Radius" }).first().locator(".arrow.up").click();
const r1 = await page.evaluate(() => FILES["data/towers/ruby.json"].cur.tiers[0].abilities[0].radius);
check(Math.abs(r1 - r0 * 1.05) < 0.01, `Splash-Radius +5 %: ${r0} -> ${r1}`);
await page.locator(".panel .row select").last().selectOption("crit");
await page.click("text=+ Fähigkeit");
const abs = await page.evaluate(() => FILES["data/towers/ruby.json"].cur.tiers[0].abilities.map((a) => a.type));
check(abs.join() === "splash,crit", "Fähigkeit hinzugefügt: " + abs);
const rubyText = await page.evaluate(() => fileText("data/towers/ruby.json"));
check(/"chance": 0\.2,\n\t+"multiplier": 2\.0/.test(rubyText), "neue Fähigkeit mit Kommazahlen wie in abilities.gd (2.0)");
check(/"cooldown": 0\.8,/.test(rubyText), "Abklingzeit als Zahl geschrieben");
if (shots) await page.screenshot({ path: path.join(shots, "balance_editor_tower.png"), fullPage: true });

// GemTD-Wellen
await page.click("#kind >> text=Enemies");
await page.selectOption("#pick", "4");
const hp0 = await page.evaluate(() => FILES["data/enemies/" + FILES["data/waves/classic.json"].cur.waves[4].groups[0].enemy + ".json"].cur.hp);
await page.locator(".card .stat", { hasText: "Leben" }).first().locator(".arrow.up").click();
const hp1 = await page.evaluate(() => FILES["data/enemies/" + FILES["data/waves/classic.json"].cur.waves[4].groups[0].enemy + ".json"].cur.hp);
check(hp1 === Math.round(hp0 * 1.05), `Welle 5 Leben +5 %: ${hp0} -> ${hp1}`);
if (shots) await page.screenshot({ path: path.join(shots, "balance_editor_wellen.png"), fullPage: true });

// eeveTD und Maul
await page.click(".tab >> text=eeveTD");
await page.click("#kind >> text=Tower");
const eeveCount = await page.locator("#pick option").count();
check(eeveCount > 100, "eeveTD-Tower im Menü: " + eeveCount);
await page.selectOption("#pick", "data/towers/eeve_gold_mine.json");
await page.locator(".stat", { hasText: "Kosten" }).first().locator(".arrow.down").click();
await page.click(".tab >> text=Shopping Maul");
const maulCount = await page.locator("#pick option").count();
check(maulCount > 200, "Maul-Tower im Menü: " + maulCount);
await page.locator(".stat", { hasText: "Reichweite" }).first().locator(".arrow.up").click();
await page.click("#kind >> text=Enemies");
await page.locator(".stat", { hasText: "HP-Faktor" }).first().locator(".arrow.up").click();
if (shots) await page.screenshot({ path: path.join(shots, "balance_editor_maul.png"), fullPage: true });

const n = await page.evaluate(() => allChanges().length);
const rows = await page.locator("#changes tr").count();
check(n === 12 && rows === n + 1, `Änderungsliste: ${n} Änderungen, ${rows - 1} Zeilen`);
const badges = await page.locator(".tab .badge").allTextContents();
check(badges.join() === "9,1,2", "Zähler an den Tabs: " + badges);

// Eine zurücknehmen
await page.locator("#changes tr").last().locator("button").click();
check(await page.evaluate(() => allChanges().length) === 11, "einzelne Änderung zurückgenommen");

// 3. Export und Übernahme (nur Probe)
const [dl] = await Promise.all([page.waitForEvent("download"), page.click("#b-export")]);
const exp = path.join(tmp, "balance_aenderungen.json");
await dl.saveAs(exp);
const data = JSON.parse(readFileSync(exp, "utf-8"));
check(data.aenderungen.length === 11, "Export enthält 11 Änderungen");
try {
  const out = execFileSync("python3", ["tools/balance_anwenden.py", exp, "--probe"], { encoding: "utf-8" });
  check(/11 übernommen, 0 ausgelassen/.test(out), "balance_anwenden.py --probe: " + out.trim().split("\n").pop());
} catch (e) { check(false, "balance_anwenden.py: " + (e.stdout || e.message)); }

check(errors.length === 0, "keine JavaScript-Fehler" + (errors.length ? ": " + errors.join("; ") : ""));
await browser.close();
console.log(failed ? `${failed} Prüfungen fehlgeschlagen` : "Balance-Editor: alle Prüfungen bestanden");
process.exit(failed ? 1 : 0);
