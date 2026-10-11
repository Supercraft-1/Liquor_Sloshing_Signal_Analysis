function result = analyze_pair(signal, background, config)
%ANALYZE_PAIR 分别处理实验和背景记录，计算频谱及指标。
% 输入为 N×2 双精度数组 [时间秒, ADC计数] 和参数结构体。
% 返回预处理窗口、独立 FFT／PSD、频段指标及短时分析结果。
% 兼容未提供 diagnostics 配置的调用。
if ~isfield(config, 'diagnostics')
    defaults = case_config;
    config.diagnostics = defaults.diagnostics;
end
validate_config(config);
validate_recording(signal, config.fs, 'experiment');
validate_recording(background, config.fs, 'background');

% 先对完整记录滤波，保留分析窗口前后的上下文。
[z, p, k] = butter(config.filter_order, config.band_hz / (config.fs / 2), 'bandpass');
[sos, gain] = zp2sos(z, p, k);
result.signal = process_recording(signal, config.signal_window_s, config, sos, gain);
result.background = process_recording(background, config.background_window_s, config, sos, gain);
count = numel(result.signal.filtered);
if count ~= numel(result.background.filtered)
    error('Sloshing:WindowMismatch', 'Experiment and background windows must have equal sample counts.');
end
validate_spectral_lengths(config, count);

% 幅值谱用窗系数和归一化，PSD 用窗平方和归一化。
fftWindow = hann(count, 'periodic');
result.fft.frequency_hz = (0:config.fft_nfft / 2)' * config.fs / config.fft_nfft;
result.fft.signal_amplitude = amplitude_spectrum(result.signal.filtered, fftWindow, config.fft_nfft);
result.fft.background_amplitude = amplitude_spectrum(result.background.filtered, fftWindow, config.fft_nfft);
welchWindow = hann(config.welch_segment_samples, 'periodic');
[result.psd.signal_density, result.psd.frequency_hz] = pwelch( ...
    result.signal.filtered, welchWindow, config.welch_overlap_samples, ...
    config.welch_nfft, config.fs, 'onesided');
result.psd.background_density = pwelch(result.background.filtered, welchWindow, ...
    config.welch_overlap_samples, config.welch_nfft, config.fs, 'onesided');
result.psd.segment_count = 1 + (count - config.welch_segment_samples) / ...
    (config.welch_segment_samples - config.welch_overlap_samples);
result.bands = band_metrics(result.psd, config.bands_hz);
result.config = config;

inBand = result.fft.frequency_hz >= config.band_hz(1) & ...
    result.fft.frequency_hz <= config.band_hz(2);
frequencies = result.fft.frequency_hz(inBand);
[peakAmplitude, peakIndex] = max(result.fft.signal_amplitude(inBand));
result.peak_frequency_hz = NaN;
if peakAmplitude > 0
    result.peak_frequency_hz = frequencies(peakIndex);
end
result.metrics = summary_metrics(result, peakAmplitude);
result.diagnostics = analyze_diagnostics(result);
end

function validate_config(config)
validateattributes(config.fs, {'numeric'}, {'scalar', 'real', 'positive', 'finite'});
validateattributes(config.band_hz, {'numeric'}, {'vector', 'numel', 2, 'real', 'finite'});
if config.band_hz(1) <= 0 || config.band_hz(1) >= config.band_hz(2) || ...
        config.band_hz(2) >= config.fs / 2
    error('Sloshing:InvalidBand', 'Filter band must lie strictly between 0 and fs/2.');
end
validateattributes(config.filter_order, {'numeric'}, {'scalar', 'integer', 'positive'});
validateattributes(config.fft_nfft, {'numeric'}, {'scalar', 'integer', 'positive', 'even'});
validateattributes(config.welch_nfft, {'numeric'}, {'scalar', 'integer', 'positive', 'even'});
validateattributes(config.welch_segment_samples, {'numeric'}, {'scalar', 'integer', '>=', 2});
validateattributes(config.welch_overlap_samples, {'numeric'}, {'scalar', 'integer', 'nonnegative'});
if config.welch_overlap_samples >= config.welch_segment_samples || ...
        config.welch_nfft < config.welch_segment_samples
    error('Sloshing:InvalidWelch', 'Welch overlap must be shorter than the segment; NFFT must cover it.');
end
validateattributes(config.bands_hz, {'numeric'}, {'2d', 'ncols', 2, 'real', 'finite', 'nonempty'});
if any(config.bands_hz(:, 1) < config.band_hz(1)) || ...
        any(config.bands_hz(:, 2) > config.band_hz(2)) || ...
        any(config.bands_hz(:, 1) >= config.bands_hz(:, 2))
    error('Sloshing:InvalidBands', 'Every reported band must lie within the analysis passband.');
end
end

function validate_recording(data, fs, name)
validateattributes(data, {'double'}, {'2d', 'ncols', 2, 'real', 'nonempty'});
if any(~isfinite(data(:)))
    error('Sloshing:NonFiniteData', '%s contains NaN or Inf; no samples were discarded.', name);
end
step = diff(data(:, 1));
if isempty(step) || any(step <= 0)
    error('Sloshing:InvalidTime', '%s timestamps must be strictly increasing.', name);
