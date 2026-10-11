function plot_case(rawSignal, result, outputDir)
%PLOT_CASE Export data-faithful scientific figures at 300 dpi and as vector PDF.
% Plotting does not smooth, resample or modify any numerical analysis output.
style.signal = [0.12, 0.32, 0.53];
style.background = [0.78, 0.36, 0.16];
style.raw = [0.58, 0.61, 0.65];
style.ink = [0.16, 0.19, 0.23];
style.grid = [0.78, 0.80, 0.83];
draw_waveform(rawSignal, result, outputDir, style);
draw_fft(result, outputDir, style);
draw_power(result, outputDir, style);
end

function draw_waveform(rawSignal, result, outputDir, s)
fig = make_figure;
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'loose', 'Padding', 'loose');
heading(layout, 'Time-domain response', sprintf( ...
    'Independent recordings | %g kHz sampling | %.2f s analysis windows', ...
    result.config.fs / 1000, numel(result.signal.filtered) / result.config.fs), s);

ax = nexttile(layout, [1, 2]);
plot(ax, rawSignal(:, 1), rawSignal(:, 2), 'Color', s.raw, 'LineWidth', 0.8);
hold(ax, 'on');
limits = ylim(ax);
interval = result.config.signal_window_s;
patch(ax, [interval(1), interval(2), interval(2), interval(1)], ...
    [limits(1), limits(1), limits(2), limits(2)], s.signal, ...
    'FaceAlpha', 0.07, 'EdgeColor', 'none', 'HandleVisibility', 'off');
plot(ax, result.signal.time_s, result.signal.raw, 'Color', s.signal, 'LineWidth', 1.05);
xline(ax, interval(1), '--', 'Color', s.signal, 'HandleVisibility', 'off');
xline(ax, interval(2), '--', 'Color', s.signal, 'HandleVisibility', 'off');
text(ax, mean(interval), limits(2) - 0.05 * diff(limits), ...
    sprintf('Analysis window: %.2f-%.2f s', interval), ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
    'Color', s.signal, 'BackgroundColor', 'w', 'Margin', 3, 'FontSize', 10);
xlim(ax, [rawSignal(1, 1), rawSignal(end, 1)]);
ylim(ax, limits);
xlabel(ax, 'Recording time (s)'); ylabel(ax, 'ADC counts');
panel_title(ax, '(a) Full experiment record');
format_axes(ax, s);

ax = nexttile(layout);
plot(ax, result.signal.relative_time_s, result.signal.filtered, 'Color', s.signal, 'LineWidth', 0.9);
xlim(ax, [0, 1]);
xlabel(ax, 'Time within window (s)'); ylabel(ax, 'AC response (ADC counts)');
panel_title(ax, sprintf('(b) Experiment | %g-%g Hz', result.config.band_hz));
corner_label(ax, sprintf('RMS = %.2f ADC counts', result.signal.rms_adc), s.signal);
format_axes(ax, s);

ax = nexttile(layout);
plot(ax, result.background.relative_time_s, result.background.filtered, ...
    'Color', s.background, 'LineWidth', 0.85);
xlim(ax, [0, 1]);
xlabel(ax, 'Time within window (s)'); ylabel(ax, 'AC response (ADC counts)');
panel_title(ax, '(c) Background | independent y-scale');
corner_label(ax, sprintf('RMS = %.2f ADC counts', result.background.rms_adc), s.background);
format_axes(ax, s);
export_figure(fig, outputDir, 'waveform');
end

function draw_fft(result, outputDir, s)
fig = make_figure;
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig, 2, 1, 'TileSpacing', 'loose', 'Padding', 'loose');
heading(layout, 'FFT amplitude spectrum', sprintf( ...
    '%.2f s periodic Hann window | coherent-gain normalization | independent spectra', ...
    numel(result.signal.filtered) / result.config.fs), s);
f = result.fft.frequency_hz;
visible = f >= result.config.band_hz(1) & f <= result.config.band_hz(2);
ax = nexttile(layout);
loglog(ax, f(visible), positive_only(result.fft.signal_amplitude(visible)), ...
    'Color', s.signal, 'LineWidth', 0.9);
hold(ax, 'on');
loglog(ax, f(visible), positive_only(result.fft.background_amplitude(visible)), ...
    'Color', s.background, 'LineWidth', 0.9);
xlim(ax, result.config.band_hz);
ax.XTick = [20, 50, 100, 200, 500, 1000, 2000];
xlabel(ax, 'Frequency (Hz, logarithmic scale)'); ylabel(ax, 'Amplitude (ADC counts)');
panel_title(ax, '(a) Full analysis band');
legend(ax, {'Experiment', 'Background'}, 'Location', 'northeast', 'Box', 'off');
format_axes(ax, s);

ax = nexttile(layout);
zoom = f >= 20 & f <= 200;
plot(ax, f(zoom), result.fft.signal_amplitude(zoom), 'Color', s.signal, 'LineWidth', 1.15);
hold(ax, 'on');
plot(ax, f(zoom), result.fft.background_amplitude(zoom), 'Color', s.background, 'LineWidth', 0.9);
if isfinite(result.peak_frequency_hz)
    xline(ax, result.peak_frequency_hz, '--', 'Color', s.raw, 'HandleVisibility', 'off');
    corner_label(ax, sprintf('Largest FFT bin: %.2f Hz', result.peak_frequency_hz), s.signal);
