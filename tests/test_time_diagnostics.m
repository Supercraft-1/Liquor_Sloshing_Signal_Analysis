function tests = test_time_diagnostics
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
testCase.TestData.oldPath = path;
addpath(fullfile(root, 'src'));
testCase.TestData.config = case_config;
testCase.TestData.time = (0:12499)' / 5000;
end

function teardownOnce(testCase)
path(testCase.TestData.oldPath);
end

function testFrameAverageRetainsWelchNormalization(testCase)
r = analyze_tones(testCase, 125, 125);
assertTrue(testCase, isfield(r, 'diagnostics'), 'Time-local diagnostics are missing.');
d = r.diagnostics.time_frequency;
verifyEqual(testCase, mean(d.signal.density, 2), r.psd.signal_density, ...
    'RelTol', 1e-12, 'AbsTol', 1e-12);
verifyEqual(testCase, mean(d.background.density, 2), r.psd.background_density, ...
    'RelTol', 1e-12, 'AbsTol', 1e-12);
end

function testFramePowerMatchesKnownToneAndParseval(testCase)
r = analyze_tones(testCase, 125, 125);
assertTrue(testCase, isfield(r, 'diagnostics'));
tf = r.diagnostics.time_frequency.signal;
power = sum(tf.density, 1)' * 5000 / 2048;
verifyEqual(testCase, power, 5000 * ones(9, 1), 'AbsTol', 2);
window = hann(1000, 'periodic');
for frame = 1:9
    indices = (frame - 1) * 500 + (1:1000);
    weighted = sum((r.signal.filtered(indices) .* window).^2) / sum(window.^2);
    verifyEqual(testCase, power(frame), weighted, 'RelTol', 1e-12);
end
end

