function [motor, batteryCurrentA, control] = pmsm_foc_ekf_step(motor, torqueRequestNm, speedRadS, vdcV, temperatureC, outerDt, P, mode)
% PMSM_FOC_EKF_STEP Closed-loop dq-current controller, PMSM plant and optional EKF.
% This software-in-the-loop model substeps the electrical plant at P.motorSampleTime.
% mode is 'fixed' (nominal Rs/flux feed-forward) or 'ekf' (adaptive estimates).
% It is not a switching inverter, production controller, or hardware validation.
if nargin < 8 || isempty(mode), mode = 'ekf'; end
if ~any(strcmp(mode,{'fixed','ekf'}))
    error('Controller mode must be ''fixed'' or ''ekf''.');
end
if ~isfield(motor,'ekfX')
    motor.idA = 0; motor.iqA = 0; motor.intD = 0; motor.intQ = 0;
    motor.idMeasuredA = 0; motor.iqMeasuredA = 0;
    motor.vdApplied = 0; motor.vqApplied = 0; motor.ekfX = [0;0;P.motorResistanceOhm;P.motorFluxWb];
    motor.ekfCov = diag([4,4,(0.25*P.motorResistanceOhm)^2,(0.15*P.motorFluxWb)^2]);
    motor.ekfUpdates = 0; motor.ekfEnabled = false; motor.ekfHealthy = true;
    motor.sampleCounter = 0;
end
Ts = P.motorSampleTime;
steps = max(1,round(outerDt/Ts));
Ts = outerDt/steps;
we = P.motorPolePairs*speedRadS;
rsTrue = P.motorResistanceOhm*(1+P.motorThermalCoefficient*(temperatureC-25));
fluxTrue = P.motorFluxWb*max(0.75,1-0.0011*(temperatureC-25));
if abs(torqueRequestNm) < 0.01 && abs(speedRadS) < 0.5 && ...
        hypot(motor.idA,motor.iqA) < 0.1
    motor.idA = 0; motor.iqA = 0; motor.currentA = 0; motor.torqueNm = 0;
    motor.rsOhm = rsTrue; motor.fluxWb = fluxTrue;
    motor.temperatureC = temperatureC; motor.speedRpm = 0;
    batteryCurrentA = 0;
    control.idReferenceA = 0; control.iqReferenceA = 0;
    control.idFeedbackA = 0; control.iqFeedbackA = 0;
    control.rsControlOhm = P.motorResistanceOhm;
    control.fluxControlWb = P.motorFluxWb;
    control.rsEstimateOhm = motor.ekfX(3);
    control.fluxEstimateWb = motor.ekfX(4);
    control.ekfEnabled = strcmp(mode,'ekf');
    control.ekfAdaptationEnabled = false;
    control.ekfUpdates = motor.ekfUpdates;
    control.mode = mode; control.ekfHealthy = motor.ekfHealthy;
    return;
end
if strcmp(mode,'ekf')
    rsControl = motor.ekfX(3);
    fluxControl = motor.ekfX(4);
else
    rsControl = P.motorResistanceOhm;
    fluxControl = P.motorFluxWb;
end
idRef = 0;
iqRef = torqueRequestNm/(1.5*P.motorPolePairs*max(fluxControl,0.5*P.motorFluxWb));
iqRef = min(max(iqRef,-P.maxMotorCurrentA),P.maxMotorCurrentA);
Vlim = max(10,0.95*vdcV/sqrt(3));
adaptationEnabled = false;
for n = 1:steps
    % EKF time update using applied dq voltage and the PMSM current equations.
    if strcmp(mode,'ekf')
        [motor.ekfX,motor.ekfCov] = observer_predict(motor.ekfX,motor.ekfCov, ...
            motor.vdApplied,motor.vqApplied,we,P.motorLd,P.motorLq,Ts,P);
        if ~observer_is_healthy(motor.ekfX,motor.ekfCov)
            motor = reset_observer(motor,P);
        end
        rsControl = motor.ekfX(3);
        fluxControl = motor.ekfX(4);
        iqRef = torqueRequestNm/(1.5*P.motorPolePairs*max(fluxControl,0.5*P.motorFluxWb));
        iqRef = min(max(iqRef,-P.maxMotorCurrentA),P.maxMotorCurrentA);
    end

    motor.sampleCounter = motor.sampleCounter+1;
    motor.idMeasuredA = quantize_current(motor.idA+P.motorCurrentSensorOffsetA+ ...
        P.motorCurrentSensorNoiseA*sin(0.71*motor.sampleCounter),P.currentAdcLsbA);
    motor.iqMeasuredA = quantize_current(motor.iqA+P.motorCurrentSensorOffsetA+ ...
        P.motorCurrentSensorNoiseA*cos(0.53*motor.sampleCounter),P.currentAdcLsbA);
    errD = idRef-motor.idMeasuredA;
    errQ = iqRef-motor.iqMeasuredA;
    vdRaw = P.motorKpD*errD+motor.intD+rsControl*idRef-we*P.motorLq*iqRef;
    vqRaw = P.motorKpQ*errQ+motor.intQ+rsControl*iqRef+we*(P.motorLd*idRef+fluxControl);
    [vd,vq] = voltage_limit(vdRaw,vqRaw,Vlim);
    motor.intD = motor.intD+(P.motorKiD*errD+P.motorAntiWindup*(vd-vdRaw))*Ts;
    motor.intQ = motor.intQ+(P.motorKiQ*errQ+P.motorAntiWindup*(vq-vqRaw))*Ts;

    did = (vd-rsTrue*motor.idA+we*P.motorLq*motor.iqA)/P.motorLd;
    diq = (vq-rsTrue*motor.iqA-we*P.motorLd*motor.idA-we*fluxTrue)/P.motorLq;
    motor.idA = motor.idA+Ts*did;
    motor.iqA = motor.iqA+Ts*diq;
    motor.idA = min(max(motor.idA,-1.2*P.maxMotorCurrentA),1.2*P.maxMotorCurrentA);
    motor.iqA = min(max(motor.iqA,-1.2*P.maxMotorCurrentA),1.2*P.maxMotorCurrentA);
    motor.vdApplied = vd;
    motor.vqApplied = vq;

    if strcmp(mode,'ekf') && mod(n,P.ekfDivider)==0
        % Deterministic sensor perturbation/quantization for reproducible A/B runs.
        z = [motor.idMeasuredA;motor.iqMeasuredA];
        adaptationEnabled = abs(we)>=P.ekfMinElectricalSpeedRadS && hypot(z(1),z(2))>=P.ekfMinCurrentA;
        [motor.ekfX,motor.ekfCov] = observer_correct(motor.ekfX,motor.ekfCov,z, ...
            adaptationEnabled,P);
        if ~observer_is_healthy(motor.ekfX,motor.ekfCov)
            motor = reset_observer(motor,P);
        end
        motor.ekfX(3) = min(max(motor.ekfX(3),P.ekfRsBounds(1)),P.ekfRsBounds(2));
        motor.ekfX(4) = min(max(motor.ekfX(4),P.ekfFluxBounds(1)),P.ekfFluxBounds(2));
        motor.ekfUpdates = motor.ekfUpdates+double(adaptationEnabled);
    end
