function diagnostics = analyze_diagnostics(result)
%ANALYZE_DIAGNOSTICS 计算逐帧 PSD、局部活动区间和邻近谱峰。
c = result.config;
validate_settings(c, numel(result.signal.filtered));
diagnostics.time_frequency.signal = frame_spectrum(result.signal, c);
diagnostics.time_frequency.background = frame_spectrum(result.background, c);
diagnostics.responses.signal = response_candidates(result.signal, c);
diagnostics.responses.background = response_candidates(result.background, c);
diagnostics.common_peaks = nearby_peaks(result.fft, c, numel(result.signal.filtered));
end

function validate_settings(c, count)
try
    d = c.diagnostics;
    validateattributes(d.envelope_window_s, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
    samples = d.envelope_window_s * c.fs;
    if samples < 2 || samples > count || abs(samples - round(samples)) > 1e-6
        error('Sloshing:InvalidDiagnostics', 'RMS window must span 2 to N whole samples.');
    end
    validateattributes(d.threshold_mad_multiplier, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'});
    validateattributes(d.minimum_relative_rise, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'});
    validateattributes(d.merge_gap_s, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'});
    validateattributes(d.minimum_active_s, {'numeric'}, {'scalar', 'real', 'finite', 'positive', '<=', count / c.fs});
    validateattributes(d.peak_prominence_fraction, {'numeric'}, {'scalar', 'real', 'finite', '>', 0, '<=', 1});
catch exception
    error('Sloshing:InvalidDiagnostics', 'Invalid diagnostic settings: %s', exception.message);
end
end

function tf = frame_spectrum(segment, c)
window = hann(c.welch_segment_samples, 'periodic');
[~, tf.frequency_hz, center, tf.density] = spectrogram(segment.filtered, window, ...
    c.welch_overlap_samples, c.welch_nfft, c.fs, 'onesided', 'psd');
count = numel(center);
hop = c.welch_segment_samples - c.welch_overlap_samples;
tf.frame_start_s = segment.time_s(1) + (0:count - 1)' * hop / c.fs;
tf.frame_end_s = tf.frame_start_s + c.welch_segment_samples / c.fs;
tf.frame_center_s = segment.time_s(1) + center(:);
tf.band_power_adc2 = zeros(count, size(c.bands_hz, 1));
for frame = 1:count
    for band = 1:size(c.bands_hz, 1)
        tf.band_power_adc2(frame, band) = integrate_psd(tf.frequency_hz, ...
            tf.density(:, frame), c.bands_hz(band, :));
    end
end
end

function response = response_candidates(segment, c)
d = c.diagnostics;
window = round(d.envelope_window_s * c.fs);
left = floor((window - 1) / 2);
right = ceil((window - 1) / 2);
x = segment.filtered;
count = numel(x);
response.time_s = segment.time_s;
response.rms_adc = sqrt(movmean(x.^2, [left, right], 'Endpoints', 'shrink'));
response.baseline_adc = median(response.rms_adc);
response.robust_spread_adc = 1.4826 * median(abs(response.rms_adc - response.baseline_adc));
% 相对上升项抑制稳定正弦的微小包络起伏。
rise = max([d.threshold_mad_multiplier * response.robust_spread_adc, ...
    d.minimum_relative_rise * response.baseline_adc, 32 * eps(max(response.rms_adc))]);
response.threshold_adc = response.baseline_adc + rise;
active = response.rms_adc > response.threshold_adc;
edges = diff([false; active; false]);
starts = find(edges == 1);
stops = find(edges == -1) - 1;
mergedStart = zeros(0, 1);
mergedStop = zeros(0, 1);
for i = 1:numel(starts)
    if ~isempty(mergedStop) && (starts(i) - mergedStop(end) - 1) / c.fs <= d.merge_gap_s
        mergedStop(end) = stops(i);
    else
        mergedStart(end + 1, 1) = starts(i); %#ok<AGROW>
        mergedStop(end + 1, 1) = stops(i); %#ok<AGROW>
    end
end
startTime = zeros(0, 1); endTime = zeros(0, 1); peakTime = zeros(0, 1);
peakRms = zeros(0, 1); regionRms = zeros(0, 1); boundary = false(0, 1);
for i = 1:numel(mergedStart)
    indices = (mergedStart(i):mergedStop(i))';
    if sum(active(indices)) / c.fs < d.minimum_active_s
        continue
    end
    [peak, offset] = max(response.rms_adc(indices));
    startTime(end + 1, 1) = segment.time_s(indices(1)); %#ok<AGROW>
    endTime(end + 1, 1) = segment.time_s(indices(end)) + 1 / c.fs; %#ok<AGROW>
    peakTime(end + 1, 1) = segment.time_s(indices(offset)); %#ok<AGROW>
    peakRms(end + 1, 1) = peak; %#ok<AGROW>
    regionRms(end + 1, 1) = sqrt(mean(x(indices).^2)); %#ok<AGROW>
    boundary(end + 1, 1) = indices(1) <= left || indices(end) > count - right; %#ok<AGROW>
end
response.candidates = table((1:numel(startTime))', startTime, endTime, peakTime, ...
    peakRms, regionRms, boundary, 'VariableNames', {'Candidate', 'Start_Time_s', ...
    'End_Time_s', 'Peak_Time_s', 'Peak_RMS_ADC', 'Region_RMS_ADC', 'Boundary_Limited'});
end

function common = nearby_peaks(spectrum, c, sampleCount)
% 容差取 Hann 主瓣零点间宽度的一半，不代表统计置信区间。
common.match_tolerance_hz = 2 * c.fs / sampleCount;
common.minimum_prominence_fraction = c.diagnostics.peak_prominence_fraction;
inBand = spectrum.frequency_hz >= c.band_hz(1) & spectrum.frequency_hz <= c.band_hz(2);
f = spectrum.frequency_hz(inBand);
[signalAmplitude, signalFrequency] = strong_peaks( ...
    spectrum.signal_amplitude(inBand), f, common);
[backgroundAmplitude, backgroundFrequency] = strong_peaks( ...
    spectrum.background_amplitude(inBand), f, common);
distance = abs(signalFrequency(:) - backgroundFrequency(:)');
[experimentIndex, backgroundIndex] = find(distance <= common.match_tolerance_hz);
separation = distance(sub2ind(size(distance), experimentIndex, backgroundIndex));
pairs = [separation(:), experimentIndex(:), backgroundIndex(:)];
pairs = sortrows(pairs, [1, 2, 3]);
usedExperiment = false(numel(signalFrequency), 1);
usedBackground = false(numel(backgroundFrequency), 1);
accepted = zeros(0, 5);
for i = 1:size(pairs, 1)
    e = pairs(i, 2); b = pairs(i, 3);
    if usedExperiment(e) || usedBackground(b)
        continue
    end
    usedExperiment(e) = true; usedBackground(b) = true;
    accepted(end + 1, :) = [signalFrequency(e), backgroundFrequency(b), pairs(i, 1), ...
        signalAmplitude(e), backgroundAmplitude(b)]; %#ok<AGROW>
end
common.matches = array2table(sortrows(accepted, 1), 'VariableNames', ...
    {'Experiment_Frequency_Hz', 'Background_Frequency_Hz', 'Separation_Hz', ...
    'Experiment_Amplitude_ADC', 'Background_Amplitude_ADC'});
end

function [amplitude, frequency] = strong_peaks(a, f, common)
amplitude = zeros(0, 1); frequency = zeros(0, 1);
if numel(a) < 3 || max(a) <= 0
    return
end
cutoff = common.minimum_prominence_fraction * max(a);
[amplitude, frequency] = findpeaks(a, f, 'MinPeakProminence', cutoff, ...
    'MinPeakHeight', cutoff, 'MinPeakDistance', common.match_tolerance_hz);
end
