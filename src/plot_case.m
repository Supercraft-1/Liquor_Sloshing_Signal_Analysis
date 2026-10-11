function plot_case(rawSignal, result, outputDir)
%PLOT_CASE Chinese research figures; no smoothing or numerical modification.
s.signal = [0, 0, 0];
s.background = [0, 0.447, 0.698];
s.raw = [0.65, 0.65, 0.65];
s.font = chinese_font;
draw_waveform(rawSignal, result, outputDir, s);
draw_fft(result, outputDir, s);
draw_power(result, outputDir, s);
end

function draw_waveform(rawSignal, result, outputDir, s)
fig = make_figure(s);
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'loose', 'Padding', 'compact');
ax = nexttile(layout, [1, 2]);
plot(ax, rawSignal(:, 1), rawSignal(:, 2), 'Color', s.raw, 'LineWidth', 0.7);
hold(ax, 'on');
limits = ylim(ax);
limits(2) = limits(2) + 0.15 * diff(limits);
interval = result.config.signal_window_s;
plot(ax, result.signal.time_s, result.signal.raw, 'Color', s.signal, 'LineWidth', 0.7);
xline(ax, interval(1), '--', 'Color', s.raw, 'HandleVisibility', 'off');
xline(ax, interval(2), '--', 'Color', s.raw, 'HandleVisibility', 'off');
text(ax, mean(interval), limits(2) - 0.05 * diff(limits), ...
    sprintf('分析区间 %.2f-%.2f s', interval), ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
    'Color', 'k', 'FontSize', 8);
xlim(ax, [rawSignal(1, 1), rawSignal(end, 1)]);
ylim(ax, limits);
xlabel(ax, '记录时间（s）'); ylabel(ax, '幅值（ADC 计数）');
panel_title(ax, '(a) 原始实验记录');
format_axes(ax, s);

ax = nexttile(layout);
plot(ax, result.signal.relative_time_s, result.signal.filtered, ...
    'Color', s.signal, 'LineWidth', 0.7);
xlim(ax, [0, numel(result.signal.filtered) / result.config.fs]);
xlabel(ax, '区间内时间（s）'); ylabel(ax, '交流响应（ADC 计数）');
panel_title(ax, '(b) 实验响应');
corner_label(ax, sprintf('均方根 %.2f', result.signal.rms_adc));
format_axes(ax, s);

ax = nexttile(layout);
plot(ax, result.background.relative_time_s, result.background.filtered, ...
    'Color', s.background, 'LineWidth', 0.7);
xlim(ax, [0, numel(result.background.filtered) / result.config.fs]);
xlabel(ax, '区间内时间（s）'); ylabel(ax, '交流响应（ADC 计数）');
panel_title(ax, '(c) 背景响应（独立纵轴）');
corner_label(ax, sprintf('均方根 %.2f', result.background.rms_adc));
format_axes(ax, s);
export_figure(fig, outputDir, 'waveform');
end

function draw_fft(result, outputDir, s)
fig = make_figure(s);
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig, 2, 1, 'TileSpacing', 'loose', 'Padding', 'compact');
f = result.fft.frequency_hz;
visible = f >= result.config.band_hz(1) & f <= result.config.band_hz(2);
ax = nexttile(layout);
loglog(ax, f(visible), positive_only(result.fft.signal_amplitude(visible)), ...
    'Color', s.signal, 'LineWidth', 0.75);
hold(ax, 'on');
loglog(ax, f(visible), positive_only(result.fft.background_amplitude(visible)), ...
    'Color', s.background, 'LineStyle', '--', 'LineWidth', 0.75);
xlim(ax, result.config.band_hz);
ax.XTick = [20, 50, 100, 200, 500, 1000, 2000];
xlabel(ax, '频率（Hz）'); ylabel(ax, '幅值（ADC 计数）');
panel_title(ax, '(a) 完整频段幅值谱');
case_legend(ax);
format_axes(ax, s);

ax = nexttile(layout);
zoom = f >= 20 & f <= 200;
plot(ax, f(zoom), result.fft.signal_amplitude(zoom), 'Color', s.signal, 'LineWidth', 0.85);
hold(ax, 'on');
plot(ax, f(zoom), result.fft.background_amplitude(zoom), ...
    'Color', s.background, 'LineStyle', '--', 'LineWidth', 0.75);
if isfinite(result.peak_frequency_hz)
    xline(ax, result.peak_frequency_hz, '--', 'Color', s.raw, 'HandleVisibility', 'off');
    corner_label(ax, sprintf('最大幅值频点 %.2f Hz', result.peak_frequency_hz));
end
xlim(ax, [20, 200]);
xlabel(ax, '频率（Hz）'); ylabel(ax, '幅值（ADC 计数）');
panel_title(ax, '(b) 低频局部放大');
format_axes(ax, s);
export_figure(fig, outputDir, 'spectrum');
end

