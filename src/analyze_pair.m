function result = analyze_pair(signal, background, config)
%ANALYZE_PAIR Apply the same fixed analysis to an experiment and a background.
% Inputs are N-by-2 double matrices: [Time_s, ADC_Value].
validateattributes(config.fs, {'numeric'}, {'scalar', 'positive', 'finite'});
validateattributes(config.band_hz, {'numeric'}, {'vector', 'numel', 2, 'finite'});
if config.band_hz(1) <= 0 || config.band_hz(1) >= config.band_hz(2) || ...
        config.band_hz(2) >= config.fs / 2
    error('Sloshing:InvalidBand', 'Filter band must lie between 0 and fs/2.');
end
validateattributes(config.median_points, {'numeric'}, ...
    {'scalar', 'integer', 'positive', 'odd'});
validateattributes(config.filter_order, {'numeric'}, {'scalar', 'integer', 'positive'});
validateattributes(config.tukey_alpha, {'numeric'}, {'scalar', '>=', 0, '<=', 1});

signalSegment = select_segment(signal, config.signal_window_s, config, 'signal');
backgroundSegment = select_segment(background, config.background_window_s, config, 'background');
if numel(signalSegment.centered) ~= numel(backgroundSegment.centered)
    error('Sloshing:WindowMismatch', 'Signal and background windows must have equal sample counts.');
end
count = numel(signalSegment.centered);
if count <= 6 * config.filter_order + 1
    error('Sloshing:ShortWindow', 'Window is too short for zero-phase filtering.');
end

% SOS form avoids the numerical sensitivity of high-order polynomial filters.
[z, p, k] = butter(config.filter_order, config.band_hz / (config.fs / 2), 'bandpass');
[sos, gain] = zp2sos(z, p, k);
signalSegment.filtered = filtfilt(sos, gain, signalSegment.centered);
backgroundSegment.filtered = filtfilt(sos, gain, backgroundSegment.centered);
window = tukeywin(count, config.tukey_alpha);
nfft = 2 ^ nextpow2(count);
frequency = (0:nfft / 2)' * config.fs / nfft;
signalAmplitude = one_sided_amplitude(signalSegment.filtered, window, nfft);
backgroundAmplitude = one_sided_amplitude(backgroundSegment.filtered, window, nfft);
% This is a spectral contrast, not phase-coherent time-domain noise removal.
contrastAmplitude = sqrt(max(signalAmplitude .^ 2 - backgroundAmplitude .^ 2, 0));
band = frequency >= config.band_hz(1) & frequency <= config.band_hz(2);
bandFrequency = frequency(band);
bandAmplitude = contrastAmplitude(band);
peakFrequency = NaN;
centroid = NaN;
[peakAmplitude, peakIndex] = max(bandAmplitude);
if peakAmplitude > 0
    peakFrequency = bandFrequency(peakIndex);
    centroid = sum(bandFrequency .* bandAmplitude .^ 2) / sum(bandAmplitude .^ 2);
end
low = frequency >= 50 & frequency < 300;
high = frequency >= 300 & frequency <= 1000;
lowSquaredSum = sum(contrastAmplitude(low) .^ 2);
highSquaredSum = sum(contrastAmplitude(high) .^ 2);
highLowRatio = NaN;
if lowSquaredSum > 0
    highLowRatio = highSquaredSum / lowSquaredSum;
end

names = {'sample_rate_hz'; 'window_samples'; 'nfft'; 'fft_bin_spacing_hz'; ...
    'signal_filtered_rms_adc'; 'background_filtered_rms_adc'; ...
    'contrast_peak_frequency_hz'; 'contrast_peak_amplitude_adc'; ...
    'contrast_centroid_hz'; 'contrast_squared_sum_50_300_hz'; ...
    'contrast_squared_sum_300_1000_hz'; 'contrast_high_low_ratio'};
values = [config.fs; count; nfft; config.fs / nfft; ...
    sqrt(mean(signalSegment.filtered .^ 2)); sqrt(mean(backgroundSegment.filtered .^ 2)); ...
    peakFrequency; peakAmplitude; centroid; lowSquaredSum; highSquaredSum; highLowRatio];
units = {'Hz'; 'samples'; 'points'; 'Hz'; 'ADC counts'; 'ADC counts'; ...
    'Hz'; 'ADC counts'; 'Hz'; 'ADC counts^2 (fixed FFT grid)'; ...
    'ADC counts^2 (fixed FFT grid)'; 'dimensionless'};
result.metrics = table(names, values, units, 'VariableNames', {'Metric', 'Value', 'Unit'});
result.config = config;
result.signal = signalSegment;
result.background = backgroundSegment;
result.frequency_hz = frequency;
result.signal_amplitude = signalAmplitude;
result.background_amplitude = backgroundAmplitude;
result.contrast_amplitude = contrastAmplitude;
result.peak_frequency_hz = peakFrequency;
end

function segment = select_segment(data, interval, config, name)
validateattributes(data, {'double'}, {'2d', 'ncols', 2, 'real', 'nonempty'});
if any(~isfinite(data(:)))
    error('Sloshing:NonFiniteData', '%s contains NaN or Inf; no rows were discarded.', name);
end
validateattributes(interval, {'numeric'}, {'vector', 'numel', 2, 'finite'});
if interval(2) <= interval(1)
    error('Sloshing:InvalidWindow', '%s window end must exceed its start.', name);
end
time = data(:, 1);
step = diff(time);
if isempty(step) || any(step <= 0)
    error('Sloshing:InvalidTime', '%s timestamps must be strictly increasing.', name);
end
expectedStep = 1 / config.fs;
if max(abs(step - expectedStep)) > expectedStep * 1e-5
    error('Sloshing:SamplingMismatch', '%s timestamps do not match the configured sample rate.', name);
end
expectedCount = (interval(2) - interval(1)) * config.fs;
if expectedCount < 1 || abs(expectedCount - round(expectedCount)) > 1e-6
    error('Sloshing:InvalidWindow', '%s window must contain an integer number of samples.', name);
end
% Half-open intervals give 5000 samples for [0.60, 1.60) at 5000 Hz.
selected = time >= interval(1) - expectedStep * 1e-6 & ...
    time < interval(2) - expectedStep * 1e-6;
indices = find(selected);
if numel(indices) ~= round(expectedCount) || ...
        abs(time(indices(1)) - interval(1)) > expectedStep * 1e-5
    error('Sloshing:MissingWindow', '%s does not cover the full configured window.', name);
end
cleaned = medfilt1(data(:, 2), config.median_points);
segment.time_s = time(indices);
segment.relative_time_s = (0:numel(indices) - 1)' / config.fs;
segment.raw = data(indices, 2);
segment.centered = cleaned(indices) - mean(cleaned(indices));
end

function amplitude = one_sided_amplitude(samples, window, nfft)
% Normalize by the window's coherent gain; do not label this spectrum as PSD.
transformed = fft(samples .* window, nfft);
amplitude = abs(transformed(1:nfft / 2 + 1)) / sum(window);
amplitude(2:end - 1) = 2 * amplitude(2:end - 1);
end
