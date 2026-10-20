# TD-Hub-Relay (Spielen ohne Portfreigabe)

Der Relay ist ein kleiner Lobby-Server. Host und Mitspieler verbinden sich nur ausgehend mit ihm,
deshalb muss kein Spieler einen Port im Router freigeben. Der Host bekommt in der Lobby einen
Code aus fünf Zeichen (z. B. `K7QXM`), Mitspieler tippen ihn statt einer IP-Adresse ein. Der
Server leitet danach die Pakete des Spiels weiter.

- `relay.py`: der Server, nur Python-Standardbibliothek (ab 3.9), TCP-Port 24565
- `Dockerfile`, `image_bauen.sh`: Image für x86 und ARM als `.tar` zum Importieren
- `docker-compose.yml`: dasselbe als Projekt für Container Manager oder `docker compose`
- Gegenstück im Spiel: `scripts/net/relay_peer.gd`, Einstellung „Server“ in der Lobby
  (oder fest eingebaut über `Net.DEFAULT_RELAY` in `scripts/autoload/net.gd`)
- Test: `tools/run_tests.sh relay` (Host und zwei Mitspieler über einen lokalen Relay)

## Auf einer Synology einrichten

Voraussetzung: DSM 7.2 oder neuer und ein Modell mit **Container Manager** (im Paket-Zentrum
suchen; bei manchen günstigen „j“-Modellen fehlt er).

Fertige Images (bauen mit `tools/relay/image_bauen.sh`, liegen unter `/mnt/project-files/relay/`):
- `tdhub-relay-amd64.tar` für Intel- und AMD-Prozessoren (die meisten „+“-Modelle)
- `tdhub-relay-arm64.tar` für ARM-Prozessoren (z. B. Realtek RTD1619B im DS223/DS423)

Welcher Prozessor drin ist, steht unter Systemsteuerung → Info-Center → Allgemein → CPU.

1. Im Paket-Zentrum **Container Manager** installieren.
2. Die passende `.tar`-Datei per File Station aufs NAS legen.
3. Container Manager → **Image** → **Hinzufügen** → **Aus Datei hinzufügen** → die `.tar` wählen.
   Danach steht `tdhub-relay` mit Tag `latest` in der Liste.
4. Das Image wählen → **Ausführen**: Name `tdhub-relay`, **automatischen Neustart aktivieren**,
   bei den Port-Einstellungen lokaler Port `24565` → Container-Port `24565`, Typ **TCP**.
   Sonst nichts ändern → Fertig. Unter Container → tdhub-relay → Protokoll steht
   `TD-Hub-Relay hört auf TCP-Port 24565`.
5. Im Router **TCP-Port 24565** an die IP-Adresse der Synology weiterleiten
   (FritzBox: Internet → Freigaben → Portfreigaben → Gerät hinzufügen → neue Freigabe,
   Protokoll TCP, Port 24565).
6. Falls die Firewall der Synology an ist (Systemsteuerung → Sicherheit → Firewall): Regel für
   TCP-Port 24565 erlauben.
7. Ändert sich die öffentliche IP des Anschlusses, DDNS einrichten: Systemsteuerung → Externer
   Zugriff → DDNS → Hinzufügen, Anbieter Synology, z. B. `name.synology.me`.

Statt Schritt 2–4 geht auch ein Projekt: `relay.py`, `Dockerfile` und `docker-compose.yml` in
einen Ordner legen, Container Manager → Projekt → Erstellen mit diesem Ordner.

Neue Version des Relays: neues `.tar` importieren, Container stoppen, löschen und wie in
Schritt 4 neu ausführen.

Im Spiel dann in der Lobby bei **Server** `name.synology.me` (oder die öffentliche IP) eintragen.
Ein anderer Port als 24565 geht als `name.synology.me:12345` (dann in Schritt 3 und 4 anpassen).

Prüfen von außen (z. B. vom Handy ohne WLAN): Lobby → Server eintragen → „Neue Sitzung hosten“.
Erscheint ein Code, läuft alles. „Server nicht erreichbar“ heißt meist: Portweiterleitung fehlt
oder der Anschluss hat keine eigene öffentliche IPv4 (CGNAT, im Router steht dann eine Adresse
aus 100.64.x.x).

## Ohne Docker

```
python3 relay.py --port=24565
```

Als Dienst unter Linux z. B. mit systemd (`ExecStart=/usr/bin/python3 -I /opt/tdhub/relay.py`).

## Grenzen und Sicherheit

- Der Container läuft als Nutzer nobody ohne Zugriff aufs NAS (keine Ordner eingebunden) und
  öffnet nur den einen Port; im Projekt zusätzlich nur lesbar und auf 128 MB begrenzt.
- Höchstens 200 Räume, 16 Verbindungen je IP-Adresse, 16 MB je Paket; stille Verbindungen
  fliegen nach 45 Sekunden raus (das Spiel schickt alle 10 Sekunden ein Lebenszeichen).
- Der Datenverkehr ist klein (Befehle und Spielstände, grob einige KB/s pro Spieler).
- Die Pakete laufen unverschlüsselt durch den Server, wie bisher bei der direkten Verbindung.
- Ist der Server aus, geht weiter das direkte Verbinden per IP (Feld „Server“ leer lassen).
