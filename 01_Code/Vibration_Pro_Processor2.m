function Vibration_Pro_Processor2
    % --- 1. 配置参数 ---
    fs = 5000; % 采样率

    bg_file = 'BG_STORAGE.mat'; % 背景频谱保存文件

    % 模式选择对话框
    choice = questdlg('请选择处理模式：', '振动分析专家系统', ...
        '1. 提取背景(空瓶)', '2. 分析实验(对比)', '3. 独立分析', '3. 独立分析');
    if isempty(choice), return; end

    % --- 2. 数据加载与初步清洗 ---
    [f, p] = uigetfile('*.xlsx', '选择测试数据文件');
    if isequal(f,0), return; end
    raw_table = readtable(fullfile(p,f));
    t_raw = double(raw_table{:,1}); 
    y_raw = double(raw_table{:,2});

    % 第一步：去异常，使用 5 点中值滤波剔除传感器脉冲噪声
    y_clean = medfilt1(y_raw, 5);

    % --- 3. 交互选区与智能对齐 ---
    hF = figure('Name', '点选冲击区间 (大致范围即可)', 'Position', [200, 200, 900, 450]);
    plot(t_raw, y_clean, 'Color', [0.7 0.7 0.7]); hold on; grid on;
    title('请点击【起点】和【终点】，划定冲击大致区间');
    [px, ~] = ginput(2);
    if length(px) < 2
        close(hF);
        return;
    end
    
    % 智能对齐：寻找选区内真正的冲击峰值点
    sel_idx = find(t_raw >= min(px) & t_raw <= max(px));
    [~, local_peak] = max(abs(y_clean(sel_idx) - mean(y_clean(sel_idx))));
    center_pt = sel_idx(local_peak);
    
    % 自动截取有效段：
    % 前 0.04 s，后 0.96 s，总长度约 1.0 s
    pre_points = round(0.04 * fs);
    post_points = round(0.96 * fs);

    final_range = max(1, center_pt-pre_points) : min(length(y_clean), center_pt+post_points);
    y_seg = y_clean(final_range);
    t_seg = t_raw(final_range);

    % 显示选区颜色
    if strcmp(choice, '1. 提取背景(空瓶)')
        fill_color = [0.8 1 0.8]; % 绿色
    else
        fill_color = [1 0.8 0.8]; % 红色
    end

    patch([min(t_seg) max(t_seg) max(t_seg) min(t_seg)], ...
          [min(y_raw) min(y_raw) max(y_raw) max(y_raw)], ...
          fill_color, 'FaceAlpha', 0.3, 'EdgeColor', 'none');
    pause(0.5); close(hF);

    % --- 4. 核心处理步骤 ---
    % 第二步：减均值
    y_detrend = y_seg - mean(y_seg);
    
    % 第三步：带通滤波，20 Hz - 2000 Hz
    [b_filt, a_filt] = butter(4, [20 2000]/(fs/2), 'bandpass');
    y_filt = filtfilt(b_filt, a_filt, y_detrend);
    
    % 第四步：加 Hann 窗
    L = length(y_filt);
    y_windowed = y_filt .* hann(L);

    % 第五步：FFT
    NFFT = 2^nextpow2(L);
    Y_fft = fft(y_windowed, NFFT);
    P2 = abs(Y_fft/L);
    P1 = P2(1:NFFT/2+1);
    P1(2:end-1) = 2*P1(2:end-1);
    freq_axis = fs*(0:(NFFT/2))/NFFT;

    % --- 5. 背景谱减法 ---
    diff_val = 0;
    P1_clean = P1;  % 默认不扣背景

    if strcmp(choice, '1. 提取背景(空瓶)')
        BG_STORAGE.amp = P1;
        BG_STORAGE.freq = freq_axis;
        BG_STORAGE.fs = fs;
        BG_STORAGE.file = f;
        BG_STORAGE.time = datestr(now);

        save(bg_file, 'BG_STORAGE');

        msgbox('背景特征已保存为 BG_STORAGE.mat！请再次运行选择模式2分析实验。');
        return;

    elseif strcmp(choice, '2. 分析实验(对比)')
        if exist(bg_file, 'file')
            load(bg_file, 'BG_STORAGE');

            bg_interp = interp1(BG_STORAGE.freq, BG_STORAGE.amp, freq_axis, 'linear', 0);

            % 频域总能量差值
            v_idx_temp = freq_axis >= 20 & freq_axis <= 2000;
            diff_val = sum(P1(v_idx_temp).^2) - sum(bg_interp(v_idx_temp).^2);

            % 能量谱减法
            P_clean_power = max(P1.^2 - bg_interp.^2, 0);
            P1_clean = sqrt(P_clean_power);
        else
            warndlg('未找到 BG_STORAGE.mat，当前将按独立分析处理。');
            P1_clean = P1;
            diff_val = 0;
        end
    end

    % --- 6. 指标深度提取 ---
    v_idx = (freq_axis >= 20 & freq_axis <= 2000);
    f_v = freq_axis(v_idx);
    A_v = P1_clean(v_idx);

    f_v = f_v(:);
    A_v = A_v(:);
    
    % 主峰频率与幅值
    [peak_amp, peak_i] = max(A_v);
    main_freq = f_v(peak_i);
    
    % 峰宽：半功率带宽法
    half_power = peak_amp / sqrt(2);

    left_i = find(A_v(1:peak_i) <= half_power, 1, 'last');
    right_rel = find(A_v(peak_i:end) <= half_power, 1, 'first');

    if ~isempty(left_i) && ~isempty(right_rel)
        right_i = peak_i + right_rel - 1;
        peak_width = f_v(right_i) - f_v(left_i);
    else
        peak_width = NaN;
    end
    
    % 频段能量，基于扣背景后的频谱 P1_clean
    idx_low = freq_axis >= 50 & freq_axis < 300;
    idx_high = freq_axis >= 300 & freq_axis <= 1000;

    e_low = sum(P1_clean(idx_low).^2);
    e_high = sum(P1_clean(idx_high).^2);
    e_ratio = e_high / (e_low + 1e-12);

    % 谱质心：能量加权谱质心
    P_v = A_v.^2;
    centroid = sum(f_v .* P_v) / (sum(P_v) + 1e-12);
    
    % 衰减常数 Tau：限定拟合时间段
    env = abs(hilbert(y_filt));
    [~, env_peak] = max(env);

    t_fit = (0:length(env)-env_peak)' / fs;
    y_fit = env(env_peak:end);

    % 只拟合包络峰值后的 0.8 s，避免后期噪声影响
    fit_time_max = 0.8;

    valid_fit = t_fit <= fit_time_max & ...
                y_fit > 0.1 * max(y_fit) & ...
                y_fit > 1e-6;

    if sum(valid_fit) > 10
        fit_p = polyfit(t_fit(valid_fit), log(y_fit(valid_fit) + 1e-6), 1);

        if fit_p(1) < 0
            tau = -1 / fit_p(1);
        else
            tau = NaN;
        end
    else
        tau = NaN;
    end

    % --- 7. 生成分析报表 ---
    fig = figure('Name', '完善版振动分析报告', 'Color', 'w', 'Position', [200, 100, 1000, 750]);
    
    % 频谱图展示
    subplot(2,2,1);
    plot(freq_axis, P1_clean, 'LineWidth', 1.5);
    xlim([0 1200]);
    grid on;
    title('处理后频谱 FFT');
    ylabel('幅值');
    xlabel('Frequency / Hz');
    
    % 衰减曲线展示
    subplot(2,2,2);
    plot(t_seg-t_seg(1), y_filt, 'Color', [0.8 0.8 0.8]);
    hold on;
    plot(t_seg-t_seg(1), env, 'r', 'LineWidth', 1.2);
    title('包络衰减拟合');
    xlabel('Time / s');
    ylabel('Amplitude');

    % 数据报表表格
    subplot(2,2,3:4);
    axis off;

    data_cell = {
        '分析指标', '计算结果', '单位/物理意义';
        '主峰频率', sprintf('%.2f', main_freq), 'Hz (结构主振动)';
        '主峰幅值', sprintf('%.4f', peak_amp), 'ADC units';
        '峰宽 半功率带宽', sprintf('%.2f', peak_width), 'Hz (阻尼特性)';
        '50-300Hz 能量', sprintf('%.6f', e_low), '低频分量强度';
        '300-1000Hz 能量', sprintf('%.6f', e_high), '高频分量强度';
        '高低频能量比', sprintf('%.4f', e_ratio), '反映信号清脆程度';
        '谱质心', sprintf('%.2f', centroid), 'Hz (能量重心)';
        '衰减常数 Tau', sprintf('%.4f', tau), 's (衰减快慢)';
        '能量差值', sprintf('%.6f', diff_val), '装液 - 空瓶'
    };

    uitable(fig, 'Data', data_cell, 'Position', [50, 40, 900, 260], 'FontSize', 10, ...
            'ColumnWidth', {200, 200, 450});
end