function draw_power(result, outputDir, s)
fig = make_figure(s);
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig, 2, 1, 'TileSpacing', 'loose', 'Padding', 'compact');
f = result.psd.frequency_hz;
visible = f >= result.config.band_hz(1) & f <= result.config.band_hz(2);
ax = nexttile(layout);
loglog(ax, f(visible), positive_only(result.psd.signal_density(visible)), ...
    'Color', s.signal, 'LineWidth', 0.85);
hold(ax, 'on');
loglog(ax, f(visible), positive_only(result.psd.background_density(visible)), ...
    'Color', s.background, 'LineStyle', '--', 'LineWidth', 0.75);
xlim(ax, result.config.band_hz);
ax.XTick = [20, 50, 100, 200, 500, 1000, 2000];
xlabel(ax, '频率（Hz）'); ylabel(ax, '功率谱密度（ADC 计数^2/Hz）');
panel_title(ax, '(a) Welch 功率谱密度');
case_legend(ax);
format_axes(ax, s);

ax = nexttile(layout);
values = [result.bands.Experiment_Power_ADC2, result.bands.Background_Power_ADC2];
positions = (1:height(result.bands))';
plot(ax, positions - 0.08, positive_only(values(:, 1)), 'o', ...
    'LineStyle', 'none', 'Color', s.signal, 'MarkerFaceColor', s.signal, 'MarkerSize', 4);
hold(ax, 'on');
plot(ax, positions + 0.08, positive_only(values(:, 2)), 's', ...
    'LineStyle', 'none', 'Color', s.background, 'MarkerFaceColor', 'w', 'MarkerSize', 4);
ax.YScale = 'log';
ax.XTick = 1:height(result.bands);
ax.XTickLabel = compose('%g-%g', result.bands.Low_Hz, result.bands.High_Hz);
xlim(ax, [0.5, height(result.bands) + 0.5]);
ylabel(ax, '频段均方响应（ADC 计数^2）'); xlabel(ax, '频段（Hz）');
panel_title(ax, '(b) 频段积分与实验占比');
positive = values(values > 0);
if ~isempty(positive)
    ylim(ax, [10 ^ floor(log10(min(positive))), max(positive) * 8]);
end
for i = 1:height(result.bands)
    if values(i, 1) > 0
        text(ax, positions(i) - 0.08, values(i, 1) * 1.3, ...
            sprintf('%.2f%%', 100 * result.bands.Experiment_Fraction(i)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
            'Color', 'k', 'FontSize', 8);
    end
end
case_legend(ax);
format_axes(ax, s);
export_figure(fig, outputDir, 'power');
end

function fig = make_figure(s)
fig = figure('Visible', 'off', 'Theme', 'light', 'Color', 'w', 'Units', 'centimeters', ...
    'Position', [1, 1, 18, 12.5], ...
    'DefaultAxesFontName', s.font, 'DefaultAxesFontSize', 8, ...
    'DefaultTextFontName', s.font, 'DefaultTextFontSize', 8, ...
    'DefaultTextColor', 'k');
end

function font = chinese_font
available = listfonts;
candidates = {'Noto Sans CJK SC', 'Microsoft YaHei UI', ...
    'Microsoft JhengHei', 'PingFang SC', 'Heiti SC', 'Noto Sans SC'};
for i = 1:numel(candidates)
    if any(strcmpi(available, candidates{i}))
        font = candidates{i};
        return
    end
end
error('Sloshing:MissingChineseFont', ...
    '请安装 Noto Sans SC 或 Noto Sans CJK SC 中文字体，再重新启动 MATLAB。');
end

function panel_title(ax, label)
title(ax, label, 'FontWeight', 'normal', 'FontSize', 8.5, ...
    'Color', 'k', 'HorizontalAlignment', 'left');
ax.Title.Units = 'normalized';
ax.Title.Position(1) = 0;
end

function corner_label(ax, label)
limits = ylim(ax);
ylim(ax, [limits(1), limits(2) + 0.15 * diff(limits)]);
text(ax, 0.98, 0.95, label, 'Units', 'normalized', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
    'Color', 'k', 'FontSize', 8);
end

function case_legend(ax)
legend(ax, {'实验记录', '背景记录'}, 'Location', 'northeast', ...
    'Box', 'off', 'FontSize', 7.5, 'TextColor', 'k');
end

function format_axes(ax, s)
ax.Box = 'off'; ax.TickDir = 'out'; ax.TickLength = [0.005, 0.005];
ax.LineWidth = 0.6; ax.FontName = s.font;
ax.XColor = 'k'; ax.YColor = 'k';
ax.Color = 'w';
ax.YGrid = 'off'; ax.XGrid = 'off';
ax.XMinorGrid = 'off'; ax.YMinorGrid = 'off';
end

function values = positive_only(values)
% Omit nonpositive values on log axes without changing stored analysis data.
values(values <= 0) = NaN;
end

function export_figure(fig, outputDir, basename)
exportgraphics(fig, fullfile(outputDir, [basename, '.png']), ...
    'Resolution', 600, 'BackgroundColor', 'white', 'Padding', 10);
exportgraphics(fig, fullfile(outputDir, [basename, '.pdf']), ...
    'ContentType', 'vector', 'BackgroundColor', 'white', 'Padding', 5);
end
