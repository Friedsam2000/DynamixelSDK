% The arm follows a series of points. Point 2 Point using PID.

clear()
clc
close

addpath('C:\Users\samue\Documents\Git\Robotic-Arm-Prototype\simulatedRobot')

%% Setup simulated robot
simulatedRobot = SimulatedRobot();


%% Initialize variables for visualization
tcp_positions = [];  % Array to store end-effector positions


%% Move the robot to a non-singularity position
simulatedRobot.moveInitPos(0);

% Number of points
n_points = 10;
% Radius of the circle in mm
radius = 150;  
% Center of the circle
center = [-radius/2, -radius/2, 500];

% Create an array of angular positions
theta = linspace(0, 2*pi, n_points);

% Use the parametric equations of a circle
x = center(1) + radius * cos(theta);
y = center(2) + radius * sin(theta);
z = center(3) * ones(size(theta));

% Create the waypoint array
waypoints = [x; y; z];

%% Use inverse kinematics to reach a goal position (Endeffector Position Control with PID)
% PID gains
Kp = 8;
Ki = 0;
Kd = 0.1;

% Display parameters
epsilon = 5; %mm

% Initialize error and integral terms
error_integral = zeros(3,1);
error_prev = zeros(3,1);

%Plot the goal positions
scatter3(x, y, z, (epsilon^2) * pi, 'm', 'filled');

for k = 1:size(waypoints, 2)
    x_desired = waypoints(:, k);
    
    max_timesteps = 10000;
    tcp_positions = zeros(3,max_timesteps);
    outerTic = tic;
    dt = 0.01;
    for timesteps = 1:max_timesteps

        % Get current end-effector position
        x_current = simulatedRobot.forwardKinematicsNumeric;
        tcp_positions(:,timesteps) = x_current;

        % Compute error
        error = x_desired - x_current;
        
        % Compute integral and derivative of error
        error_integral = error_integral + error;
        error_derivative = error - error_prev;
        
        % Compute control input (PID)
        u = Kp * error + Ki * error_integral + Kd * error_derivative;
        
        % Compute the Jacobian for the current robot configuration
        J = simulatedRobot.getJacobianNumeric();

        % Compute joint velocities
        pinvJ = pinv(J);
        q_dot = pinvJ * u;
    
        % Check for singularity
        if norm(J)*norm(pinvJ) > 25
            disp('Warning: Close to singularity');
            break
        end
        
        % Update joint angles based on computed joint velocities
        q = simulatedRobot.getQ;
        simulatedRobot.setQ(q + q_dot*dt)
            
        % Update previous error
        error_prev = error;
 
        % Display the robot
        plot3(tcp_positions(1,1:timesteps), tcp_positions(2,1:timesteps), tcp_positions(3,1:timesteps), 'k');
        simulatedRobot.draw(0);
        simulatedRobot.frames(end).draw;
        drawnow limitrate
        
        % Break condition: go to next waypoint if error is small
        if norm(error) < 5 %mm
            break;
        end

        % Wait if too fast
        if toc(outerTic) < timesteps*dt
            pause(timesteps*dt-toc(outerTic))
        end

    end
end