function testFrameTimesReferToTheirOwnRecording(testCase)
r = analyze_tones(testCase, 125, 125);
assertTrue(testCase, isfield(r, 'diagnostics'));
tf = r.diagnostics.time_frequency;
verifyEqual(testCase, tf.signal.frame_start_s, (0.6:0.1:1.4)', 'AbsTol', 1e-12);
verifyEqual(testCase, tf.signal.frame_center_s, (0.7:0.1:1.5)', 'AbsTol', 1e-12);
verifyEqual(testCase, tf.signal.frame_end_s, (0.8:0.1:1.6)', 'AbsTol', 1e-12);
verifyEqual(testCase, tf.background.frame_center_s, (0.3:0.1:1.1)', 'AbsTol', 1e-12);
end

function testFrameBandAverageMatchesPublishedBandIntegration(testCase)
r = analyze_tones(testCase, 125, 125);
assertTrue(testCase, isfield(r, 'diagnostics'));
tf = r.diagnostics.time_frequency;
verifyEqual(testCase, mean(tf.signal.band_power_adc2, 1)', ...
    r.bands.Experiment_Power_ADC2, 'RelTol', 1e-12, 'AbsTol', 1e-10);
verifyEqual(testCase, mean(tf.background.band_power_adc2, 1)', ...
    r.bands.Background_Power_ADC2, 'RelTol', 1e-12, 'AbsTol', 1e-10);
end

function testTwoSeparatedBurstsYieldTwoCandidateIntervals(testCase)
r = analyze_bursts(testCase, [0.85, 1.25]);
assertTrue(testCase, isfield(r, 'diagnostics'));
c = r.diagnostics.responses.signal.candidates;
assertEqual(testCase, height(c), 2);
verifyEqual(testCase, c.Peak_Time_s, [0.85; 1.25], 'AbsTol', 0.02);
verifyLessThan(testCase, c.Start_Time_s, [0.85; 1.25]);
verifyGreaterThan(testCase, c.End_Time_s, [0.85; 1.25]);
verifyFalse(testCase, any(c.Boundary_Limited));
verifyLessThan(testCase, c.End_Time_s(1), c.Start_Time_s(2));
end

function testCloseBurstsAreMergedRatherThanClaimedIndependent(testCase)
r = analyze_bursts(testCase, [0.85, 0.88]);
assertTrue(testCase, isfield(r, 'diagnostics'));
c = r.diagnostics.responses.signal.candidates;
assertEqual(testCase, height(c), 1);
verifyLessThan(testCase, c.Start_Time_s, 0.85);
verifyGreaterThan(testCase, c.End_Time_s, 0.88);
end

function testWindowBoundaryBurstsAreMarkedLimited(testCase)
r = analyze_bursts(testCase, [0.601, 1.599]);
assertTrue(testCase, isfield(r, 'diagnostics'));
c = r.diagnostics.responses.signal.candidates;
assertEqual(testCase, height(c), 2);
verifyTrue(testCase, all(c.Boundary_Limited));
verifyGreaterThanOrEqual(testCase, c.Start_Time_s, 0.60);
verifyLessThanOrEqual(testCase, c.End_Time_s, 1.60 + 1e-12);
end

function testFullSupportEdgeWindowsAreNotMarkedShortened(testCase)
r = analyze_tones(testCase, 125, 125);
% Isolate RMS support geometry with two impulses in the filtered-input stage.
r.signal.filtered(:) = 0;
r.signal.filtered([100, 4901]) = 1;
r.config.diagnostics.merge_gap_s = 0;
d = analyze_diagnostics(r);
c = d.responses.signal.candidates;
assertEqual(testCase, height(c), 2);
verifyEqual(testCase, c.Start_Time_s(1), r.signal.time_s(50));
verifyEqual(testCase, c.End_Time_s(2), r.signal.time_s(4950) + 1 / r.config.fs);
verifyFalse(testCase, any(c.Boundary_Limited));
end

function testMergingBridgesAnActualBelowThresholdGap(testCase)
r = separated_activity_fixture(testCase);
r.config.diagnostics.merge_gap_s = 0;
separate = analyze_diagnostics(r);
assertEqual(testCase, height(separate.responses.signal.candidates), 2);
verifyGreaterThan(testCase, separate.responses.signal.candidates.Start_Time_s(2), ...
    separate.responses.signal.candidates.End_Time_s(1));
r.config.diagnostics.merge_gap_s = 0.040;
merged = analyze_diagnostics(r);
assertEqual(testCase, height(merged.responses.signal.candidates), 1);
verifyEqual(testCase, merged.responses.signal.candidates.Start_Time_s, ...
    separate.responses.signal.candidates.Start_Time_s(1));
verifyEqual(testCase, merged.responses.signal.candidates.End_Time_s, ...
    separate.responses.signal.candidates.End_Time_s(2));
end

function testMinimumActivityCountsActiveSamplesNotMergedSpan(testCase)
r = separated_activity_fixture(testCase);
r.config.diagnostics.merge_gap_s = 0.040;
accepted = analyze_diagnostics(r);
assertEqual(testCase, height(accepted.responses.signal.candidates), 1);
response = accepted.responses.signal;
verifyEqual(testCase, sum(response.rms_adc > response.threshold_adc), 22);
r.config.diagnostics.minimum_active_s = 0.005;
rejected = analyze_diagnostics(r);
verifyEqual(testCase, height(rejected.responses.signal.candidates), 0);
end

function testSteadyToneIsNotAnExcitationCandidate(testCase)
r = analyze_tones(testCase, 125, 125);
assertTrue(testCase, isfield(r, 'diagnostics'));
verifyEqual(testCase, height(r.diagnostics.responses.signal.candidates), 0);
verifyEqual(testCase, height(r.diagnostics.responses.background.candidates), 0);
end

function testZeroResponseDoesNotInventCandidatesOrPeaks(testCase)
t = testCase.TestData.time;
x = [t, 2048 * ones(size(t))];
r = analyze_pair(x, x, testCase.TestData.config);
assertTrue(testCase, isfield(r, 'diagnostics'));
verifyEqual(testCase, r.diagnostics.time_frequency.signal.density, zeros(1025, 9));
verifyEqual(testCase, r.diagnostics.responses.signal.rms_adc, zeros(5000, 1));
verifyEqual(testCase, height(r.diagnostics.responses.signal.candidates), 0);
verifyEqual(testCase, height(r.diagnostics.common_peaks.matches), 0);
end

function testCommonToneIsReportedWithoutRemovingIt(testCase)
r = analyze_tones(testCase, 50, 50);
assertTrue(testCase, isfield(r, 'diagnostics'));
peaks = r.diagnostics.common_peaks;
assertEqual(testCase, height(peaks.matches), 1);
verifyEqual(testCase, peaks.matches.Experiment_Frequency_Hz, 50, 'AbsTol', 0.611);
verifyEqual(testCase, peaks.matches.Background_Frequency_Hz, 50, 'AbsTol', 0.611);
verifyEqual(testCase, peaks.match_tolerance_hz, 2, 'AbsTol', 1e-12);
verifyGreaterThan(testCase, max(r.fft.signal_amplitude), 99);
end

function testDifferentTonesDoNotProduceCommonPeak(testCase)
r = analyze_tones(testCase, 125, 150);
assertTrue(testCase, isfield(r, 'diagnostics'));
verifyEqual(testCase, height(r.diagnostics.common_peaks.matches), 0);
end

function testNearbyToneIsOnlyASpectralCandidate(testCase)
r = analyze_tones(testCase, 50, 51);
assertTrue(testCase, isfield(r, 'diagnostics'));
matches = r.diagnostics.common_peaks.matches;
assertEqual(testCase, height(matches), 1);
verifyGreaterThan(testCase, matches.Separation_Hz, 0);
verifyLessThanOrEqual(testCase, matches.Separation_Hz, 2);
end

function testCompetingPeaksUseClosestOneToOneMatch(testCase)
r = analyze_tones(testCase, 125, 125);
r.fft.signal_amplitude(:) = 0;
r.fft.background_amplitude(:) = 0;
f = r.fft.frequency_hz;
[~, low] = min(abs(f - 49.5));
[~, high] = min(abs(f - 52));
[~, background] = min(abs(f - 50));
r.fft.signal_amplitude([low, high]) = [10, 9];
r.fft.background_amplitude(background) = 5;
d = analyze_diagnostics(r);
matches = d.common_peaks.matches;
assertEqual(testCase, height(matches), 1);
verifyEqual(testCase, matches.Experiment_Frequency_Hz, f(low));
verifyEqual(testCase, matches.Background_Frequency_Hz, f(background));
end

function testScalingPreservesIntervalsAndSquaresFramePower(testCase)
r = analyze_bursts(testCase, [0.85, 1.25], 1);
scaled = analyze_bursts(testCase, [0.85, 1.25], 2);
assertTrue(testCase, isfield(r, 'diagnostics'));
assertTrue(testCase, isfield(scaled, 'diagnostics'));
verifyEqual(testCase, scaled.diagnostics.responses.signal.candidates.Start_Time_s, ...
    r.diagnostics.responses.signal.candidates.Start_Time_s, 'AbsTol', 1e-12);
verifyEqual(testCase, scaled.diagnostics.responses.signal.threshold_adc, ...
    2 * r.diagnostics.responses.signal.threshold_adc, 'RelTol', 1e-12);
verifyEqual(testCase, scaled.diagnostics.time_frequency.signal.density, ...
    4 * r.diagnostics.time_frequency.signal.density, 'RelTol', 1e-10, 'AbsTol', 1e-12);
end

function testInvalidDiagnosticWindowFailsExplicitly(testCase)
c = testCase.TestData.config;
c.diagnostics.envelope_window_s = 0;
t = testCase.TestData.time;
x = [t, 2048 + 100 * sin(2 * pi * 125 * t)];
verifyError(testCase, @() analyze_pair(x, x, c), 'Sloshing:InvalidDiagnostics');
end

function r = analyze_tones(testCase, experimentFrequency, backgroundFrequency)
t = testCase.TestData.time;
x = [t, 2048 + 100 * sin(2 * pi * experimentFrequency * t)];
b = [t, 2048 + 10 * sin(2 * pi * backgroundFrequency * t)];
r = analyze_pair(x, b, testCase.TestData.config);
end

function r = separated_activity_fixture(testCase)
r = analyze_tones(testCase, 125, 125);
% Two separated, exactly known active runs; no bandpass tails or RMS overlap.
r.signal.filtered(:) = 0;
r.signal.filtered([500:509, 560:569]) = 1;
r.config.diagnostics.envelope_window_s = 2 / r.config.fs;
r.config.diagnostics.minimum_active_s = 0.002;
end

function r = analyze_bursts(testCase, centers, scale)
if nargin < 3
    scale = 1;
end
t = testCase.TestData.time;
x = 10 * sin(2 * pi * 50 * t);
for center = centers
    x = x + 200 * exp(-0.5 * ((t - center) / 0.008).^2) .* cos(2 * pi * 1000 * t);
end
r = analyze_pair([t, 2048 + scale * x], ...
    [t, 2048 * ones(size(t))], testCase.TestData.config);
end