end
motor.rsOhm = rsTrue;
motor.fluxWb = fluxTrue;
motor.temperatureC = temperatureC;
motor.currentA = min(hypot(motor.idA,motor.iqA),P.maxMotorCurrentA);
motor.speedRpm = speedRadS*60/(2*pi);
motor.torqueNm = 1.5*P.motorPolePairs*(fluxTrue*motor.iqA+(P.motorLd-P.motorLq)*motor.idA*motor.iqA);
motor.torqueNm = min(max(motor.torqueNm,-P.maxRegenTorqueNm),P.maxDriveTorqueNm);
mechanicalPowerW = motor.torqueNm*speedRadS;
if mechanicalPowerW >= 0
    electricalPowerW = mechanicalPowerW/max(P.motorEfficiency,0.5);
else
    electricalPowerW = mechanicalPowerW*P.motorEfficiency;
end
batteryCurrentA = electricalPowerW/max(vdcV,100);
control.idReferenceA = idRef;
control.iqReferenceA = iqRef;
control.idFeedbackA = motor.idMeasuredA;
control.iqFeedbackA = motor.iqMeasuredA;
control.rsControlOhm = rsControl;
control.fluxControlWb = fluxControl;
control.rsEstimateOhm = motor.ekfX(3);
control.fluxEstimateWb = motor.ekfX(4);
control.ekfEnabled = strcmp(mode,'ekf');
control.ekfAdaptationEnabled = adaptationEnabled;
control.ekfUpdates = motor.ekfUpdates;
control.mode = mode;
control.ekfHealthy = motor.ekfHealthy;
end

function healthy = observer_is_healthy(x,Cov)
healthy = all(isfinite(x)) && all(isfinite(Cov(:))) && ...
    max(max(abs(Cov-Cov'))) < 1e-8 && all(diag(Cov) >= -1e-10);
end

function motor = reset_observer(motor,P)
motor.ekfHealthy = false;
motor.ekfX = [motor.idA;motor.iqA;P.motorResistanceOhm;P.motorFluxWb];
motor.ekfCov = diag([4,4,(0.25*P.motorResistanceOhm)^2,(0.15*P.motorFluxWb)^2]);
motor.intD = 0; motor.intQ = 0;
motor.vdApplied = 0; motor.vqApplied = 0;
end

function [x,Cov] = observer_predict(x,Cov,vd,vq,we,Ld,Lq,dt,P)
id=x(1); iq=x(2); rs=x(3); flux=x(4);
x(1)=id+dt*(vd-rs*id+we*Lq*iq)/Ld;
x(2)=iq+dt*(vq-rs*iq-we*Ld*id-we*flux)/Lq;
F=[1-dt*rs/Ld,dt*we*Lq/Ld,-dt*id/Ld,0; ...
   -dt*we*Ld/Lq,1-dt*rs/Lq,-dt*iq/Lq,-dt*we/Lq; ...
    0,0,1,0;0,0,0,1];
Cov=F*Cov*F'+P.ekfProcessNoise;
Cov=0.5*(Cov+Cov');
end

function [x,Cov] = observer_correct(x,Cov,z,adaptationEnabled,P)
H=[1 0 0 0;0 1 0 0];
R=diag([P.ekfMeasurementNoiseA^2,P.ekfMeasurementNoiseA^2]);
innovation=z-H*x;
innovationCov=H*Cov*H'+R;
if any(~isfinite(innovationCov(:))) || rcond(innovationCov)<1e-12, return; end
K=Cov*H'/innovationCov;
if ~adaptationEnabled, K(3:4,:)=0; end
x=x+K*innovation;
A=eye(4)-K*H;
Cov=A*Cov*A'+K*R*K';
Cov=0.5*(Cov+Cov');
end

function [vd,vq] = voltage_limit(vdRaw,vqRaw,Vlim)
vd=min(max(vdRaw,-Vlim),Vlim);
vqLimit=sqrt(max(Vlim^2-vd^2,0));
vq=min(max(vqRaw,-vqLimit),vqLimit);
end

function y = quantize_current(x,lsb)
y=round(x/lsb)*lsb;
end
