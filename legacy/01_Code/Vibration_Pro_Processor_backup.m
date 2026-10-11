function Vibration_Pro_Processor
    % --- 1. 配置参数 ---
    fs = 5000; % 采样率
    global BG_STORAGE; % 用于跨次运行存储背景特征

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

    % 第一步：去异常 (使用 5 点中值滤波剔除传感器脉冲噪声)
    y_clean = medfilt1(y_raw, 5);

    % --- 3. 交互选区与智能对齐 ---
    hF = figure('Name', '点选冲击区间 (大致范围即可)', 'Position', [200, 200, 900, 450]);
    plot(t_raw, y_clean, 'Color', [0.7 0.7 0.7]); hold on; grid on;
    title('请点击【起点】和【终点】，划定冲击大致区间');
    [px, ~] = ginput(2);
    if length(px) < 2, close(hF); return; end
    
    % 智能对齐：寻找选区内真正的冲击峰值点
    sel_idx = find(t_raw >= min(px) & t_raw <= max(px));
    [~, local_peak] = max(abs(y_clean(sel_idx) - mean(y_clean(sel_idx))));
    center_pt = sel_idx(local_peak);
    
    % 自动截取有效段：向前取 100 点，向后取 900 点 (固定长度便于对比)
    final_range = max(1, center_pt-100) : min(length(y_clean), center_pt+900);
    y_seg = y_clean(final_range);
    t_seg = t_raw(final_range);

    % 修复 Patch 语法错误 (用 if-else 代替三元运算符)
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
    % 第二步：减均值 (去趋势处理)
    y_detrend = y_seg - mean(y_seg);
    
    % 第三步：带通滤波 (20Hz - 2000Hz 滤除低频晃动和高频白噪)
    [b_filt, a_filt] = butter(4, [20 2000]/(fs/2), 'bandpass');
    y_filt = filtfilt(b_filt, a_filt, y_detrend);
    
    % 第四步：加窗处理 (Hann 窗减小频谱泄露)
    L = length(y_filt);
    y_windowed = y_filt .* hann(L);

    % 第五步：转频域 (FFT)
    NFFT = 2^nextpow2(L);
    Y_fft = fft(y_windowed, NFFT);
    P2 = abs(Y_fft/L);
    P1 = P2(1:NFFT/2+1);
    P1(2:end-1) = 2*P1(2:end-1);
    freq_axis = fs*(0:(NFFT/2))/NFFT;

    % --- 5. 指标深度提取 ---
    v_idx = (freq_axis >= 20 & freq_axis <= 2000); % 有效频段索引
    f_v = freq_axis(v_idx); A_v = P1(v_idx);
    
    % 主峰频率与幅值
    [peak_amp, peak_i] = max(A_v);
    main_freq = f_v(peak_i);
    
    % 峰宽 (FWHM)
    half_max = peak_amp / 2;
    idx_above = find(A_v >= half_max);
    peak_width = f_v(max(idx_above)) - f_v(min(idx_above));
    
    % 频段能量 (50-300Hz vs 300-1000Hz)
    e_low = sum(P1(freq_axis >= 50 & freq_axis < 300).^2);
    e_high = sum(P1(freq_axis >= 300 & freq_axis <= 1000).^2);
    e_ratio = e_high / (e_low + 1e-12);

    % 谱质心 (Spectral Centroid)
    f_v = f_v(:);
    A_v = A_v(:);
    centroid = sum(f_v .* A_v) / (sum(A_v) + 1e-12);
    
    % 衰减常数 Tau (拟合包络)
    env = abs(hilbert(y_filt));
    [~, env_peak] = max(env);
    t_fit = (0:length(env)-env_peak)'/fs;
    y_fit = env(env_peak:end);
    valid_fit = y_fit > (0.1 * max(y_fit));
    if sum(valid_fit) > 10
        fit_p = polyfit(t_fit(valid_fit), log(y_fit(valid_fit)+1e-6), 1);
        tau = -1/fit_p(1);
    else
        tau = 0;
    end

    % --- 6. 差值对比逻辑 ---
    diff_val = 0;
    if strcmp(choice, '1. 提取背景(空瓶)')
        BG_STORAGE.amp = P1; BG_STORAGE.freq = freq_axis;
        msgbox('背景特征已记录！请再次运行选择模式2分析实验。'); return;
    elseif strcmp(choice, '2. 分析实验(对比)') && ~isempty(BG_STORAGE)
        bg_interp = interp1(BG_STORAGE.freq, BG_STORAGE.amp, freq_axis, 'linear', 0);
        diff_val = sum(P1(v_idx).^2) - sum(bg_interp(v_idx).^2);
    end

    % --- 7. 生成分析报表 ---
    fig = figure('Name', '完善版振动分析报告', 'Color', 'w', 'Position', [200, 100, 1000, 750]);
    
    % 频谱图展示
    subplot(2,2,1); plot(freq_axis, P1, 'LineWidth', 1.5);
    xlim([0 1200]); grid on; title('处理后频谱 (FFT)'); ylabel('幅值');
    
    % 衰减曲线展示
    subplot(2,2,2); plot(t_seg-t_seg(1), y_filt, 'Color', [0.8 0.8 0.8]); hold on;
    plot(t_seg-t_seg(1), env, 'r', 'LineWidth', 1.2); title('包络衰减拟合');

    % 数据报表表格
    subplot(2,2,3:4); axis off;
    data_cell = {
        '分析指标', '计算结果', '单位/物理意义';
        '主峰频率', sprintf('%.2f', main_freq), 'Hz (结构主振动)';
        '主峰幅值', sprintf('%.4f', peak_amp), 'ADC units';
        '峰宽 (FWHM)', sprintf('%.2f', peak_width), 'Hz (阻尼特性)';
        '50-300Hz 能量', sprintf('%.6f', e_low), '低频分量强度';
        '300-1000Hz 能量', sprintf('%.6f', e_high), '高频分量强度';
        '高低频能量比', sprintf('%.4f', e_ratio), '反映信号清脆程度';
        '谱质心', sprintf('%.2f', centroid), 'Hz (能量重心)';
        '衰减常数 Tau', sprintf('%.4f', tau), 's (衰减快慢)';
        '能量差值', sprintf('%.6f', diff_val), '空瓶 - 装液'
    };
    uitable(fig, 'Data', data_cell, 'Position', [50, 40, 900, 260], 'FontSize', 10, ...
            'ColumnWidth', {200, 200, 450});
end