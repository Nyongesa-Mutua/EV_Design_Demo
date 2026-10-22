function [controller, torqueRequestNm] = speed_controller_step(controller, targetSpeedKph, measuredSpeedKph, dt, P)
% SPEED_CONTROLLER_STEP PI speed controller with torque saturation/anti-windup.
% Positive torque accelerates; negative request is reserved for regen/braking.
if ~isfield(controller,'integralError'), controller.integralError = 0; end
errorKph = max(0,targetSpeedKph)-max(0,measuredSpeedKph);
rawTorque = P.speedControllerKpNmPerKph*errorKph + ...
    P.speedControllerKiNmPerKphS*controller.integralError;
torqueRequestNm = min(max(rawTorque,0),P.maxDriveTorqueNm);
controller.integralError = controller.integralError + ...
    (errorKph + P.speedControllerAntiWindup*(torqueRequestNm-rawTorque)/ ...
    max(P.speedControllerKpNmPerKph,eps))*dt;
controller.integralError = min(max(controller.integralError,-30),150);
controller.errorKph = errorKph;
controller.rawTorqueNm = rawTorque;
controller.torqueRequestNm = torqueRequestNm;
controller.targetSpeedKph = max(0,targetSpeedKph);
end
