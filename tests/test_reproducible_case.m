function tests = test_reproducible_case
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
testCase.TestData.oldPath = path;
addpath(root, fullfile(root, 'src'));
runtime = fullfile(root, '.runtime');
if ~isfolder(runtime)
    mkdir(runtime);
end
work = tempname(runtime);
mkdir(work);
testCase.TestData.root = root;
testCase.TestData.work = work;
testCase.TestData.result = run_demo(fullfile(work, 'first'));
testCase.TestData.signal = readmatrix(fullfile(root, 'data', 'example_signal.csv'));
testCase.TestData.background = readmatrix(fullfile(root, 'data', 'example_background.csv'));
end

function teardownOnce(testCase)
path(testCase.TestData.oldPath);
end

function testPublishedNumericReference(testCase)
expected = readtable(fullfile(testCase.TestData.root, 'expected', 'metrics.csv'));
actual = testCase.TestData.result.metrics;
verifyEqual(testCase, actual.Metric, expected.Metric);
verifyEqual(testCase, actual.Unit, expected.Unit);
verifyEqual(testCase, actual.Value, expected.Value, 'RelTol', 1e-7, 'AbsTol', 1e-8);
end

function testIndependentOfWorkingDirectory(testCase)
originalFolder = pwd;
restoreFolder = onCleanup(@() cd(originalFolder));
cd(testCase.TestData.work);
second = run_demo(fullfile(testCase.TestData.work, 'second'));
verifyEqual(testCase, second.metrics.Value, testCase.TestData.result.metrics.Value);
verifyEqual(testCase, second.contrast_amplitude, testCase.TestData.result.contrast_amplitude);
files = {'waveform.png', 'spectrum.png', 'metrics.csv', 'spectrum.csv', ...
    'analysis.mat', 'run_metadata.json'};
for k = 1:numel(files)
    verifyTrue(testCase, isfile(fullfile(testCase.TestData.work, 'second', files{k})));
end
metadata = jsondecode(fileread(fullfile(testCase.TestData.work, 'second', 'run_metadata.json')));
verifyEqual(testCase, metadata.config.fs, 5000);
end

function testExampleDataRetainsOriginalSamples(testCase)
root = testCase.TestData.root;
sourceNames = {'Signal_0512_2320.xlsx', 'Background_0512_2319.xlsx'};
copies = {testCase.TestData.signal, testCase.TestData.background};
for k = 1:numel(sourceNames)
    source = readtable(fullfile(root, 'legacy', '02_Data', sourceNames{k}), 'UseExcel', false);
    verifyEqual(testCase, copies{k}(:, 2), source.ADC_Value);
    verifyEqual(testCase, copies{k}(:, 1), source.Time_s, 'AbsTol', 1e-12);
end
end

function testKnownToneFrequencyAndAmplitude(testCase)
config = testCase.TestData.result.config;
t = (0:4999)' / config.fs;
signal = [t + 0.6, 2048 + 100 * sin(2 * pi * 125 * t)];
background = [t, 2048 * ones(size(t))];
result = analyze_pair(signal, background, config);
verifyEqual(testCase, result.peak_frequency_hz, 125, 'AbsTol', config.fs / 8192);
verifyGreaterThan(testCase, max(result.contrast_amplitude), 95);
verifyLessThan(testCase, max(result.contrast_amplitude), 101);
verifyEqual(testCase, result.background.filtered, zeros(size(t)), 'AbsTol', 1e-10);
end

function testAmplitudeScalingPreservesRatio(testCase)
signal = testCase.TestData.signal;
background = testCase.TestData.background;
signal(:, 2) = 2 * signal(:, 2);
background(:, 2) = 2 * background(:, 2);
scaled = analyze_pair(signal, background, testCase.TestData.result.config);
actual = testCase.TestData.result;
verifyEqual(testCase, scaled.contrast_amplitude, 2 * actual.contrast_amplitude, 'AbsTol', 1e-9);
verifyEqual(testCase, scaled.metrics.Value(end), actual.metrics.Value(end), 'RelTol', 1e-9);
end

function testNonFiniteSamplesFail(testCase)
signal = testCase.TestData.signal;
signal(4000, 2) = NaN;
verifyError(testCase, @() analyze_pair(signal, testCase.TestData.background, ...
    testCase.TestData.result.config), 'Sloshing:NonFiniteData');
end

function testIncorrectSamplingRateFails(testCase)
signal = testCase.TestData.signal;
signal(:, 1) = 2 * signal(:, 1);
verifyError(testCase, @() analyze_pair(signal, testCase.TestData.background, ...
    testCase.TestData.result.config), 'Sloshing:SamplingMismatch');
end

function testIncompleteWindowFails(testCase)
signal = testCase.TestData.signal;
signal = signal(signal(:, 1) >= 0.62, :);
verifyError(testCase, @() analyze_pair(signal, testCase.TestData.background, ...
    testCase.TestData.result.config), 'Sloshing:MissingWindow');
end

function testUnequalWindowsFail(testCase)
config = testCase.TestData.result.config;
config.background_window_s = [0, 0.5];
verifyError(testCase, @() analyze_pair(testCase.TestData.signal, ...
    testCase.TestData.background, config), 'Sloshing:WindowMismatch');
end

function testConstantSignalDoesNotInventPeak(testCase)
signal = testCase.TestData.signal;
background = testCase.TestData.background;
signal(:, 2) = 2048;
background(:, 2) = 2048;
result = analyze_pair(signal, background, testCase.TestData.result.config);
verifyTrue(testCase, isnan(result.peak_frequency_hz));
verifyEqual(testCase, result.contrast_amplitude, zeros(size(result.frequency_hz)));
verifyTrue(testCase, isnan(result.metrics.Value(end)));
end
