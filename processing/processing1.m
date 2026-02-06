close all; clear all; clc;

set(groot,'DefaultFigureWindowStyle','docked')

%% Import BME688 data from CSV

fName = "es3-rpi1.csv";
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
meas.timestamp = datetime(meas.timestamp_ms/1000, 'ConvertFrom','posixtime', 'TimeZone','UTC+1');
meas.status = hex2dec(erase(meas.status,"0x"));
meas.received_utc = datetime(meas.received_utc, ...
                                    "InputFormat","yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXX", ...
                                    "TimeZone","Europe/Rome" );

clear opts

%% Import Aeroqual CSV
fName = "AQM65 29112024-957 Data Export.csv";

opts = delimitedTextImportOptions("NumVariables", 10, "Encoding", "UTF-8");

% Specify range and delimiter
opts.DataLines = [8, Inf];
opts.Delimiter = ";";

% Specify column names and types
opts.VariableNames = ["Time", "COppm", "CO2ppm", "NOxppm", "O3ppm", "SO2ppm", "ITEMPC", "TEMPC", "RH", "Inlet"];
opts.VariableTypes = ["string", "double", "double", "double", "double", "double", "double", "double", "double", "categorical"];

% Specify file level properties
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";

% Specify variable properties
opts = setvaropts(opts, "Time", "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["Time", "Inlet"], "EmptyFieldRule", "auto");
opts = setvaropts(opts, ["COppm", "NOxppm", "O3ppm", "SO2ppm", "ITEMPC", "TEMPC", "RH"], "TrimNonNumeric", true);
opts = setvaropts(opts, ["COppm", "NOxppm", "O3ppm", "SO2ppm", "ITEMPC", "TEMPC", "RH"], "ThousandsSeparator", ",");

% Import the data
aqm = readtable( fName, opts);

clear opts
%"2026/01/02 00:00:00"
aqm.Time = datetime(aqm.Time, ...
                        "InputFormat","yyyy/MM/dd HH:mm:ss", ...
                        "TimeZone","Europe/Rome" );

%% FIGURE
figure(); 
    plot( aqm.Time, aqm.CO2ppm )

%% Filters:

sensorsIdxs = unique( meas.sensor_id );
gasIdxs = unique( meas.gas_index );


gasId = 8;


filters = {};

for sid = 1:numel( sensorsIdxs )
    sensorId = sensorsIdxs(sid);
    filters{sid} = (meas.gas_index == gasId) & (meas.sensor_id == sensorId );

end

fig = figure();
    for sid = 1:numel( sensorsIdxs )
        plot( meas.timestamp(filters{sid}), meas.gas_resistance(filters{sid}), '*', DisplayName=sprintf( "Sensor %d", sensorsIdxs(sid)) );
        hold on;
    end
    title( "GAS Resistance" );
    ylabel( "Resistance" );
    xlabel( "Date" );
    legend();


fig = figure();
    for sid = 1:numel( sensorsIdxs )
        plot( meas.timestamp(filters{sid}), meas.temperature(filters{sid}), '*', DisplayName=sprintf( "Sensor %d", sensorsIdxs(sid)) );
        hold on;
    end
    title( "Temperature" );
    ylabel( "Temperature [°C]" );
    xlabel( "Date" );
    legend();

fig = figure();
    for sid = 1:numel( sensorsIdxs )
        plot( meas.timestamp(filters{sid}), meas.humidity(filters{sid}), '*', DisplayName=sprintf( "Sensor %d", sensorsIdxs(sid)) );
        hold on;
    end
    title( "Humidity" );
    ylabel( "RH [%]" );
    xlabel( "Date" );
    legend();


%% FIG Temperature/Humidity


nCols = 1;
nRows = 2;
kax = 0;
fig = figure();
    
    kax = kax+1;
    subplot( nRows, nCols, kax );
        for sid = 1:numel( sensorsIdxs )
            plot( meas.timestamp(filters{sid}), meas.temperature(filters{sid}), '*', DisplayName=sprintf( "Sensor %d", sensorsIdxs(sid)) );
            hold on;
        end
        title( "Temperature" );
        ylabel( "Temperature [°C]" );
        xlabel( "Date" );
        legend();

    kax = kax+1;
    subplot( nRows, nCols, kax );
        for sid = 1:numel( sensorsIdxs )
            plot( meas.timestamp(filters{sid}), meas.humidity(filters{sid}), '*', DisplayName=sprintf( "Sensor %d", sensorsIdxs(sid)) );
            hold on;
        end
        title( "Humidity" );
        ylabel( "RH [%]" );
        xlabel( "Date" );
        legend();

%% FIG Gas Resistance

filters = {};

for gid = 1:numel( gasIdxs )
    gasId = gasIdxs( gid );
    for sid = 1:numel( sensorsIdxs )
        sensorId = sensorsIdxs(sid);
        filters{gid,sid} = (meas.gas_index == gasId) & (meas.sensor_id == sensorId );
    end
end

fig = figure();
    nCols = 2;
    nRows = numel( gasIdxs )/2;
    kax = 0;

    for gid = 1:numel( gasIdxs )
        kax = kax+1;
        subplot( nRows, nCols, kax );
            for sid = 1:numel( sensorsIdxs )
                plot( meas.timestamp(filters{gid,sid}), meas.gas_resistance(filters{gid,sid}), '*', DisplayName=sprintf( "Sensor %d", sensorsIdxs(sid)) );
                hold on;
            end
            title( sprintf( "Sampling index %d", gid ) );
            ylabel( "Resistance [Ohm]" );
            xlabel( "Date" );
            %legend();
    end

%% PROCESSING
xLimits = [datetime(2026,2,3,14,0,0, "TimeZone","Europe/Rome" ) datetime(2026,2,4,4,0,0, "TimeZone","Europe/Rome")];

vars = ["timestamp","temperature","humidity", "gas_resistance"];     % keep only these

fig = figure();
    nCols = 2;
    nRows = numel( gasIdxs )/2;
    kax = 0;
    
    for gid = 1:numel( gasIdxs )
        kax = kax+1;
        axs(kax) = subplot( nRows, nCols, kax );
            for sid = 1:numel( sensorsIdxs )
                
                gasId = gasIdxs( gid );
                sensorId = sensorsIdxs(sid);
                filter = (meas.gas_index == gasId) & (meas.sensor_id == sensorId );
                
                TT = table2timetable(meas(filter, vars), "RowTimes", "timestamp");
                TTRes = retime(TT,"regular","mean","TimeStep",minutes(5));

                plot( TTRes.timestamp, TTRes.gas_resistance/1e6, DisplayName=sprintf( "Sensor %d", sensorsIdxs(sid)) );
                hold on;
            end
            title( sprintf( "Sampling index %d", gid ) );
            ylabel( "Resistance [MOhm]" );
            xlabel( "Date" );
            xlim( xLimits )
            %ylim( [0, 10^7] );
            %legend();
    end
    linkaxes(axs,'x');
    %linkaxes(axs,'y');
    