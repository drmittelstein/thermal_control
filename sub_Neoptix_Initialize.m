% Author: David Reza Mittelstein (drmittelstein@gmail.com)
% Medical Engineering, California Institute of Technology, 2020

% SUBROUTINE
% Initialize connection to the Neoptix

function params = sub_Neoptix_Initialize(params)

disp('- Connecting to Neoptix Reflex Fiber Optic Temp Sensor')
delete(instrfind('status', 'closed'));
% First try to connect to the Neoptix without disconnecting anything
port = 2;
connected = 0;
while port < 20 && ~connected
    try
    port = port + 1;
    params.Neoptix.sobj = serial(sprintf('COM%d',port), 'Terminator', 'CR', 'Timeout', 1);   
    fopen(params.Neoptix.sobj);
    disp(sprintf('   > Found device on open port COM%d', port));
    if contains(query(params.Neoptix.sobj, 'i'), 'ReFlex')
        disp(sprintf('   > Confirmed connection to Neoptix Reflex on COM%d', port))
        fclose(params.Neoptix.sobj);
        fopen(params.Neoptix.sobj);
        connected = 1;
    else
        disp('   > But it is not Neoptix')
        fclose(params.Neoptix.sobj);
        delete(instrfind('Name', sprintf('Serial-COM%1.0f',port)));
    end
    
    catch
    end
end

if ~connected
disp('   > Could not find Neoptix on unused ports, now looking through used ports')
disp('     this may cause other devices to disconnect');

port = 2;
connected = 0;
while port < 100 && ~connected
    try
    port = port + 1;
    dvcs = instrfind('Name', sprintf('Serial-COM%1.0f',port));

    if numel(dvcs) > 0
        disp(sprintf('   > Disconnected device on COM%1.0f', port));
        delete(dvcs);
    end
    params.Neoptix.sobj = serial(sprintf('COM%d',port), 'Terminator', 'CR', 'Timeout', 1);   
    fopen(params.Neoptix.sobj);
    disp(sprintf('   > Found device on open port COM%d', port));
    if contains(query(params.Neoptix.sobj, 'i'), 'ReFlex')
        disp(sprintf('   > Connected connection to Neoptix Reflex on COM%d', port))
        connected = 1;
    else
        disp('   > But it is not Neoptix')
    end
    
    catch
    end
end   

    
end
delete(instrfind('status', 'closed'));
if ~connected
    error('Could not find Neoptix on any COM port')
end

end