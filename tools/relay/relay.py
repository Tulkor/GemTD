#!/usr/bin/env python3
"""TD-Hub-Relay: Lobby-Server, über den Spieler ohne Portfreigabe zusammen spielen.

Alle Spieler bauen nur eine ausgehende TCP-Verbindung zu diesem Server auf. Der Host eröffnet einen
Raum und bekommt einen kurzen Code, Mitspieler treten mit dem Code bei, danach leitet der Server
die Pakete des Spiels (Godot-Multiplayer) zwischen den Spielern im Raum weiter.
Gegenstück im Spiel: scripts/net/relay_peer.gd. Nur Python-Standardbibliothek.

  python3 relay.py [--port=24565] [--code=TEST1]   (--code: fester Code für den ersten Raum, nur Tests)

Rahmen: u32 Länge (little endian), dann u8 Typ und Inhalt.
  Spieler -> Server: HOST(1) "TDHUB1|max" · JOIN(2) "TDHUB1|CODE|wunsch_id" · DATA(3) i32 ziel, u8 kanal,
                     u8 modus, daten · KICK(4) i32 id · PING(5)
  Server -> Spieler: WELCOME(10) i32 id, code · PEER_ADD(11) i32 · PEER_DEL(12) i32
                     · DATA(13) i32 absender, u8 kanal, u8 modus, daten · ERROR(14) text · PONG(15)
Ziel wie in Godot: 0 = alle anderen, > 0 = dieser Spieler, < 0 = alle außer -ziel.
"""
import argparse
import asyncio
import logging
import random
import struct
import time

VERSION = "TDHUB1"
HOST, JOIN, DATA, KICK, PING = 1, 2, 3, 4, 5
WELCOME, PEER_ADD, PEER_DEL, DATA_IN, ERROR, PONG = 10, 11, 12, 13, 14, 15
MAX_FRAME = 16 * 1024 * 1024
MAX_ROOMS = 200
MAX_PER_IP = 16
IDLE_TIMEOUT = 45.0
CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"   # ohne 0/O, 1/I

log = logging.getLogger("relay")
rooms: dict[str, "Room"] = {}
per_ip: dict[str, int] = {}
fixed_code = ""


