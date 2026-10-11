function tests = test_spectral_method
% Analytical checks catch incorrect spectral normalization and band integration.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
testCase.TestData.oldPath = path;
addpath(fullfile(root, 'src'));
config.fs = 5000;
config.signal_window_s = [0.60, 1.60];
config.background_window_s = [0.20, 1.20];
config.filter_order = 4;
config.band_hz = [20, 2000];
config.fft_nfft = 8192;
config.welch_segment_samples = 1000;
config.welch_overlap_samples = 500;
config.welch_nfft = 2048;
config.bands_hz = [20, 50; 50, 300; 300, 1000; 1000, 2000];
testCase.TestData.config = config;
end

function teardownOnce(testCase)
path(testCase.TestData.oldPath);
end

function testKnownToneHasPhysicalMeanSquarePower(testCase)
% A missing fs/window normalization changes the expected A^2/2 power.
[signal, background] = tone_pair(125, 100, 0);
result = analyze_pair(signal, background, testCase.TestData.config);
assertTrue(testCase, isfield(result, 'psd'), 'Welch PSD is required.');
power = trapz(result.psd.frequency_hz, result.psd.signal_density);
verifyEqual(testCase, power, 5000, 'RelTol', 0.03);
verifyEqual(testCase, result.psd.background_density, ...
    zeros(size(result.psd.frequency_hz)), 'AbsTol', 1e-12);
verifyEqual(testCase, result.bands.Experiment_Power_ADC2(2), 5000, 'RelTol', 0.03);
end

function testSpectralPowerDoesNotGrowWithZeroPadding(testCase)
% Summing FFT amplitude squared instead of integrating PSD fails this check.
[signal, background] = tone_pair(125, 100, 0);
config = testCase.TestData.config;
coarse = analyze_pair(signal, background, config);
assertTrue(testCase, isfield(coarse, 'psd'), 'Welch PSD is required.');
config.welch_nfft = 8192;
fine = analyze_pair(signal, background, config);
verifyEqual(testCase, fine.bands.Experiment_Power_ADC2(2), ...
    coarse.bands.Experiment_Power_ADC2(2), 'RelTol', 0.01);
end

function testBackgroundDoesNotEraseExperimentFFT(testCase)
% Spectrum subtraction would remove this tone because background is stronger.
[signal, background] = tone_pair(125, 100, 150);
result = analyze_pair(signal, background, testCase.TestData.config);
verifyEqual(testCase, result.peak_frequency_hz, 125, 'AbsTol', 5000 / 8192);
assertTrue(testCase, isfield(result, 'fft'), 'Independent amplitude spectra are required.');
verifyEqual(testCase, max(result.fft.signal_amplitude), 100, 'RelTol', 0.03);
verifyEqual(testCase, max(result.fft.background_amplitude), 150, 'RelTol', 0.03);
end

function testLinearAmplitudeAndQuadraticPowerScaling(testCase)
[signal, background] = tone_pair(125, 100, 10);
original = analyze_pair(signal, background, testCase.TestData.config);
assertTrue(testCase, isfield(original, 'psd'), 'Welch PSD is required.');
signal(:, 2) = signal(:, 2) * 2;
background(:, 2) = background(:, 2) * 2;
scaled = analyze_pair(signal, background, testCase.TestData.config);
verifyEqual(testCase, scaled.fft.signal_amplitude, ...
    2 * original.fft.signal_amplitude, 'AbsTol', 1e-8);
verifyEqual(testCase, scaled.psd.signal_density, ...
    4 * original.psd.signal_density, 'AbsTol', 1e-7);
verifyEqual(testCase, scaled.bands.Experiment_Fraction, ...
    original.bands.Experiment_Fraction, 'AbsTol', 1e-10);
end

function testDCOffsetDoesNotChangeACResponse(testCase)
[signal, background] = tone_pair(125, 100, 10);
original = analyze_pair(signal, background, testCase.TestData.config);
signal(:, 2) = signal(:, 2) + 10000;
background(:, 2) = background(:, 2) - 20000;
shifted = analyze_pair(signal, background, testCase.TestData.config);
verifyEqual(testCase, shifted.signal.filtered, original.signal.filtered, 'AbsTol', 1e-7);
end

function testFilteringUsesSamplesOutsideAnalysisWindow(testCase)
% Cropping before filtfilt would make these two processed windows identical.
[signal, background] = tone_pair(125, 100, 0);
original = analyze_pair(signal, background, testCase.TestData.config);
signal(2951, 2) = signal(2951, 2) + 10000; % 0.5900 s, outside the window.
changed = analyze_pair(signal, background, testCase.TestData.config);
verifyGreaterThan(testCase, max(abs(changed.signal.filtered - original.signal.filtered)), 1);
end

function testBandIntegralIncludesInterpolatedBoundaries(testCase)
% A bin-count sum or snapping the band edges changes the literal area of 540.
assertEqual(testCase, exist('integrate_psd', 'file'), 2);
f = (0:10:100)';
verifyEqual(testCase, integrate_psd(f, 10 * ones(size(f)), [13, 67]), 540, 'AbsTol', 1e-10);
verifyEqual(testCase, integrate_psd(f, f, [13, 67]), 2160, 'AbsTol', 1e-10);
end

function testAdjacentBandsPartitionTotalPower(testCase)
assertEqual(testCase, exist('integrate_psd', 'file'), 2);
f = (0:10:100)';
p = f + 5;
parts = integrate_psd(f, p, [13, 50]) + integrate_psd(f, p, [50, 67]);
verifyEqual(testCase, parts, 2430, 'AbsTol', 1e-10);
end

function testConstantRecordingHasNoInventedPeakOrPower(testCase)
[signal, background] = tone_pair(125, 0, 0);
result = analyze_pair(signal, background, testCase.TestData.config);
assertTrue(testCase, isfield(result, 'psd'), 'Welch PSD is required.');
verifyTrue(testCase, isnan(result.peak_frequency_hz));
verifyEqual(testCase, result.bands.Experiment_Power_ADC2, zeros(4, 1));
verifyTrue(testCase, all(isnan(result.bands.Experiment_Fraction)));
end

function testInvalidWelchOverlapIsRejected(testCase)
[signal, background] = tone_pair(125, 100, 0);
config = testCase.TestData.config;
config.welch_overlap_samples = config.welch_segment_samples;
verifyError(testCase, @() analyze_pair(signal, background, config), 'Sloshing:InvalidWelch');
end

function [signal, background] = tone_pair(frequency, signalAmplitude, backgroundAmplitude)
t = (0:12499)' / 5000;
signal = [t, 2048 + signalAmplitude * sin(2 * pi * frequency * t)];
background = [t, 2048 + backgroundAmplitude * sin(2 * pi * frequency * t)];
end
