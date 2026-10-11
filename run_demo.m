function result = run_demo(outputDir)
%RUN_DEMO Reproduce the single published case; no hardware or dialogs required.
%   RUN_DEMO exports figures (PNG/PDF), spectra, metrics and metadata to output/.
%   RESULT = RUN_DEMO(OUTPUTDIR) writes the same case to a different directory.
root = fileparts(mfilename('fullpath'));
if nargin == 0
    outputDir = fullfile(root, 'output');
end
validateattributes(outputDir, {'char', 'string'}, {'nonempty', 'row'});
outputDir = char(outputDir);
if ~license('test', 'Signal_Toolbox') || exist('pwelch', 'file') ~= 2
    error('Sloshing:MissingToolbox', 'Install and activate Signal Processing Toolbox.');
end
oldPath = path;
restorePath = onCleanup(@() path(oldPath));
addpath(fullfile(root, 'src'));

config = case_config;
signal = load_recording(fullfile(root, 'data', 'example_signal.csv'));
background = load_recording(fullfile(root, 'data', 'example_background.csv'));
result = analyze_pair(signal, background, config);
if ~isfolder(outputDir)
    [created, message] = mkdir(outputDir);
    if ~created
        error('Sloshing:OutputDirectory', 'Cannot create output directory: %s', message);
    end
end
export_results(result, outputDir);
plot_case(signal, result, outputDir);
fprintf('\nOffline vibration case completed.\n');
fprintf('Windows: %d samples each | fs: %g Hz | Welch: %d segments\n', ...
    numel(result.signal.filtered), config.fs, result.psd.segment_count);
fprintf('AC RMS: experiment %.4f, background %.4f ADC counts\n', ...
    result.signal.rms_adc, result.background.rms_adc);
fprintf('Largest experiment FFT bin: %.4f Hz (not a modal identification)\n', result.peak_frequency_hz);
fprintf('Results: %s\n', outputDir);
end
