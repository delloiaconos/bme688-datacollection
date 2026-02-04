close all; clear all; clc;

fName = "es3-rpi1.csv";

%% Import data from CSV

% Set up the Import Options and import the data
opts = delimitedTextImportOptions("NumVariables", 13);

% Specify range and delimiter
opts.DataLines = [2, Inf];
opts.Delimiter = ",";

% Specify column names and types
opts.VariableNames = ["measid", "received_utc", "host", "sensor_id", "timestamp_ms", "temperature", "pressure", "humidity", "gas_resistance", "gas_index", "meas_index", "idac", "status"];
opts.VariableTypes = ["uint64", "string", "categorical", "uint32", "uint64", "double", "double", "double", "double", "uint32", "uint32", "uint32", "string"];

% Specify file level properties
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";

% Specify variable properties
opts = setvaropts(opts, ["received_utc", "status"], "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["received_utc", "host", "status"], "EmptyFieldRule", "auto");


% Import the data
meas = readtable( fName, opts);

% Convert fields
meas.timestamp = datetime(meas.timestamp_ms/1000, 'ConvertFrom','posixtime', 'TimeZone','UTC');
meas.status = hex2dec(erase(meas.status,"0x"));
meas.received_utc = datetime(meas.received_utc, ...
                                    "InputFormat","yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXX", ...
                                    "TimeZone","UTC" );
% Clear temporary variables
clear opts



%% Filters:

sensorsIdxs = unique( meas.sensor_id );
gasIdxs = unique( meas.gas_index );


gasId = 8;


filters = {};

for id = 1:numel( sensorsIdxs )
    sensorId = sensorsIdxs(id);
    filters{id} = (meas.gas_index == gasId) & (meas.sensor_id == sensorId );

end


fig2 = figure();
    for id = 1:numel( sensorsIdxs )
        plot( meas.timestamp(filters{id}), meas.gas_resistance(filters{id}), '*', DisplayName=sprintf( "Sensor %d", sensorsIdxs(id)) );
        hold on;
    end
    title( "GAS Resistance" );
    ylabel( "Resistance" );
    xlabel( "Date" );
    legend();


fig1 = figure();
    for id = 1:numel( sensorsIdxs )
        plot( meas.timestamp(filters{id}), meas.temperature(filters{id}), '*', DisplayName=sprintf( "Sensor %d", sensorsIdxs(id)) );
        hold on;
    end
    title( "Temperature" );
    ylabel( "Temperature [°C]" );
    xlabel( "Date" );
    legend();

fig3 = figure();
    for id = 1:numel( sensorsIdxs )
        plot( meas.timestamp(filters{id}), meas.humidity(filters{id}), '*', DisplayName=sprintf( "Sensor %d", sensorsIdxs(id)) );
        hold on;
    end
    title( "Humidity" );
    ylabel( "RH [%]" );
    xlabel( "Date" );
    legend();