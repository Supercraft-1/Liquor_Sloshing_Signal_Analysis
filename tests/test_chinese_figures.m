function tests = test_chinese_figures
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
testCase.TestData.oldPath = path;
testCase.TestData.existingFigures = findall(groot, 'Type', 'figure');
addpath(root, fullfile(root, 'src'));
runtime = fullfile(root, '.runtime');
if ~isfolder(runtime)
    mkdir(runtime);
end
work = tempname(runtime);
mkdir(work);
oldDelete = get(groot, 'DefaultFigureDeleteFcn');
settingsRoot = settings;
themeSetting = settingsRoot.matlab.appearance.figure.GraphicsTheme;
oldTheme = themeSetting.ActiveValue;
hadTemporaryTheme = hasTemporaryValue(themeSetting);
restoreTheme = onCleanup(@() restore_theme(themeSetting, oldTheme, hadTemporaryTheme));
themeSetting.TemporaryValue = 'dark';
restoreSettings = onCleanup(@() set(groot, 'DefaultFigureDeleteFcn', oldDelete));
captured = {};
set(groot, 'DefaultFigureDeleteFcn', @captureFigure);
testCase.TestData.result = run_demo(work);
set(groot, 'DefaultFigureDeleteFcn', oldDelete);
restore_theme(themeSetting, oldTheme, hadTemporaryTheme);
clear restoreSettings
clear restoreTheme
testCase.TestData.figures = captured;
testCase.TestData.work = work;

    function captureFigure(fig, ~)
        % Inspect actual rendered graphics immediately before normal disposal.
        axesObjects = findall(fig, 'Type', 'axes');
        entry.axes = cell(1, numel(axesObjects));
        entry.theme = char(fig.Theme.BaseColorStyle);
        for i = 1:numel(axesObjects)
            ax = axesObjects(i);
            item.labels = {ax.XLabel.String, ax.YLabel.String, ax.Title.String};
            item.font = ax.FontName;
            item.background = ax.Color;
            item.xGrid = char(ax.XGrid);
            item.yGrid = char(ax.YGrid);
            item.yScale = ax.YScale;
            lineObjects = findall(ax, 'Type', 'line');
            item.lines = cell(1, numel(lineObjects));
            for j = 1:numel(lineObjects)
                line = lineObjects(j);
                item.lines{j} = struct('y', line.YData(:), 'x', line.XData(:), ...
                    'marker', line.Marker, 'style', line.LineStyle, ...
                    'yScale', ax.YScale, 'yLimits', ax.YLim);
            end
            entry.axes{i} = item;
        end
        texts = findall(fig, 'Type', 'text');
        entry.textSizes = arrayfun(@(t) t.FontSize, texts);
        entry.textColors = arrayfun(@(t) norm(t.Color), texts);
        entry.bars = numel(findall(fig, 'Type', 'bar'));
        images = findall(fig, 'Type', 'image');
        entry.images = arrayfun(@(im) struct('data', im.CData, 'alpha', im.AlphaData), ...
            images, 'UniformOutput', false);
        captured{end + 1} = entry;
    end
end

function teardownOnce(testCase)
path(testCase.TestData.oldPath);
end

function testAxesUseChineseLabels(testCase)
figures = testCase.TestData.figures;
verifyNumElements(testCase, figures, 4);
chinese = [];
for i = 1:numel(figures)
    for j = 1:numel(figures{i}.axes)
        item = figures{i}.axes{j};
        for k = 1:numel(item.labels)
            chinese(end + 1) = ~isempty(regexp(char(join(string(item.labels{k}), ' ')), ...
                '[\x{4E00}-\x{9FFF}]', 'once')); %#ok<AGROW>
        end
        verifyNotEqual(testCase, item.font, 'Helvetica');
    end
end
verifyTrue(testCase, all(chinese));
end

function testNoPresentationDecorations(testCase)
for entry = testCase.TestData.figures
    item = entry{1};
    verifyLessThanOrEqual(testCase, max(item.textSizes), 10);
    verifyEqual(testCase, item.textColors, zeros(size(item.textColors)));
    for axis = item.axes
        verifyEqual(testCase, axis{1}.xGrid, 'off');
        verifyEqual(testCase, axis{1}.yGrid, 'off');
    end
end
end

function testWhiteAxesUnderDarkDefaults(testCase)
for entry = testCase.TestData.figures
    verifyEqual(testCase, entry{1}.theme, 'light');
    for axis = entry{1}.axes
        verifyEqual(testCase, axis{1}.background, [1, 1, 1]);
    end
end
end

