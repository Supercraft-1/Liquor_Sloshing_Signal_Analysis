function prepare_example_data
%PREPARE_EXAMPLE_DATA Export the two original recordings without resampling.
% Developer utility; the public example already includes these CSV files.
root = fileparts(fileparts(mfilename('fullpath')));
target = fullfile(root, 'data');
if ~isfolder(target)
    mkdir(target);
end
sourceNames = {'Signal_0512_2320.xlsx', 'Background_0512_2319.xlsx'};
targetNames = {'example_signal.csv', 'example_background.csv'};
for k = 1:numel(sourceNames)
    source = readtable(fullfile(root, 'legacy', '02_Data', sourceNames{k}), ...
        'UseExcel', false);
    assert(isequal(source.Properties.VariableNames, {'Time_s', 'ADC_Value'}), ...
        'Unexpected source columns.');
    writetable(source, fullfile(target, targetNames{k}));
    exported = readtable(fullfile(target, targetNames{k}));
    assert(isequal(source.ADC_Value, exported.ADC_Value), 'ADC values changed.');
    assert(max(abs(source.Time_s - exported.Time_s)) < 1e-12, ...
        'Time values changed.');
    fprintf('%s -> %s (%d rows)\n', sourceNames{k}, targetNames{k}, height(source));
end
end
