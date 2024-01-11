classdef Launcher < handle
    properties
        % Instances
        virtualRobot;
        realRobot; % if empty -> not connected
        currentProgramInstance; % if empty -> not running

        % Singularity warning: true or false
        singularityWarning;

        % List of all available concrete programs
        programNames;

        % ConfigUpdateTimer
        configUpdateTimer;
    end


    methods (Static)
        % Static method to get the instance of the class
        function single_instance = getInstance()
            persistent instance;
            if isempty(instance) || ~isvalid(instance)
                instance = Launcher();
            end

            single_instance = instance;
        end
    end


    methods (Access = private)

        function obj = Launcher()

            % Add all relevant folders to MATLAB PATH
            Launcher.initPath;

            % Create the Virtual Robot Object
            obj.virtualRobot = VirtualRobot;

            % Create the configUpdateTimer
            obj.configUpdateTimer = timer('ExecutionMode', 'fixedRate', 'Period', 0.1, ...
                'BusyMode', 'queue', 'TimerFcn', @(~,~) obj.updateConfigAndPlot);

            % Load all available Programs
            obj.programNames = obj.getPrograms;
            obj.currentProgramInstance = [];

        end
    end

    methods

        function connect(obj, varargin)
            % Check if the constructor was called with a specified port
            if nargin < 2
                % If not, use 'COM3' as a default port
                PORT = 'COM3';
            else
                % Use the provided port
                PORT = varargin{1};
            end

            % Connect
            dynamixel_lib_path = Launcher.initPath;
            obj.realRobot = RealRobot(dynamixel_lib_path,PORT);

            % Check Connection
            if ~obj.realRobot.servoChain.checkConnection
                warning("Launcher: Connection Failed on USB Port %s \n", PORT);
            else
                fprintf("Launcher: Successfully connected on USB Port %s \n", PORT);

                % Set Zero Positoin
                obj.realRobot.setZeroPositionToCurrentPosition;
                obj.singularityWarning = true;
                fprintf("Launcher: Zero Position Set. \n");

                % Start the Plotting timer
                fprintf("Launcher: Starting Timer. \n");
                start(obj.configUpdateTimer);
            end

        end

        function disconnect(obj)

            fprintf("Launcher: Disconnecting... \n")

            % Stop any running program
            delete(obj.currentProgramInstance);   
            % If the launcher is connected
            if ~isempty(obj.realRobot)         
    
                % Stop the UpdateConfigTimer
                fprintf("Launcher: Stopping Timer. \n");
                stop(obj.configUpdateTimer);
                
                % Break connection by deleting realRobot object
                delete(obj.realRobot)
                obj.realRobot = [];
            end
        end
        
        function delete(obj)
            obj.disconnect;
            fprintf("Launcher: Deleting Timer.\n")
            delete(obj.configUpdateTimer);
            obj.configUpdateTimer = [];
            fprintf("Launcher: Deleting.\n")
        end

        function launchProgram(obj, programName, varargin)

            % Check if in ready state
            if isempty(obj.realRobot)   
                fprintf("Launcher: Not Connected.\n");
                return;
            end

            % Check if program is in the list of available programs
            if ~ismember(programName, obj.programNames)
                fprintf('Launcher: Program %s not found in available programs. \n', programName);
                return
            end

            % Stop and Delete any running program
            delete(obj.currentProgramInstance);

            % Stop the configUpdateTimer
            fprintf("Launcher: Stopping Timer. \n");
            stop(obj.configUpdateTimer)

            % Try to launch
            try
                % Create and Store an Instance of the Program and pass the
                % launcher object by reference
                obj.currentProgramInstance = feval(programName, obj);

                % Start the Program
                fprintf('Launcher: Program %s starting...\n', class(obj.currentProgramInstance));
                obj.currentProgramInstance.start(varargin{:});

            catch ME
                fprintf('Launcher: Failed to launch Program: %s. Error: %s. \n', programName, ME.message);
                delete(obj.currentProgramInstance)
            end
        end

        function programDeleteCallback(obj, deletedProgram)
            % Callback function that gets called by the program after
            % stopping or error and before it delets itself
            fprintf('Launcher: Program %s ended.\n', class(deletedProgram));
  
            % Clear the reference to it
            obj.currentProgramInstance = [];

            % Restart the plotting timer
            fprintf("Launcher: Starting Timer. \n");
            start(obj.configUpdateTimer);

        end

        function updateConfigAndPlot(obj)
            % Check if figure is still valid
            if isempty(obj.virtualRobot.fig) || ~isvalid(obj.virtualRobot.fig)
                % If not reopen the plot
                obj.virtualRobot.initRobotPlot;
            end

            % Common method to update the virtual robots configuration and update the plot
            obj.virtualRobot.setQ(obj.realRobot.getQ);
            obj.virtualRobot.updateRobotPlot;

            % Update Singularity Status
            obj.singularityWarning = obj.virtualRobot.checkSingularity;
        end
    end

    methods (Static, Hidden)

        function [is_valid, error_msg] = checkProgramArgs(programName, arguments)

            switch programName
                case 'Set_Joints'
                    % Expecting 4 doubles (including negatives) separated by commas or semicolons
                    expression = '^(-?\d+(\.\d+)?[,;] *){3}-?\d+(\.\d+)?$';
                    if regexp(arguments, expression)
                        is_valid = true;
                    else
                        is_valid = false;
                        error_msg = 'Please enter 4 joint angles (including negatives) separated by commas or semicolons.';
                    end

                case 'Set_Position'
                    % Expecting 3 doubles (including negatives) separated by commas or semicolons
                    expression = '^(-?\d+(\.\d+)?[,;] *){2}-?\d+(\.\d+)?$';
                    if regexp(arguments, expression)
                        is_valid = true;
                    else
                        is_valid = false;
                        error_msg = 'Please enter 3 position coordinates (x, y, z) including negatives, separated by commas or semicolons.';
                    end

                case 'Trajectory_2D'
                    % No arguments needed for Trajectory_2D
                    is_valid = true;
                    error_msg = [];
            end
        end

        function programs = getPrograms()
            % Get Current Dir of Launcher.m file
            currentFile = mfilename('fullpath');
            [currentDir, ~, ~] = fileparts(currentFile);

            % Construct the path to the 'ConcretePrograms' folder
            ConcreteProgramsPath = fullfile(currentDir, 'ConcretePrograms');

            % Load program names
            programFiles = dir(fullfile(ConcreteProgramsPath, '*.m'));
            programs = {}; % Initialize empty cell array for program names

            for i = 1:length(programFiles)
                programName = erase(programFiles(i).name, '.m');
                programs{end + 1} = char(programName); % Add the program name to the list
            end
        end

        function dynamixel_lib_path = initPath()

            % Get Current Dir of Launcher.m file (Programs)
            currentFile = mfilename('fullpath');
            [currentDir, ~, ~] = fileparts(currentFile);

            % Get Parent Dir (src)
            [parentDir, ~, ~] = fileparts(currentDir);

            addpath(fullfile(parentDir, 'VirtualRobot'));
            addpath(fullfile(parentDir, 'RealRobot'));
            addpath(fullfile(parentDir, 'Planner'));
            addpath(fullfile(parentDir, 'Controller'));
            addpath(fullfile(parentDir, 'Programs'));
            addpath(fullfile(parentDir, 'Programs\ConcretePrograms'));

            dynamixel_lib_path = fullfile(parentDir, 'DynamixelLib\c\');
        end
    end
end
