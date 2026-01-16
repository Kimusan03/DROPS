"""
drops_esp_alt.py
Fixed & Robust Arduino serial reader + local Flask API for DROPS.
"""

import re
import time
import threading
import logging
from datetime import datetime
from typing import Optional, Tuple
from flask_cors import CORS
import serial
import serial.tools.list_ports
from flask import Flask, jsonify, make_response

app = Flask(__name__)
CORS(app)

# ------------------- CONFIG -------------------
SERIAL_PORT = None           # None = auto-detect
BAUD = 9600
SERIAL_TIMEOUT = 1.0         # seconds
API_HOST = "0.0.0.0"         # Critical for LAN access
API_PORT = 5000
READ_LOOP_DELAY = 0.05       # 50 ms

# Logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

# Shared state
_latest_value_lock = threading.Lock()
_latest_value: Optional[dict] = None  

# ------------------- SERIAL UTIL -------------------
def find_serial_port() -> Optional[str]:
    ports = list(serial.tools.list_ports.comports())
    if not ports:
        logging.warning("No serial ports found. Check USB connection.")
        return None
    for p in ports:
        desc = (p.description or "").lower()
        # Look for common Arduino/USB-Serial drivers
        if any(keyword in desc for keyword in ["arduino", "usb", "ch340", "cp210", "prolific"]):
            logging.info(f"Auto-detected serial port: {p.device} ({p.description})")
            return p.device
    
    # Fallback to the first available port if no keywords match
    return ports[0].device

def parse_line(line: str) -> Optional[Tuple[Optional[float], float]]:
    """
    Parses 'distance, water_level' or just 'water_level'.
    Handles extra whitespace or malformed text gracefully.
    """
    line = line.strip()
    if not line:
        return None
    try:
        # Regex to find numbers even if mixed with text (e.g., "Dist: 10.5 cm, Level: 5.0")
        numbers = re.findall(r"[-+]?\d*\.\d+|\d+", line)
        if len(numbers) >= 2:
            return float(numbers[0]), float(numbers[1])
        elif len(numbers) == 1:
            return None, float(numbers[0])
    except Exception as e:
        logging.error(f"Parsing error on line '{line}': {e}")
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
                    time.sleep(2)
                    continue
                
                # Close existing if it's messy
                if self.ser and self.ser.is_open:
                    self.ser.close()

                self.ser = serial.Serial(port_to_use, self.baud, timeout=self.timeout)
                # Flush buffers to clear old junk data
                self.ser.reset_input_buffer()
                time.sleep(2.0)  # Essential for Arduino reboot cycle
                logging.info(f"CONNECTED to {port_to_use}")
                return
            except Exception as e:
                logging.warning(f"Connection failed: {e}. Retrying...")
                time.sleep(2)

    def run(self):
        while not self._stop_event.is_set():
            if not self.ser or not self.ser.is_open:
                self.open_serial()
            
            try:
                if self.ser and self.ser.is_open:
                    raw = self.ser.readline()
                    if not raw:
                        continue
                    
                    line = raw.decode("utf-8", errors="ignore").strip()
                    parsed = parse_line(line)
                    
                    if parsed:
                        dist, water = parsed
                        ts = datetime.now().isoformat()
                        with _latest_value_lock:
                            global _latest_value
                            _latest_value = {
                                "water_level_cm": float(water),
                                "distance_cm": float(dist) if dist is not None else None,
                                "timestamp": ts
                            }
            except Exception as e:
                logging.error(f"Runtime serial error: {e}")
                if self.ser:
                    try: self.ser.close()
                    except: pass
                time.sleep(1)

    def stop(self):
        self._stop_event.set()
        if self.ser:
            try: self.ser.close()
            except: pass

# ------------------- FLASK API -------------------
app = Flask(__name__)

def add_cors_headers(response):
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type"
    return response

@app.route("/water", methods=["GET", "OPTIONS"])
def get_water():
    # Handle pre-flight for Flutter Web/Mobile
    if flask_request_method() == "OPTIONS":
        return add_cors_headers(make_response("", 204))

    with _latest_value_lock:
        data = _latest_value
    
    if data is None:
        resp = make_response(jsonify({"error": "Waiting for Arduino data..."}), 503)
    else:
        resp = make_response(jsonify(data), 200)
    
    return add_cors_headers(resp)

def flask_request_method():
    # Helper to check method safely
    from flask import request
    return request.method

# ------------------- MAIN -------------------
def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", help="Serial port. If omitted, auto-detect.")
    parser.add_argument("--baud", type=int, default=BAUD)
    parser.add_argument("--api-port", type=int, default=API_PORT)
    args = parser.parse_args()

    reader = SerialReader(port=args.port, baud=args.baud, timeout=SERIAL_TIMEOUT)
    reader.start()

    try:
        logging.info(f"API ONLINE: http://{API_HOST}:{args.api_port}/water")
        # Threaded=True allows multiple Flutter clients to poll at once
        app.run(host=API_HOST, port=args.api_port, debug=False, use_reloader=False, threaded=True)
    except KeyboardInterrupt:
        logging.info("Shutting down...")
    finally:
        reader.stop()
        logging.info("Serial Reader stopped.")

if __name__ == "__main__":
    main()