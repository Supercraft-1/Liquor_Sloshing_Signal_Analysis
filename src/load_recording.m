function data = load_recording(filename)
%LOAD_RECORDING Read the committed time/ADC CSV without modifying its samples.
if ~isfile(filename)
    error('Sloshing:MissingData', 'Missing recording: %s. Download the complete repository.', filename);
end
recording = readtable(filename);
if ~isequal(recording.Properties.VariableNames, {'Time_s', 'ADC_Value'})
    error('Sloshing:InvalidColumns', 'Expected exactly Time_s and ADC_Value in %s.', filename);
end
if ~isnumeric(recording.Time_s) || ~isnumeric(recording.ADC_Value)
    error('Sloshing:NonNumericData', 'Recording columns must contain numeric values.');
end
data = double([recording.Time_s, recording.ADC_Value]);
end
