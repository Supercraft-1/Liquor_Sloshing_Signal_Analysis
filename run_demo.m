function result = run_demo(outputDir)
%RUN_DEMO Reproduce the published offline case without hardware or dialogs.
%   RUN_DEMO writes figures and data to output/ next to this file.
%   RESULT = RUN_DEMO(OUTPUTDIR) is used by the regression checks.
root = fileparts(mfilename('fullpath'));
if nargin == 0
    outputDir = fullfile(root, 'output');
end
validateattributes(outputDir, {'char', 'string'}, {'nonempty'});
outputDir = char(outputDir);
if ~license('test', 'Signal_Toolbox') || exist('butter', 'file') ~= 2
    error('Sloshing:MissingToolbox', ...
        'Install and activate Signal Processing Toolbox, then run run_demo again.');
end
oldPath = path;
restorePath = onCleanup(@() path(oldPath));
addpath(fullfile(root, 'src'));

% The complete public case is defined here. No cached MAT settings are read.
config.fs = 5000;
config.signal_window_s = [0.60, 1.60];
config.background_window_s = [0.00, 1.00];
config.median_points = 5;
config.filter_order = 4;
config.band_hz = [20, 2000];
config.tukey_alpha = 0.1;
signalFile = fullfile(root, 'data', 'example_signal.csv');
backgroundFile = fullfile(root, 'data', 'example_background.csv');
signal = load_recording(signalFile);
background = load_recording(backgroundFile);
result = analyze_pair(signal, background, config);
if ~isfolder(outputDir)
    [created, message] = mkdir(outputDir);
    if ~created
        error('Sloshing:OutputDirectory', 'Cannot create output folder: %s', message);
    end
end
writetable(result.metrics, fullfile(outputDir, 'metrics.csv'));
spectrum = table(result.frequency_hz, result.signal_amplitude, ...
    result.background_amplitude, result.contrast_amplitude, ...
    'VariableNames', {'Frequency_Hz', 'Signal_Amplitude_ADC', ...
    'Background_Amplitude_ADC', 'Contrast_Amplitude_ADC'});
writetable(spectrum, fullfile(outputDir, 'spectrum.csv'));
save(fullfile(outputDir, 'analysis.mat'), 'result');
write_metadata(outputDir, config);
draw_waveform(signal, result, outputDir);
draw_spectrum(result, outputDir);
fprintf('\nOffline vibration case completed.\n');
disp(result.metrics);
fprintf('Results: %s\n', outputDir);
end

function data = load_recording(filename)
if ~isfile(filename)
    error('Sloshing:MissingData', 'Missing sample file: %s. Download the complete repository.', filename);
end
recording = readtable(filename);
if ~isequal(recording.Properties.VariableNames, {'Time_s', 'ADC_Value'})
    error('Sloshing:InvalidColumns', 'Expected exactly Time_s and ADC_Value in %s.', filename);
end
if ~isnumeric(recording.Time_s) || ~isnumeric(recording.ADC_Value)
    error('Sloshing:NonNumericData', 'Sample columns must contain numeric values.');
end
data = double([recording.Time_s, recording.ADC_Value]);
end

function write_metadata(outputDir, config)
metadata.matlab_version = version;
metadata.matlab_release = version('-release');
toolbox = ver('signal');
metadata.signal_toolbox_version = toolbox.Version;
metadata.signal_source = 'data/example_signal.csv';
metadata.background_source = 'data/example_background.csv';
metadata.config = config;
metadata.amplitude_unit = 'uncalibrated ADC counts';
metadata.spectrum_normalization = 'one-sided FFT amplitude / sum(Tukey window)';
metadata.contrast_definition = 'sqrt(max(signal_amplitude^2 - background_amplitude^2, 0))';
filename = fullfile(outputDir, 'run_metadata.json');
[file, message] = fopen(filename, 'w', 'n', 'UTF-8');
if file < 0
    error('Sloshing:MetadataWrite', 'Cannot write metadata: %s', message);
end
closeFile = onCleanup(@() fclose(file));
fprintf(file, '%s\n', jsonencode(metadata, 'PrettyPrint', true));
end

