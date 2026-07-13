#!/usr/bin/env python3
"""
MAVLink → WebSocket テレメトリブリッジ

ドローン(ArduPilot / PX4)からのMAVLinkテレメトリを受信し、
GCS UI (index.html) が読めるJSONに変換して ws://0.0.0.0:8765 で配信する。
UI側からのコマンド({"cmd": "RTL"} など)はMAVLinkコマンドに変換して送る。

依存: pip install pymavlink websockets

接続例:
  テレメトリ無線(SiK等)  : python bridge.py --mav /dev/ttyUSB0 --baud 57600
  SITL / UDP             : python bridge.py --mav udp:0.0.0.0:14550
"""
import argparse
import asyncio
import json
import math
import threading

import websockets
from pymavlink import mavutil

state = {
    "t": 0.0, "phase": "PAD", "armed": False,
    "x": 0.0, "y": 0.0, "z": 0.0, "vz": 0.0, "spd": 0.0,
    "hdg": 0.0, "roll": 0.0, "pitch": 0.0,
    "batt": 0.0, "volt": 0.0, "sats": 0, "hdop": 99.0,
    "az": 0.0, "el": 0.0, "rssi": -120, "lq": 0, "rng": 0.0,
    "lat": 0.0, "lon": 0.0, "live": True, "pkt": 0,
}
home = {"lat": None, "lon": None}
clients: set = set()
pkt_count = 0

MODE_MAP = {"HOLD": "LOITER", "RESUME": "AUTO", "RTL": "RTL", "LAND": "LAND"}


def update_antenna():
    """ホーム(地上局)から見た方位角・仰角・距離を計算する"""
    if home["lat"] is None or state["lat"] == 0:
        return
    dlat = (state["lat"] - home["lat"]) * 111320.0
    dlon = (state["lon"] - home["lon"]) * 111320.0 * math.cos(math.radians(home["lat"]))
    rng_h = math.hypot(dlat, dlon)
    state["x"], state["y"] = dlon, dlat
    state["rng"] = math.hypot(rng_h, state["z"])
    state["az"] = (math.degrees(math.atan2(dlon, dlat)) + 360) % 360
    state["el"] = 90.0 if rng_h < 1 else math.degrees(math.atan2(state["z"], rng_h))


def mav_reader(mav):
    """MAVLink受信スレッド: メッセージ種別ごとにstateへ反映"""
    global pkt_count
    while True:
        msg = mav.recv_match(blocking=True, timeout=5)
        if msg is None:
            continue
        t = msg.get_type()
        pkt_count += 1
        if t == "GLOBAL_POSITION_INT":
            state["lat"] = msg.lat / 1e7
            state["lon"] = msg.lon / 1e7
            state["z"] = msg.relative_alt / 1000.0
            state["vz"] = -msg.vz / 100.0
            state["hdg"] = msg.hdg / 100.0
            if home["lat"] is None:
                home["lat"], home["lon"] = state["lat"], state["lon"]
            update_antenna()
        elif t == "VFR_HUD":
            state["spd"] = msg.groundspeed
        elif t == "ATTITUDE":
            state["roll"] = math.degrees(msg.roll)
            state["pitch"] = math.degrees(msg.pitch)
        elif t == "SYS_STATUS":
            state["volt"] = msg.voltage_battery / 1000.0
            state["batt"] = max(0, msg.battery_remaining)
        elif t == "GPS_RAW_INT":
            state["sats"] = msg.satellites_visible
            state["hdop"] = msg.eph / 100.0
        elif t == "RADIO_STATUS":
            state["rssi"] = msg.rssi - 127  # SiK: 0-254 → おおよそのdBm
            state["lq"] = round((1 - msg.rxerrors / max(msg.fixed + msg.rxerrors, 1)) * 100)
        elif t == "HEARTBEAT":
            state["armed"] = bool(msg.base_mode & mavutil.mavlink.MAV_MODE_FLAG_SAFETY_ARMED)
            mode = mavutil.mode_string_v10(msg)
            state["phase"] = {
                "RTL": "RTL", "LAND": "LANDING", "LOITER": "HOLD",
                "AUTO": "CRUISE", "GUIDED": "CRUISE",
            }.get(mode, "PAD" if state["z"] < 1 else "CRUISE")


def send_command(mav, cmd):
    """UIからのコマンドをMAVLinkに変換"""
    if cmd == "ARM":
        mav.arducopter_arm()
    elif cmd == "LAUNCH":
        mav.set_mode("GUIDED")
        mav.mav.command_long_send(
            mav.target_system, mav.target_component,
            mavutil.mavlink.MAV_CMD_NAV_TAKEOFF, 0, 0, 0, 0, 0, 0, 0, 120)
    elif cmd in MODE_MAP:
        mav.set_mode(MODE_MAP[cmd])


async def ws_handler(ws, mav):
    clients.add(ws)
    try:
        async for raw in ws:
            try:
                data = json.loads(raw)
                if "cmd" in data:
                    print("CMD:", data["cmd"])
                    send_command(mav, data["cmd"])
            except (json.JSONDecodeError, KeyError):
                pass
    finally:
        clients.discard(ws)


async def broadcaster():
    """10HzでテレメトリJSONを全クライアントへ配信"""
    global pkt_count
    t0 = asyncio.get_event_loop().time()
    while True:
        state["t"] = asyncio.get_event_loop().time() - t0
        state["pkt"] = pkt_count
        pkt_count = 0
        if clients:
            payload = json.dumps(state)
            await asyncio.gather(*(c.send(payload) for c in clients), return_exceptions=True)
        await asyncio.sleep(0.1)


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mav", default="udp:0.0.0.0:14550")
    ap.add_argument("--baud", type=int, default=57600)
    ap.add_argument("--port", type=int, default=8765)
    args = ap.parse_args()

    print(f"MAVLink: {args.mav} / WebSocket: ws://0.0.0.0:{args.port}")
    mav = mavutil.mavlink_connection(args.mav, baud=args.baud)
    mav.wait_heartbeat()
    print("Heartbeat OK — vehicle detected")

    threading.Thread(target=mav_reader, args=(mav,), daemon=True).start()
    async with websockets.serve(lambda ws: ws_handler(ws, mav), "0.0.0.0", args.port):
        await broadcaster()


if __name__ == "__main__":
    asyncio.run(main())
