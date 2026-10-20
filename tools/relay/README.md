# TD-Hub-Relay (Spielen ohne Portfreigabe)

Der Relay ist ein kleiner Lobby-Server. Host und Mitspieler verbinden sich nur ausgehend mit ihm,
deshalb muss kein Spieler einen Port im Router freigeben. Der Host bekommt in der Lobby einen
Code aus fünf Zeichen (z. B. `K7QXM`), Mitspieler tippen ihn statt einer IP-Adresse ein. Der
Server leitet danach die Pakete des Spiels weiter.

- `relay.py`: der Server, nur Python-Standardbibliothek (ab 3.9), TCP-Port 24565
- `docker-compose.yml`: fertig für Synology Container Manager oder `docker compose`
- Gegenstück im Spiel: `scripts/net/relay_peer.gd`, Einstellung „Server“ in der Lobby
  (oder fest eingebaut über `Net.DEFAULT_RELAY` in `scripts/autoload/net.gd`)
- Test: `tools/run_tests.sh relay` (Host und zwei Mitspieler über einen lokalen Relay)

## Auf einer Synology einrichten

Voraussetzung: DSM 7.2 oder neuer und ein Modell mit **Container Manager** (die „+“- und
Business-Modelle; im Paket-Zentrum suchen, bei den „j“-Modellen fehlt er).

1. Im Paket-Zentrum **Container Manager** installieren.
2. In der File Station einen Ordner anlegen, z. B. `docker/tdhub-relay`, und `relay.py` und
   `docker-compose.yml` aus diesem Ordner hineinkopieren.
3. Container Manager → **Projekt** → **Erstellen**: Name `tdhub-relay`, Pfad = der Ordner aus
   Schritt 2, „vorhandene docker-compose.yml verwenden“ → Weiter → Fertig. Das Projekt lädt das
   Python-Image und startet. Unter Container → tdhub-relay → Protokoll steht
   `TD-Hub-Relay hört auf TCP-Port 24565`.
4. Im Router **TCP-Port 24565** an die IP-Adresse der Synology weiterleiten
   (FritzBox: Internet → Freigaben → Portfreigaben → Gerät hinzufügen → neue Freigabe,
   Protokoll TCP, Port 24565).
5. Falls die Firewall der Synology an ist (Systemsteuerung → Sicherheit → Firewall): Regel für
   TCP-Port 24565 erlauben.
6. Ändert sich die öffentliche IP des Anschlusses, DDNS einrichten: Systemsteuerung → Externer
   Zugriff → DDNS → Hinzufügen, Anbieter Synology, z. B. `name.synology.me`.

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

- Der Container läuft ohne Rechte (Nutzer nobody, nur lesbar, 128 MB), sieht vom NAS nur
  `relay.py` und öffnet nur den einen Port.
- Höchstens 200 Räume, 16 Verbindungen je IP-Adresse, 16 MB je Paket; stille Verbindungen
  fliegen nach 45 Sekunden raus (das Spiel schickt alle 10 Sekunden ein Lebenszeichen).
- Der Datenverkehr ist klein (Befehle und Spielstände, grob einige KB/s pro Spieler).
- Die Pakete laufen unverschlüsselt durch den Server, wie bisher bei der direkten Verbindung.
- Ist der Server aus, geht weiter das direkte Verbinden per IP (Feld „Server“ leer lassen).
