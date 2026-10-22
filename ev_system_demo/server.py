#!/usr/bin/env python3
r"""
Flask bridge between the browser dashboard and the MATLAB live simulation.

This project is MATLAB-function based, not Simulink based.  The backend keeps
the live simulation state inside the connected MATLAB session and advances it
one 0.05 s step for each dashboard request.  The simulation therefore runs
continuously while the browser is connected; its MATLAB log remains bounded by
ev_live_simulation.m.

Start MATLAB first (recommended):
    addpath(genpath('C:\Users\pc\Desktop\ev_system_demo\ev_system_demo'));
    matlab.engine.shareEngine('EVSystem');
cd "C:\Users\pc\Desktop\ev_system_demo\ev_system_demo"cd "C:\Users\pc\Desktop\ev_system_demo\ev_system_demo"
Then run:
    C:\Users\pc\AppData\Local\Programs\Python\Python312\python.exe server.py

Before starting the bridge, share the open MATLAB session:
    matlab.engine.shareEngine('EVSystem');
"""
import json
import math
import os
import threading
import time

from flask import Flask, jsonify, request, send_from_directory

DT = 0.05
OFF, PRECHARGE, READY, DRIVE, REGEN, CHARGING, FAULT, ECO = range(1, 9)
STATE_NAMES = {
    OFF: "OFF",
    PRECHARGE: "PRECHARGE",
    READY: "READY",
    DRIVE: "DRIVE",
    REGEN: "REGEN",
    CHARGING: "CHARGING",
    FAULT: "FAULT",
    ECO: "ECO",
}
TORQUE_STATES = {DRIVE, ECO, REGEN}
LATCH_MASK = (1 << 1) | (1 << 3) | (1 << 4) | (1 << 5) | (1 << 8)
PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))


def clamp(value, low, high):
    return max(low, min(high, value))


def parse_inputs(payload):
    """Validate browser JSON and normalize it to live-simulation controls."""
    payload = payload if isinstance(payload, dict) else {}
    inputs = payload.get("inputs") or {}
    position = payload.get("position") or {}

    def number(value, low, high):
        try:
            value = float(value)
        except (TypeError, ValueError):
            return None
        return value if math.isfinite(value) and low <= value <= high else None

    velocity = number(payload.get("velocity"), -5.0, 70.0)
    sensor_ok = velocity is not None and all(
        number(position.get(axis), -1e5, 1e5) is not None
        for axis in ("x", "z")
    )
    inject = number(payload.get("inject_dtc"), 0, 511)
    return {
        "velocity": velocity,
        "sensor_ok": sensor_ok,
        "power": bool(inputs.get("power")),
        "pedal": clamp(number(inputs.get("pedal_accel"), 0, 1) or 0.0, 0.0, 1.0),
        "brake": clamp(number(inputs.get("pedal_brake"), 0, 1) or 0.0, 0.0, 1.0),
        "estop": bool(inputs.get("estop_event")),
        "eco": bool(inputs.get("eco")),
        "plug": bool(inputs.get("charger_plugged")),
        "grade": clamp(number(inputs.get("grade_pct"), -20, 20) or 0.0, -20.0, 20.0) / 100.0,
        "reset": bool(inputs.get("reset_event")),
        "inject": int(inject or 0),
    }