function draw_waveform(rawSignal, result, outputDir)
blue = [0.12, 0.32, 0.53];
gray = [0.45, 0.48, 0.52];
figureHandle = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [100, 100, 1120, 680]);
closeFigure = onCleanup(@() close(figureHandle));
layout = tiledlayout(figureHandle, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, 'Recorded waveform and fixed analysis window', 'FontWeight', 'bold');
axesHandle = nexttile(layout);
plot(axesHandle, rawSignal(:, 1), rawSignal(:, 2), 'Color', gray, 'LineWidth', 0.8);
hold(axesHandle, 'on');
plot(axesHandle, result.signal.time_s, result.signal.raw, 'Color', blue, 'LineWidth', 1);
xline(axesHandle, result.config.signal_window_s(1), '--', '0.60 s', ...
    'LabelVerticalAlignment', 'bottom');
xline(axesHandle, result.config.signal_window_s(2), '--', '1.60 s', ...
    'LabelVerticalAlignment', 'bottom');
xlim(axesHandle, [rawSignal(1, 1), rawSignal(end, 1)]);
xlabel(axesHandle, 'Recording time (s)'); ylabel(axesHandle, 'Raw ADC counts');
legend(axesHandle, {'Full recording', 'Selected samples'}, 'Location', 'northeast');
grid(axesHandle, 'on'); box(axesHandle, 'off');
axesHandle = nexttile(layout);
plot(axesHandle, result.signal.relative_time_s, result.signal.filtered, ...
    'Color', blue, 'LineWidth', 1);
hold(axesHandle, 'on');
plot(axesHandle, result.background.relative_time_s, result.background.filtered, ...
    'Color', gray, 'LineWidth', 0.8);
xlim(axesHandle, [0, 1]);
xlabel(axesHandle, 'Time within each window (s)');
ylabel(axesHandle, 'Filtered ADC counts');
title(axesHandle, 'Median filter, mean removal and 20-2000 Hz zero-phase bandpass');
legend(axesHandle, {'Experiment', 'Background'}, 'Location', 'northeast');
grid(axesHandle, 'on'); box(axesHandle, 'off');
exportgraphics(figureHandle, fullfile(outputDir, 'waveform.png'), 'Resolution', 160);
end

function draw_spectrum(result, outputDir)
blue = [0.12, 0.32, 0.53];
orange = [0.78, 0.36, 0.16];
gray = [0.45, 0.48, 0.52];
figureHandle = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [100, 100, 1120, 680]);
closeFigure = onCleanup(@() close(figureHandle));
layout = tiledlayout(figureHandle, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, 'One-sided amplitude spectrum: experiment vs background', 'FontWeight', 'bold');
axesHandle = nexttile(layout);
% A log scale keeps the low-amplitude background visible. Zero bins are omitted.
signalLog = result.signal_amplitude;
backgroundLog = result.background_amplitude;
contrastLog = result.contrast_amplitude;
signalLog(signalLog <= 0) = NaN;
backgroundLog(backgroundLog <= 0) = NaN;
contrastLog(contrastLog <= 0) = NaN;
semilogy(axesHandle, result.frequency_hz, signalLog, 'Color', blue, 'LineWidth', 1);
hold(axesHandle, 'on');
semilogy(axesHandle, result.frequency_hz, backgroundLog, 'Color', gray, 'LineWidth', 1);
semilogy(axesHandle, result.frequency_hz, contrastLog, '--', 'Color', orange, 'LineWidth', 0.8);
xlim(axesHandle, result.config.band_hz);
xlabel(axesHandle, 'Frequency (Hz)'); ylabel(axesHandle, 'Amplitude (ADC counts, log scale)');
legend(axesHandle, {'Experiment', 'Background', 'Spectral contrast'}, 'Location', 'northeast');
grid(axesHandle, 'on'); box(axesHandle, 'off');
axesHandle = nexttile(layout);
plot(axesHandle, result.frequency_hz, result.contrast_amplitude, ...
    'Color', blue, 'LineWidth', 1);
hold(axesHandle, 'on');
if isfinite(result.peak_frequency_hz)
    xline(axesHandle, result.peak_frequency_hz, '--', 'Color', orange);
end
xlim(axesHandle, [20, 350]);
xlabel(axesHandle, 'Frequency (Hz)'); ylabel(axesHandle, 'Contrast amplitude (ADC counts)');
title(axesHandle, sprintf('Low-frequency detail (20-350 Hz) | Peak bin: %.2f Hz', ...
    result.peak_frequency_hz));
grid(axesHandle, 'on'); box(axesHandle, 'off');
exportgraphics(figureHandle, fullfile(outputDir, 'spectrum.png'), 'Resolution', 160);
end
