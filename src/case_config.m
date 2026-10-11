function config = case_config
%CASE_CONFIG Fixed parameters for the single published recording pair.
% Edit here only when intentionally revising the case and its references.
config.fs = 5000;
config.signal_window_s = [0.60, 1.60];
config.background_window_s = [0.20, 1.20];
config.filter_order = 4;                 % Butterworth prototype order.
config.band_hz = [20, 2000];
config.fft_nfft = 8192;
config.welch_segment_samples = 1000;     % 0.20 s, periodic Hann window.
config.welch_overlap_samples = 500;      % 50% overlap; 9 complete segments.
config.welch_nfft = 2048;
config.bands_hz = [20, 50; 50, 300; 300, 1000; 1000, 2000];
end