class MatlabBackend:
    name = "matlab"
    unsupported_inputs = ()

    def __init__(self):
        self.lock = threading.Lock()
        self.connect_lock = threading.Lock()
        self.status = "starting"
        self.error = "Starting MATLAB engine..."
        self.eng = None
        self.unwired = list(self.unsupported_inputs)
        threading.Thread(target=self._connect, daemon=True).start()

    def _connect(self):
        with self.connect_lock:
            if self.status == "ready" and self.eng is not None:
                return
            self.status = "connecting"
            self.error = "Connecting to MATLAB engine..."
            try:
                import matlab.engine

                try:
                    self.eng = matlab.engine.connect_matlab("EVSystem")
                except Exception as exc:
                    raise RuntimeError(
                        "No shared MATLAB engine named EVSystem found. In MATLAB "
                        "run matlab.engine.shareEngine('EVSystem'), then retry."
                    ) from exc
                project = PROJECT_ROOT.replace("'", "''")
                self.eng.eval(
                    "addpath(genpath('{}')); "
                    "if exist('pmsm_foc_ekf_step','file') ~= 2, "
                    "error('EKF controller pmsm_foc_ekf_step.m is not on the MATLAB path.'); "
                    "end; "
                    "[ev_bridge_state, ev_bridge_sample] = ev_live_simulation('reset');".format(
                        project
                    ),
                    nargout=0,
                )
                self.status, self.error = "ready", ""
                print("[matlab] ready; live MATLAB function backend with EKF")
            except Exception as exc:
                self.eng = None
                self.status = "error"
                self.error = "{}: {}".format(type(exc).__name__, exc)
                print("[matlab] FAILED:", self.error)

    def _set_controls(self, controls):
        def matlab_bool(value):
            return "true" if value else "false"

        expression = (
            "ev_bridge_controls = struct("
            "'ignition',{ignition},"
            "'accelerator',{pedal},"
            "'brake',{brake},"
            "'plugged',{plug},"
            "'reset',{reset},"
            "'ecoMode',{eco},"
            "'emergencyStop',{estop},"
            "'sensorDropout',{sensor_dropout},"
            "'grade',{grade},"
            "'injectDtc',{inject},"
            "'networkLoss',false,"
            "'thermalDrift',false,"
            "'cellVoltageFault',false);".format(
                ignition=matlab_bool(controls["power"]),
                pedal=repr(controls["pedal"]),
                brake=repr(controls["brake"]),
                plug=matlab_bool(controls["plug"]),
                reset=matlab_bool(controls["reset"]),
                eco=matlab_bool(controls["eco"]),
                estop=matlab_bool(controls["estop"]),
                sensor_dropout=matlab_bool(not controls["sensor_ok"]),
                grade=repr(controls["grade"]),
                inject=controls["inject"],
            )
        )
        self.eng.eval(expression, nargout=0)

    def _sample_json(self):
        return self.eng.eval("jsonencode(ev_bridge_sample)", nargout=1)

    def reset(self):
        with self.lock:
            self.eng.eval(
                "[ev_bridge_state, ev_bridge_sample] = ev_live_simulation('reset');",
                nargout=0,
            )

    def step(self, controls):
        started = time.perf_counter()
        if self.status != "ready":
            # MATLAB may have been started after server.py. Retry here so the
            # bridge does not require a server restart to link the EKF.
            self._connect()
        if self.status != "ready" or self.eng is None:
            raise RuntimeError(self.error or "MATLAB not ready")
        if controls["reset"]:
            self.reset()
        with self.lock:
            self._set_controls(controls)
            self.eng.eval(
                "[ev_bridge_state, ev_bridge_sample] = "
                "ev_live_simulation('step', ev_bridge_state, ev_bridge_controls);",
                nargout=0,
            )
            raw = self._sample_json()
        sample = json.loads(raw)

        def scalar(value):
            if isinstance(value, list):
                return value[0] if value else None
            return value

        def text(value):
            value = scalar(value)
            return "" if value is None else str(value)

        output = {
            "state": int(scalar(sample["state"])),
            "soc_pct": float(scalar(sample["batterySoc"])) * 100,
            "velocity_mps": float(scalar(sample["vehicleSpeedKph"])) / 3.6,
            "torque_nm": float(scalar(sample["torqueActualNm"])),
            "dtc": int(scalar(sample["faultMask"])),
            "bus_load_pct": float(scalar(sample["networkBusLoadFraction"])) * 100,
            "motor_current_a": math.hypot(
                float(scalar(sample["idA"])), float(scalar(sample["iqA"]))
            ),
            "motor_power_kw": float(scalar(sample["motorPowerKw"])),
            "speed_limit_kph": float(scalar(sample["speedLimitKph"])),
            "dc_bus_v": float(scalar(sample["dcBusVoltageV"])),
            "battery_temp_c": float(scalar(sample["batteryTemperatureC"])),
            "motor_temp_c": float(scalar(sample["motorTemperatureC"])),
            "rs_true_ohm": float(scalar(sample["motorRsTrueOhm"])),
            "rs_nominal_ohm": float(scalar(sample["motorRsControlOhm"])),
            "rs_ekf_ohm": float(scalar(sample["motorRsEstimateOhm"])),
            "range_km": float(scalar(sample["rangeEstimateKm"])),
            "wh_per_km": float(scalar(sample["rangeConsumptionWhPerKm"])),
            "regen_wh": float(scalar(sample["cumulativeEnergyRecoveredWh"])),
            "charger_kw": float(scalar(sample["chargerPowerKw"])),
            "charger_status": text(sample["chargerStatus"]),
            "drive_mode": text(sample["driveMode"]),
            "sensor_ok": bool(scalar(sample["sensorValid"])),
            "contactor_closed": bool(scalar(sample["contactorClosed"])),
            "fault_latched": bool(scalar(sample["faultActive"])),
            "eco_active": bool(scalar(sample["ecoActive"])),
            "range_estimate_km": float(scalar(sample["rangeEstimateKm"])),
            "battery_current_a": float(scalar(sample["batteryCurrentA"])),
            "energy_recovered_wh": float(scalar(sample["energyRecoveredWh"])),
            "network_online": bool(scalar(sample["networkOnline"])),
            "interlock_ok": bool(scalar(sample["interlockOk"])),
            "parameter_status": text(sample["parameterStatus"]),
            "assumptions": text(sample["assumptions"]),
        }
        state = int(output["state"])
        dtc = int(output["dtc"])
        output.update(
            ok=True,
            backend=self.name,
            state_name=STATE_NAMES.get(state, "?"),
            unwired_inputs=self.unwired,
            torque_permitted=state in TORQUE_STATES and not dtc & LATCH_MASK,
            contactors_closed=output["contactor_closed"],
            fault_latched=bool(dtc & LATCH_MASK) or output["fault_latched"],
            dtc_bits=[(dtc >> bit) & 1 for bit in range(9)],
            charger_status=output["charger_status"],
            drive_mode=output["drive_mode"],
            matlab_ms=round((time.perf_counter() - started) * 1000, 1),
        )
        return output


BACKEND = MatlabBackend()
app = Flask(__name__)


@app.after_request
def cors(response):
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type"
    return response


@app.route("/")
def index():
    return send_from_directory(PROJECT_ROOT, "index.html")


@app.route("/api/health")
def health():
    return jsonify(
        ok=BACKEND.status == "ready",
        backend=BACKEND.name,
        status=BACKEND.status,
        error=BACKEND.error,
        dt=DT,
        unwired_inputs=BACKEND.unwired,
    )


@app.route("/api/telemetry", methods=["POST", "OPTIONS"])
def telemetry():
    if request.method == "OPTIONS":
        return ("", 204)
    payload = request.get_json(silent=True)
    try:
        output = BACKEND.step(parse_inputs(payload))
    except Exception as exc:
        return jsonify(ok=False, status=BACKEND.status, error=str(exc)), 503
    output["seq"] = (payload or {}).get("seq")
    output["server_ts"] = time.time()
    return jsonify(output)


if __name__ == "__main__":
    print("EV bridge on http://127.0.0.1:5000 backend=matlab live-functions")
    app.run(host="127.0.0.1", port=5000, threaded=True)