class Client:
    def __init__(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
        self.reader = reader
        self.writer = writer
        self.ip = (writer.get_extra_info("peername") or ("?",))[0]
        self.room: "Room | None" = None
        self.id = 0
        self.last = time.monotonic()

    def send(self, kind: int, body: bytes = b"") -> None:
        if self.writer.is_closing():
            return
        if self.writer.transport.get_write_buffer_size() > 4 * MAX_FRAME:
            self.close()   # liest nicht mehr mit, sonst wächst der Puffer endlos
            return
        self.writer.write(struct.pack("<IB", len(body) + 1, kind) + body)

    def close(self) -> None:
        if not self.writer.is_closing():
            self.writer.close()


class Room:
    def __init__(self, code: str, host: Client, max_players: int):
        self.code = code
        self.max = max(2, min(max_players, 16))
        self.members: dict[int, Client] = {1: host}

    def new_id(self, wish: int) -> int:
        if 1 < wish < 2**31 and wish not in self.members:
            return wish
        while True:
            i = random.randint(2, 2**31 - 1)
            if i not in self.members:
                return i


def new_code() -> str:
    global fixed_code
    if fixed_code and fixed_code not in rooms:
        code, fixed_code = fixed_code, ""
        return code
    while True:
        code = "".join(random.choice(CODE_CHARS) for _ in range(5))
        if code not in rooms:
            return code


def handle(c: Client, kind: int, body: bytes) -> bool:
    """Einen Rahmen verarbeiten; False = Verbindung schließen."""
    if kind == PING:
        c.send(PONG)
        return True
    if c.room is None:
        parts = body.decode("utf-8", "replace").split("|")
        if not parts or parts[0] != VERSION:
            c.send(ERROR, b"version")
            return False
        if kind == HOST:
            if len(rooms) >= MAX_ROOMS:
                c.send(ERROR, b"full_server")
                return False
            code = new_code()
            c.room = rooms[code] = Room(code, c, int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else 8)
            c.id = 1
            c.send(WELCOME, struct.pack("<i", 1) + code.encode())
            log.info("Raum %s eröffnet (%s, %d Räume)", code, c.ip, len(rooms))
            return True
        if kind == JOIN and len(parts) >= 2:
            room = rooms.get(parts[1].strip().upper())
            if room is None:
                c.send(ERROR, b"unknown_code")
                return False
            if len(room.members) >= room.max:
                c.send(ERROR, b"room_full")
                return False
            wish = int(parts[2]) if len(parts) > 2 and parts[2].isdigit() else 0
            c.id = room.new_id(wish)
            c.send(WELCOME, struct.pack("<i", c.id) + room.code.encode())
            for other in room.members.values():
                other.send(PEER_ADD, struct.pack("<i", c.id))
                c.send(PEER_ADD, struct.pack("<i", other.id))
            room.members[c.id] = c
            c.room = room
            return True
        c.send(ERROR, b"protocol")
        return False
    room = c.room
    if kind == DATA and len(body) >= 6:
        target, = struct.unpack_from("<i", body)
        out = struct.pack("<iBB", c.id, body[4], body[5]) + body[6:]
        if target > 0:
            dest = room.members.get(target)
            if dest is not None and dest is not c:
                dest.send(DATA_IN, out)
        else:
            for m in room.members.values():
                if m is not c and m.id != -target:
                    m.send(DATA_IN, out)
        return True
    if kind == KICK and c.id == 1 and len(body) >= 4:
        target, = struct.unpack_from("<i", body)
        dest = room.members.get(target)
        if dest is not None and dest is not c:
            dest.close()
        return True
    return True


def leave(c: Client) -> None:
    room = c.room
    c.room = None
    if room is None or room.members.get(c.id) is not c:
        return
    del room.members[c.id]
    if c.id == 1:
        # Host weg: Raum zu, alle anderen trennen (wie ein beendeter ENet-Server)
        rooms.pop(room.code, None)
        for m in list(room.members.values()):
            m.room = None
            m.close()
        log.info("Raum %s geschlossen (%d Räume)", room.code, len(rooms))
    else:
        for m in room.members.values():
            m.send(PEER_DEL, struct.pack("<i", c.id))


async def serve(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
    c = Client(reader, writer)
    if per_ip.get(c.ip, 0) >= MAX_PER_IP:
        writer.close()
        return
    per_ip[c.ip] = per_ip.get(c.ip, 0) + 1
    try:
        while True:
            head = await asyncio.wait_for(reader.readexactly(4), IDLE_TIMEOUT)
            size, = struct.unpack("<I", head)
            if size < 1 or size > MAX_FRAME:
                break
            frame = await asyncio.wait_for(reader.readexactly(size), IDLE_TIMEOUT)
            c.last = time.monotonic()
            if not handle(c, frame[0], frame[1:]):
                await writer.drain()
                break
            await writer.drain()
    except (asyncio.IncompleteReadError, asyncio.TimeoutError, ConnectionError, OSError):
        pass
    finally:
        leave(c)
        per_ip[c.ip] -= 1
        if per_ip[c.ip] <= 0:
            del per_ip[c.ip]
        c.close()


async def main() -> None:
    global fixed_code
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--port", type=int, default=24565)
    ap.add_argument("--code", default="", help="fester Code für den ersten Raum (Tests)")
    args = ap.parse_args()
    fixed_code = args.code.upper()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%Y-%m-%d %H:%M:%S")
    server = await asyncio.start_server(serve, host=None, port=args.port)
    log.info("TD-Hub-Relay hört auf TCP-Port %d", args.port)
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