function testBandPowersAreUnconnectedPoints(testCase)
result = testCase.TestData.result;
verifyEqual(testCase, sum(cellfun(@(f) f.bars, testCase.TestData.figures)), 0);
experiment = findPlottedValues(testCase.TestData.figures, result.bands.Experiment_Power_ADC2);
background = findPlottedValues(testCase.TestData.figures, result.bands.Background_Power_ADC2);
assertNotEmpty(testCase, experiment);
assertNotEmpty(testCase, background);
verifyEqual(testCase, experiment.style, 'none');
verifyEqual(testCase, background.style, 'none');
verifyNotEqual(testCase, experiment.marker, background.marker);
verifyEqual(testCase, experiment.yScale, 'log');
verifyEqual(testCase, background.yScale, 'log');
end

function testDisplayedSpectraRetainAnalysisValues(testCase)
result = testCase.TestData.result;
inBand = result.fft.frequency_hz >= 20 & result.fft.frequency_hz <= 2000;
line = findPlottedValues(testCase.TestData.figures, result.fft.signal_amplitude(inBand));
assertNotEmpty(testCase, line);
verifyEqual(testCase, line.x, result.fft.frequency_hz(inBand));
inBand = result.psd.frequency_hz >= 20 & result.psd.frequency_hz <= 2000;
line = findPlottedValues(testCase.TestData.figures, result.psd.signal_density(inBand));
assertNotEmpty(testCase, line);
verifyEqual(testCase, line.x, result.psd.frequency_hz(inBand));
end

function testFigureCleanupDoesNotLeakWindows(testCase)
verifyEqual(testCase, findall(groot, 'Type', 'figure'), testCase.TestData.existingFigures);
end

function testShortTimeImagesUseUnmodifiedPSD(testCase)
images = {};
for entry = testCase.TestData.figures
    images = [images, entry{1}.images(:)']; %#ok<AGROW>
end
assertNumElements(testCase, images, 2);
d = testCase.TestData.result.diagnostics.time_frequency;
visible = d.signal.frequency_hz >= 20 & d.signal.frequency_hz <= 300;
expected = {10 * log10(d.signal.density(visible, :)), ...
    10 * log10(d.background.density(visible, :))};
for i = 1:2
    verifyTrue(testCase, any(cellfun(@(im) isequaln(im.data, expected{i}), images)));
end
end

function testDiagnosticPlotUsesActualLocalRMS(testCase)
r = testCase.TestData.result;
line = findPlottedValues(testCase.TestData.figures, r.diagnostics.responses.signal.rms_adc);
assertNotEmpty(testCase, line);
verifyEqual(testCase, line.x, r.signal.time_s);
high = r.config.bands_hz(:, 1) >= 300;
power = sum(r.diagnostics.time_frequency.signal.band_power_adc2(:, high), 2);
line = findPlottedValues(testCase.TestData.figures, power);
assertNotEmpty(testCase, line);
verifyGreaterThan(testCase, line.yLimits(2), 4 * max(power));
end

function testZeroResponseUsesReadableNonnegativeAxis(testCase)
c = case_config;
t = (0:12499)' / c.fs;
raw = [t, 2048 * ones(size(t))];
r = analyze_pair(raw, raw, c);
directory = fullfile(testCase.TestData.work, 'zero');
mkdir(directory);
previous = get(groot, 'DefaultFigureDeleteFcn');
restore = onCleanup(@() set(groot, 'DefaultFigureDeleteFcn', previous));
limits = [];
set(groot, 'DefaultFigureDeleteFcn', @captureZeroAxis);
plot_case(raw, r, directory);
assertNumElements(testCase, limits, 2);
verifyEqual(testCase, limits(1), 0);
verifyGreaterThanOrEqual(testCase, limits(2), 1);
verifyLessThanOrEqual(testCase, limits(2), 10);
verifyEqual(testCase, r.diagnostics.responses.signal.rms_adc, zeros(5000, 1));
set(groot, 'DefaultFigureDeleteFcn', previous);
clear restore

    function captureZeroAxis(fig, ~)
        axesObjects = findall(fig, 'Type', 'axes');
        for i = 1:numel(axesObjects)
            if contains(string(axesObjects(i).YLabel.String), '局部 RMS')
                limits = axesObjects(i).YLim;
            end
        end
    end
end

function found = findPlottedValues(figures, expected)
found = [];
for entry = figures
    for axis = entry{1}.axes
        for line = axis{1}.lines
            if isequal(line{1}.y, expected(:))
                found = line{1};
                return
            end
        end
    end
end
end

function restore_theme(setting, previous, hadTemporary)
if hadTemporary
    setting.TemporaryValue = previous;
elseif hasTemporaryValue(setting)
    clearTemporaryValue(setting);
end
end