end
if max(abs(step - 1 / fs)) > 1 / fs * 1e-5
    error('Sloshing:SamplingMismatch', '%s timestamps do not match the configured sample rate.', name);
end
end

function segment = process_recording(data, interval, config, sos, gain)
validateattributes(interval, {'numeric'}, {'vector', 'numel', 2, 'real', 'finite'});
expectedCount = diff(interval) * config.fs;
if expectedCount < 1 || abs(expectedCount - round(expectedCount)) > 1e-6
    error('Sloshing:InvalidWindow', 'Window must span a positive integer number of samples.');
end
time = data(:, 1);
selected = time >= interval(1) - 1e-6 / config.fs & ...
    time < interval(2) - 1e-6 / config.fs;
indices = find(selected);
if numel(indices) ~= round(expectedCount) || ...
        abs(time(indices(1)) - interval(1)) > 1e-5 / config.fs
    error('Sloshing:MissingWindow', 'Recording does not cover the full configured window.');
end
if size(data, 1) <= 6 * config.filter_order
    error('Sloshing:ShortRecording', 'Complete recording is too short for zero-phase filtering.');
end
filtered = filtfilt(sos, gain, data(:, 2) - mean(data(:, 2)));
segment.time_s = time(indices);
segment.relative_time_s = (0:numel(indices) - 1)' / config.fs;
segment.raw = data(indices, 2);
segment.filtered = filtered(indices) - mean(filtered(indices));
segment.rms_adc = sqrt(mean(segment.filtered .^ 2));
end

function validate_spectral_lengths(config, count)
if config.fft_nfft < count
    error('Sloshing:InvalidFFT', 'FFT length must cover the complete analysis window.');
end
hop = config.welch_segment_samples - config.welch_overlap_samples;
if count < config.welch_segment_samples || mod(count - config.welch_segment_samples, hop) ~= 0
    error('Sloshing:InvalidWelch', 'Welch segments must cover the entire window without discarded samples.');
end
end

function amplitude = amplitude_spectrum(samples, window, nfft)
transformed = fft(samples .* window, nfft);
amplitude = abs(transformed(1:nfft / 2 + 1)) / sum(window);
amplitude(2:end - 1) = 2 * amplitude(2:end - 1);
end

function bands = band_metrics(psd, edges)
count = size(edges, 1);
experiment = zeros(count, 1);
background = zeros(count, 1);
labels = cell(count, 1);
for i = 1:count
    experiment(i) = integrate_psd(psd.frequency_hz, psd.signal_density, edges(i, :));
    background(i) = integrate_psd(psd.frequency_hz, psd.background_density, edges(i, :));
    labels{i} = sprintf('%g-%g Hz', edges(i, :));
end
fraction = NaN(count, 1);
if sum(experiment) > 0
    fraction = experiment / sum(experiment);
end
bands = table(labels, edges(:, 1), edges(:, 2), experiment, background, ...
    sqrt(experiment), sqrt(background), fraction, 'VariableNames', ...
    {'Band', 'Low_Hz', 'High_Hz', 'Experiment_Power_ADC2', 'Background_Power_ADC2', ...
    'Experiment_RMS_ADC', 'Background_RMS_ADC', 'Experiment_Fraction'});
end

function metrics = summary_metrics(result, peakAmplitude)
c = result.config;
f = result.psd.frequency_hz;
p = result.psd.signal_density;
signalPower = integrate_psd(f, p, c.band_hz);
backgroundPower = integrate_psd(f, result.psd.background_density, c.band_hz);
centroid = NaN;
ratio = NaN;
if signalPower > 0
    centroid = integrate_psd(f, f .* p, c.band_hz) / signalPower;
end
lowPower = integrate_psd(f, p, [50, 300]);
if lowPower > 0
    ratio = integrate_psd(f, p, [300, 1000]) / lowPower;
end
names = {'sample_rate_hz'; 'window_samples'; 'fft_nfft'; 'fft_bin_spacing_hz'; ...
    'welch_segment_count'; 'welch_bin_spacing_hz'; 'signal_filtered_rms_adc'; ...
    'background_filtered_rms_adc'; 'fft_peak_frequency_hz'; 'fft_peak_amplitude_adc'; ...
    'signal_psd_centroid_hz'; 'signal_20_2000_power_adc2'; ...
    'background_20_2000_power_adc2'; 'signal_300_1000_to_50_300_power_ratio'};
values = [c.fs; numel(result.signal.filtered); c.fft_nfft; c.fs / c.fft_nfft; ...
    result.psd.segment_count; c.fs / c.welch_nfft; result.signal.rms_adc; ...
    result.background.rms_adc; result.peak_frequency_hz; peakAmplitude; ...
    centroid; signalPower; backgroundPower; ratio];
units = {'Hz'; 'samples'; 'points'; 'Hz'; 'segments'; 'Hz'; 'ADC counts'; ...
    'ADC counts'; 'Hz'; 'ADC counts'; 'Hz'; 'ADC counts^2'; 'ADC counts^2'; 'dimensionless'};
metrics = table(names, values, units, 'VariableNames', {'Metric', 'Value', 'Unit'});
end
