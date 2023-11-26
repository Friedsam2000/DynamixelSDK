clearvars -except simulatedRobot
clc
close all


addpath('C:\Users\samue\Documents\Git\Robotic-Arm-Prototype\RealRobot\src')
addpath('C:\Users\samue\Documents\Git\Robotic-Arm-Prototype\SimulatedRobot\src')

%% Setup simulated robot, controller, planner, and trajectory generator

% Initialize the robot
if ~exist('simulatedRobot','var')
    simulatedRobot = SimulatedRobot();
end


% Initialize the controller
controller = NullspaceController(simulatedRobot);

%% Connect real robot
realRobot = RealRobot();

% Initial position setup for Real robot
realRobot.torqueEnableDisable(0);
realRobot.setOperatingMode('velocity');
realRobot.setZeroPositionToCurrentPosition;
realRobot.torqueEnableDisable(1);
realRobot.setJointVelocities([0.02,0.02,0.1,0.1]);
pause(2)
realRobot.setJointVelocities([0,0,0,0]);

% Set simulated Robot to same config as real robot
simulatedRobot.setQ(realRobot.getQ);


%% Create a goal pos

x_desired = [200;200;400];
% Plot the desired point
simulatedRobot.draw(0)
scatter3(x_desired(1),x_desired(2),x_desired(3), 30, 'filled', 'm');
figure(simulatedRobot.fig);

% Plot the workspace
simulatedRobot.visualizeWorkspace;

%% Control Loop
% Init array for storing tcp positions
tcp_positions = zeros(3,10000);

%% Loop
loopBeginTime = tic;
step = 1;
while 1

    % Simulation
    q = realRobot.getQ;
    simulatedRobot.setQ(q);
   
    q_dot = controller.computeDesiredJointVelocity(simulatedRobot, x_desired,  NaN , 0);
    
    % Action
    if mod(step,10) == 0
         realRobot.setJointVelocities(q_dot);
    end

    % Display the robot
    tcp_positions(:,step) = simulatedRobot.forwardKinematicsNumeric(q);
    plot3(tcp_positions(1,1:step), tcp_positions(2,1:step), tcp_positions(3,1:step), 'k');
    simulatedRobot.draw(0);
    simulatedRobot.frames(end).draw;
    drawnow limitrate

    step = step +1;

end