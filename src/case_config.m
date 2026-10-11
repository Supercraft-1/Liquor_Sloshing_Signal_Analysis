function config = case_config
%CASE_CONFIG 示例实验与背景记录的固定分析参数。
config.fs = 5000;
config.signal_window_s = [0.60, 1.60];
config.background_window_s = [0.20, 1.20];
config.filter_order = 4;                 % Butterworth 原型阶数。
config.band_hz = [20, 2000];
config.fft_nfft = 8192;
config.welch_segment_samples = 1000;     % 0.20 s 周期 Hann 窗。
config.welch_overlap_samples = 500;      % 50% 重叠，共 9 个完整帧。
config.welch_nfft = 2048;
config.bands_hz = [20, 50; 50, 300; 300, 1000; 1000, 2000];
% 短时诊断参数，不影响 FFT／Welch 汇总指标。
config.diagnostics.envelope_window_s = 0.020;
config.diagnostics.threshold_mad_multiplier = 4;
config.diagnostics.minimum_relative_rise = 0.25;
config.diagnostics.merge_gap_s = 0.040;
config.diagnostics.minimum_active_s = 0.006;
config.diagnostics.peak_prominence_fraction = 0.05;
end