end
xlim(ax, [20, 200]);
xlabel(ax, 'Frequency (Hz)'); ylabel(ax, 'Amplitude (ADC counts)');
panel_title(ax, '(b) Low-frequency detail | unsmoothed');
format_axes(ax, s);
export_figure(fig, outputDir, 'spectrum');
end

function draw_power(result, outputDir, s)
fig = make_figure;
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig, 2, 1, 'TileSpacing', 'loose', 'Padding', 'loose');
heading(layout, 'Power spectral density and band contributions', sprintf( ...
    'Welch estimate | %.2f s Hann segments | %g%% overlap | %d segments', ...
    result.config.welch_segment_samples / result.config.fs, ...
    100 * result.config.welch_overlap_samples / result.config.welch_segment_samples, ...
    result.psd.segment_count), s);
f = result.psd.frequency_hz;
visible = f >= result.config.band_hz(1) & f <= result.config.band_hz(2);
ax = nexttile(layout);
loglog(ax, f(visible), positive_only(result.psd.signal_density(visible)), ...
    'Color', s.signal, 'LineWidth', 1.25);
hold(ax, 'on');
loglog(ax, f(visible), positive_only(result.psd.background_density(visible)), ...
    'Color', s.background, 'LineWidth', 1.25);
xlim(ax, result.config.band_hz);
ax.XTick = [20, 50, 100, 200, 500, 1000, 2000];
xlabel(ax, 'Frequency (Hz, logarithmic scale)'); ylabel(ax, 'PSD (ADC counts^2/Hz)');
panel_title(ax, '(a) Welch power spectral density');
legend(ax, {'Experiment', 'Background'}, 'Location', 'northeast', 'Box', 'off');
format_axes(ax, s);

ax = nexttile(layout);
values = [result.bands.Experiment_Power_ADC2, result.bands.Background_Power_ADC2];
bars = bar(ax, values, 0.70, 'EdgeColor', 'none');
bars(1).FaceColor = s.signal;
bars(2).FaceColor = s.background;
ax.YScale = 'log';
ax.XTick = 1:height(result.bands);
ax.XTickLabel = result.bands.Band;
ylabel(ax, 'Integrated power (ADC counts^2)');
xlabel(ax, 'Frequency band | labels show experiment share of 20-2000 Hz power');
panel_title(ax, '(b) Band power | exact-edge PSD integration');
positive = values(values > 0);
if ~isempty(positive)
    ylim(ax, [10 ^ floor(log10(min(positive))), max(positive) * 8]);
end
for i = 1:height(result.bands)
    if result.bands.Experiment_Power_ADC2(i) > 0
        text(ax, bars(1).XEndPoints(i), bars(1).YEndPoints(i) * 1.3, ...
            sprintf('%.2f%%', 100 * result.bands.Experiment_Fraction(i)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
            'Color', s.signal, 'FontSize', 10);
    end
end
legend(ax, {'Experiment', 'Background'}, 'Location', 'northeast', 'Box', 'off');
format_axes(ax, s);
export_figure(fig, outputDir, 'power');
end

function fig = make_figure
fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'inches', ...
    'Position', [0.2, 0.2, 10.8, 7.2], ...
    'DefaultAxesFontName', 'Helvetica', 'DefaultAxesFontSize', 10.5, ...
    'DefaultTextFontName', 'Helvetica', 'DefaultTextFontSize', 10.5);
end

function heading(layout, titleText, subtitleText, s)
title(layout, titleText, 'FontSize', 18, 'FontWeight', 'bold', 'Color', s.ink);
subtitle(layout, subtitleText, 'FontSize', 10, 'Color', [0.40, 0.43, 0.47]);
end

function panel_title(ax, titleText)
title(ax, titleText, 'FontWeight', 'normal', 'FontSize', 11.5);
end

function corner_label(ax, label, color)
text(ax, 0.98, 0.93, label, 'Units', 'normalized', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
    'Color', color, 'BackgroundColor', 'w', 'Margin', 3, 'FontSize', 10);
end

function format_axes(ax, s)
ax.Box = 'off';
ax.TickDir = 'out';
ax.TickLength = [0.005, 0.005];
ax.LineWidth = 0.7;
ax.XColor = s.ink; ax.YColor = s.ink;
ax.YGrid = 'on'; ax.XGrid = 'off';
ax.GridColor = s.grid; ax.GridAlpha = 0.45;
ax.XMinorGrid = 'off'; ax.YMinorGrid = 'off';
end

function values = positive_only(values)
% Zero density has no logarithm; omit it from log plots, never alter the data.
values(values <= 0) = NaN;
end

function export_figure(fig, outputDir, basename)
exportgraphics(fig, fullfile(outputDir, [basename, '.png']), ...
    'Resolution', 300, 'BackgroundColor', 'white', 'Padding', 30);
exportgraphics(fig, fullfile(outputDir, [basename, '.pdf']), ...
    'ContentType', 'vector', 'BackgroundColor', 'white', 'Padding', 10);
end
