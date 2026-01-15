"""
drops_esp_alt.py
Reliable Arduino serial reader + local Flask API for DROPS.

Usage:
  python drops_esp_alt.py
Dependencies:
  pip install pyserial flask flask-cors
"""

import re
import time
import threading
import logging
from datetime import datetime
from typing import Optional, Tuple

import serial
import serial.tools.list_ports
from flask import Flask, jsonify, make_response

# ------------------- CONFIG -------------------
SERIAL_PORT = None          # None = auto-detect, or '/dev/ttyUSB0' or 'COM3'
BAUD = 9600
SERIAL_TIMEOUT = 1.0       # seconds
API_HOST = "0.0.0.0"
API_PORT = 5000
READ_LOOP_DELAY = 0.05     # 50 ms

# Logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

# Shared state
_latest_value_lock = threading.Lock()
_latest_value: Optional[dict] = None  # {'water_level_cm': float, 'distance_cm': Optional[float], 'timestamp': str}

# ------------------- SERIAL UTIL -------------------
def find_serial_port() -> Optional[str]:
    ports = list(serial.tools.list_ports.comports())
    if not ports:
        logging.warning("No serial ports found.")
        return None
    # prefer Arduino-like devices
    for p in ports:
        desc = (p.description or "").lower()
        if "arduino" in desc or "usb serial" in desc or "ch340" in desc or "cp210" in desc:
            logging.info(f"Auto-detected serial port: {p.device} ({p.description})")
            return p.device
    if len(ports) == 1:
        logging.info(f"Single port found: {ports[0].device}")
        return ports[0].device
    logging.info(f"Multiple ports found, defaulting to {ports[0].device}")
    return ports[0].device

def parse_line(line: str) -> Optional[Tuple[Optional[float], float]]:
    """
    Parse lines like "distance_cm,water_level_cm" or just "water_level_cm".
    Returns (distance_cm_or_None, water_level_cm)
    """
    line = line.strip()
    if not line:
        return None
    try:
        m = re.search(r"(-?\d+\.?\d*)\s*[, ]\s*(-?\d+\.?\d*)", line)
        if m:
            return float(m.group(1)), float(m.group(2))
        m2 = re.search(r"(-?\d+\.?\d*)", line)
        if m2:
            return None, float(m2.group(1))
    except Exception:
        return None
    return None

# ------------------- SERIAL READER THREAD -------------------
class SerialReader(threading.Thread):
    def __init__(self, port: Optional[str], baud: int, timeout: float):
        super().__init__(daemon=True)
        self.port = port
        self.baud = baud
        self.timeout = timeout
        self._stop_event = threading.Event()
        self.ser: Optional[serial.Serial] = None

    def open_serial(self):
        while not self._stop_event.is_set():
            try:
                port_to_use = self.port or find_serial_port()
                if not port_to_use:
                    logging.warning("No serial port found. Retrying in 2s...")
                    time.sleep(2)
                    continue
                self.ser = serial.Serial(port_to_use, self.baud, timeout=self.timeout)
                time.sleep(1.0)  # allow Arduino to reset
                logging.info(f"Serial port opened: {port_to_use}")
                return
            except Exception as e:
                logging.exception(f"Failed to open serial: {e}. Retrying in 2s...")
                if self.ser and self.ser.is_open:
                    try: self.ser.close()
                    except: pass
                time.sleep(2)

    def run(self):
        while not self._stop_event.is_set():
            if not self.ser or not self.ser.is_open:
                self.open_serial()
            try:
                raw = self.ser.readline()
                if not raw:
                    time.sleep(READ_LOOP_DELAY)
                    continue
                try:
                    line = raw.decode("utf-8", errors="ignore").strip()
                except:
                    line = raw.decode("latin1", errors="ignore").strip()
                if not line:
                    continue
                parsed = parse_line(line)
                if parsed:
                    distance_cm, water_level_cm = parsed
                    ts = datetime.utcnow().isoformat() + "Z"
                    with _latest_value_lock:
                        global _latest_value
                        _latest_value = {
                            "water_level_cm": float(water_level_cm),
                            "distance_cm": None if distance_cm is None else float(distance_cm),
                            "timestamp": ts
                        }
                    logging.debug(f"Updated water={water_level_cm}cm distance={distance_cm}")
                else:
                    logging.debug(f"Ignored line: {line}")
                time.sleep(0.001)  # tiny sleep to keep loop tight
            except serial.SerialException:
                logging.exception("SerialException, reconnecting...")
                try: self.ser.close()
                except: pass
                self.ser = None
                time.sleep(1)
            except Exception:
                logging.exception("Unexpected error in serial loop")
                time.sleep(0.5)

    def stop(self):
        self._stop_event.set()
        if self.ser and self.ser.is_open:
            try: self.ser.close()
            except: pass

# ------------------- FLASK API -------------------
app = Flask(__name__)
try:
    from flask_cors import CORS
    CORS(app)
except ImportError:
    logging.info("flask_cors not installed; using manual CORS headers.")

@app.route("/water", methods=["GET"])
def get_water():
    with _latest_value_lock:
        data = _latest_value
    if data is None:
        resp = make_response(jsonify({"error": "no_data_yet"}), 503)
    else:
        resp = make_response(jsonify(data), 200)
    resp.headers["Access-Control-Allow-Origin"] = "*"
    return resp

# ------------------- MAIN -------------------
def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", help="Serial port (COMx or /dev/ttyUSBx). If omitted, auto-detect.")
    parser.add_argument("--baud", type=int, default=BAUD)
    parser.add_argument("--api-port", type=int, default=API_PORT)
    args = parser.parse_args()

    reader = SerialReader(port=args.port, baud=args.baud, timeout=SERIAL_TIMEOUT)
    reader.start()
    try:
        logging.info(f"Starting Flask API at http://{API_HOST}:{args.api_port}")
        app.run(host=API_HOST, port=args.api_port, debug=False, use_reloader=False)
    except KeyboardInterrupt:
        logging.info("Shutting down...")
    finally:
        reader.stop()
        reader.join(timeout=2)
        logging.info("Exited.")

if __name__ == "__main__":
    main()
