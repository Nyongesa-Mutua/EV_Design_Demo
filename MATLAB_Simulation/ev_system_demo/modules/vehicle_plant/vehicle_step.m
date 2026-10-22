function vehicle = vehicle_step(vehicle, motorTorqueNm, frictionBrakeFraction, grade, dt, P)
% VEHICLE_STEP Longitudinal road-load, grade, driveline, and friction-brake model.
speed = max(vehicle.speedMps, 0);
wheelForceN = motorTorqueNm * P.gearRatio / P.wheelRadiusM;
rollingN = P.rollingCoefficient * P.massKg * P.gravity;
aeroN = 0.5 * P.airDensity * P.dragAreaM2 * speed^2;
gradeN = P.massKg * P.gravity * grade;
frictionN = frictionBrakeFraction * P.maxFrictionBrakeN;
accel = (wheelForceN - rollingN - aeroN - gradeN - frictionN) / P.massKg;
vehicle.speedMps = max(0, speed + accel * dt);
vehicle.positionM = vehicle.positionM + vehicle.speedMps * dt;
vehicle.motorSpeedRadS = vehicle.speedMps * P.gearRatio / P.wheelRadiusM;
vehicle.speedKph = vehicle.speedMps * 3.6;
vehicle.accelerationMps2 = accel;
end
