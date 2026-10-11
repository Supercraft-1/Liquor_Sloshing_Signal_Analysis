function result = run_demo(outputDir)
%RUN_DEMO 分析示例实验和背景记录。
%   RUN_DEMO 将图、频谱、指标和参数保存到 output/。
%   RESULT = RUN_DEMO(OUTPUTDIR) 可指定保存目录，并返回完整分析结果。
root = fileparts(mfilename('fullpath'));
if nargin == 0
    outputDir = fullfile(root, 'output');
end
validateattributes(outputDir, {'char', 'string'}, {'nonempty', 'row'});
outputDir = char(outputDir);
if ~license('test', 'Signal_Toolbox') || exist('pwelch', 'file') ~= 2
    error('Sloshing:MissingToolbox', 'Install and activate Signal Processing Toolbox.');
end
oldPath = path;
restorePath = onCleanup(@() path(oldPath));
addpath(fullfile(root, 'src'));

config = case_config;
signal = load_recording(fullfile(root, 'data', 'example_signal.csv'));
background = load_recording(fullfile(root, 'data', 'example_background.csv'));
result = analyze_pair(signal, background, config);
if ~isfolder(outputDir)
    [created, message] = mkdir(outputDir);
    if ~created
        error('Sloshing:OutputDirectory', 'Cannot create output directory: %s', message);
    end
end
export_results(result, outputDir);
plot_case(signal, result, outputDir);
fprintf('\n分析完成。\n');
fprintf('每窗口 %d 点，采样率 %g Hz，Welch 共 %d 帧\n', ...
    numel(result.signal.filtered), config.fs, result.psd.segment_count);
fprintf('AC RMS：实验 %.4f，背景 %.4f ADC 计数\n', ...
    result.signal.rms_adc, result.background.rms_adc);
fprintf('实验最大幅值频点：%.4f Hz\n', result.peak_frequency_hz);
fprintf('活动候选：实验 %d 段，背景 %d 段；邻近谱峰 %d 对\n', ...
    height(result.diagnostics.responses.signal.candidates), ...
    height(result.diagnostics.responses.background.candidates), ...
    height(result.diagnostics.common_peaks.matches));
fprintf('结果目录：%s\n', outputDir);
end
