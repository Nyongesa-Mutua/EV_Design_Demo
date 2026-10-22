function [motor, batteryCurrentA] = motor_step(motor, torqueRequestNm, speedRadS, vdcV, temperatureC, dt, P)
% MOTOR_STEP Legacy torque-lag surrogate retained for reference only.
% Integrated runs now use pmsm_foc_ekf_step for dq current control and plant dynamics.
motor.rsOhm = P.motorResistanceOhm * (1 + P.motorThermalCoefficient * (temperatureC - 25));
motor.fluxWb = P.motorFluxWb * max(0.75, 1 - 0.0011 * (temperatureC - 25));
motor.torqueNm = motor.torqueNm + (torqueRequestNm - motor.torqueNm) * min(1, dt / 0.12);
motor.iqA = motor.torqueNm / P.motorTorqueConstantNmPerA;
motor.idA = 0;
motor.currentA = hypot(motor.idA, motor.iqA);
mechanicalPowerW = motor.torqueNm * speedRadS;
electricalPowerW = mechanicalPowerW / max(P.motorEfficiency, 0.5);
batteryCurrentA = electricalPowerW / max(vdcV, 100);
motor.speedRpm = speedRadS * 60 / (2*pi);
end
