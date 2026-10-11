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
export_diagnostics(result, outputDir);
save(fullfile(outputDir, 'analysis.mat'), 'result');

metadata.schema_version = 3;
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
metadata.diagnostics.psd_method = 'spectrogram one-sided PSD; same Hann, overlap and NFFT as pwelch';
metadata.diagnostics.frame_time = 'Absolute center of each half-open frame; independent recordings';
metadata.diagnostics.rms_method = 'Centered moving RMS; shortened support at window edges';
metadata.diagnostics.threshold_method = 'Median + max(k * 1.4826 * MAD, relative rise * median, numerical roundoff guard); coefficients in config';
metadata.diagnostics.response_interpretation = 'Above-threshold activity candidates, not excitation times and not free decay';
metadata.diagnostics.peak_interpretation = 'Nearby strong FFT peaks, not confirmed common physical sources';
metadata.diagnostics.peak_match_tolerance_hz = result.diagnostics.common_peaks.match_tolerance_hz;
metadata.diagnostics.parameter_estimation = 'not_performed';
metadata.diagnostics.reason = 'Unmeasured excitation and unverified free-response intervals';
metadata.diagnostics.experiment_candidate_count = height(result.diagnostics.responses.signal.candidates);
metadata.diagnostics.background_candidate_count = height(result.diagnostics.responses.background.candidates);
metadata.diagnostics.common_peak_count = height(result.diagnostics.common_peaks.matches);
filename = fullfile(outputDir, 'run_metadata.json');
[file, message] = fopen(filename, 'w', 'n', 'UTF-8');
if file < 0
    error('Sloshing:MetadataWrite', 'Cannot write metadata: %s', message);
end
closeFile = onCleanup(@() fclose(file));
fprintf(file, '%s\n', jsonencode(metadata, 'PrettyPrint', true));
end

function export_diagnostics(result, directory)
d = result.diagnostics;
fields = {'signal', 'background'};
names = {"experiment", "background"};
spectra = cell(2, 1); bands = cell(2, 1); candidates = cell(2, 1);
for i = 1:2
    tf = d.time_frequency.(fields{i});
    frameCount = numel(tf.frame_center_s);
    frequencyCount = numel(tf.frequency_hz);
    spectra{i} = table(repmat(names{i}, frameCount * frequencyCount, 1), ...
        repelem((1:frameCount)', frequencyCount), ...
        repelem(tf.frame_start_s, frequencyCount), repelem(tf.frame_end_s, frequencyCount), ...
        repelem(tf.frame_center_s, frequencyCount), repmat(tf.frequency_hz, frameCount, 1), ...
        tf.density(:), 'VariableNames', {'Recording', 'Frame', 'Frame_Start_s', ...
        'Frame_End_s', 'Frame_Center_s', 'Frequency_Hz', 'PSD_ADC2_Per_Hz'});
    bandCount = size(result.config.bands_hz, 1);
    power = tf.band_power_adc2';
    bands{i} = table(repmat(names{i}, frameCount * bandCount, 1), ...
        repelem((1:frameCount)', bandCount), repelem(tf.frame_center_s, bandCount), ...
        repmat(result.config.bands_hz(:, 1), frameCount, 1), ...
        repmat(result.config.bands_hz(:, 2), frameCount, 1), power(:), ...
        'VariableNames', {'Recording', 'Frame', 'Frame_Center_s', 'Low_Hz', 'High_Hz', 'Power_ADC2'});
    response = d.responses.(fields{i});
    labels = table(repmat(names{i}, height(response.candidates), 1), 'VariableNames', {'Recording'});
    candidates{i} = [labels, response.candidates];
end
writetable(vertcat(spectra{:}), fullfile(directory, 'time_frequency.csv'));
writetable(vertcat(bands{:}), fullfile(directory, 'time_band_metrics.csv'));
writetable(vertcat(candidates{:}), fullfile(directory, 'response_candidates.csv'));
writetable(d.common_peaks.matches, fullfile(directory, 'common_peaks.csv'));
envelope = table(d.responses.signal.time_s, d.responses.signal.rms_adc, ...
    d.responses.background.time_s, d.responses.background.rms_adc, 'VariableNames', ...
    {'Experiment_Time_s', 'Experiment_RMS_ADC', 'Background_Time_s', 'Background_RMS_ADC'});
writetable(envelope, fullfile(directory, 'local_rms.csv'));
end
