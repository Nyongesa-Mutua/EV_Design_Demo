function network = communication_step(network, driver, timeS, P)
% COMMUNICATION_STEP Simulated periodic status-frame transport and link fault.
network.online = ~driver.networkLoss;
network.txFrames = network.txFrames + 1;
if network.online
    network.rxFrames = network.rxFrames + 1;
    network.lastRxTimeS = timeS;
else
    network.lostFrames = network.lostFrames + 1;
end
network.timeout = ~network.online || (timeS - network.lastRxTimeS > 3*P.networkFramePeriodS);
network.health = 'ONLINE';
if network.timeout
    network.health = 'TIMEOUT';
end
network.busLoadFraction = min(1,(network.txFrames*P.canNominalBitsPerFrame) / ...
    max(P.canBitrateBps*max(timeS,P.networkFramePeriodS),1));
network.protocolStatus = 'SIMULATED_ONLY';
end
