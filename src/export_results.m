function export_results(result, outputDir)
%EXPORT_RESULTS Store numerical outputs with explicit units and method metadata.
writetable(result.metrics, fullfile(outputDir, 'metrics.csv'));
writetable(result.bands, fullfile(outputDir, 'band_metrics.csv'));
fftData = table(result.fft.frequency_hz, result.fft.signal_amplitude, ...
    result.fft.background_amplitude, 'VariableNames', ...
    {'Frequency_Hz', 'Experiment_Amplitude_ADC', 'Background_Amplitude_ADC'});
writetable(fftData, fullfile(outputDir, 'spectrum.csv'));
psdData = table(result.psd.frequency_hz, result.psd.signal_density, ...
    result.psd.background_density, 'VariableNames', ...
    {'Frequency_Hz', 'Experiment_PSD_ADC2_Per_Hz', 'Background_PSD_ADC2_Per_Hz'});
writetable(psdData, fullfile(outputDir, 'psd.csv'));
save(fullfile(outputDir, 'analysis.mat'), 'result');

metadata.schema_version = 2;
metadata.matlab_version = version;
metadata.matlab_release = version('-release');
toolbox = ver('signal');
metadata.signal_toolbox_version = toolbox.Version;
metadata.signal_source = 'data/example_signal.csv';
metadata.background_source = 'data/example_background.csv';
metadata.config = result.config;
metadata.preprocessing = 'Full-record DC removal and SOS filtfilt, then crop and remove window mean';
metadata.amplitude_unit = 'uncalibrated ADC counts';
metadata.fft_normalization = 'Periodic Hann; abs(FFT)/sum(window); double interior one-sided bins';
metadata.psd_method = 'pwelch, periodic Hann, one-sided density in ADC counts^2/Hz';
metadata.welch_segment_count = result.psd.segment_count;
metadata.band_integration = 'Linear interpolation at exact band edges, trapezoidal PSD integration';
metadata.background_comparison = 'Independent spectra; no subtraction or denoising claim';
metadata.filter.prototype_order = result.config.filter_order;
metadata.filter.single_pass_bandpass_order = 2 * result.config.filter_order;
metadata.filter.forward_backward = true;
filename = fullfile(outputDir, 'run_metadata.json');
[file, message] = fopen(filename, 'w', 'n', 'UTF-8');
if file < 0
    error('Sloshing:MetadataWrite', 'Cannot write metadata: %s', message);
end
closeFile = onCleanup(@() fclose(file));
fprintf(file, '%s\n', jsonencode(metadata, 'PrettyPrint', true));
end
