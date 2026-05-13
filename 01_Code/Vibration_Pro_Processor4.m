function Vibration_Pro_Processor4
    % --- 1. 配置参数 ---
    fs = 5000; % 采样率

    bg_file = 'BG_STORAGE.mat';              % 背景频谱保存文件
    window_file = 'WINDOW_SETTING.mat';      % 固定选区长度保存文件

    % 模式选择对话框
    choice = questdlg('请选择处理模式：', '振动分析专家系统', ...
        '1. 提取背景(空瓶)', '2. 分析实验(对比)', '3. 独立分析', '3. 独立分析');
    if isempty(choice)
        return;
    end

    % --- 2. 数据加载与初步清洗 ---
    [f, p] = uigetfile('*.xlsx', '选择测试数据文件');
    if isequal(f,0)
        return;
    end

    raw_table = readtable(fullfile(p,f));
    t_raw = double(raw_table{:,1}); 
    y_raw = double(raw_table{:,2});

    % 第一步：去异常，使用 5 点中值滤波剔除传感器脉冲噪声
    y_clean = medfilt1(y_raw, 5);

    % --- 3. 交互选区：第一次两点确定长度，之后一点确定起点 ---
    hF = figure('Name', '点选分析区间', 'Position', [200, 200, 900, 450]);
    plot(t_raw, y_clean, 'Color', [0.7 0.7 0.7]); 
    hold on; 
    grid on;
    xlabel('Time / s');
    ylabel('Amplitude');

    % 判断是否已有固定窗口长度
    if exist(window_file, 'file')
        load(window_file, 'WINDOW_SETTING');
        window_duration = WINDOW_SETTING.window_duration;

        title(sprintf('已读取固定分析长度 %.4f s，请点击【起点】', window_duration));

        [px, ~] = ginput(1);

        if isempty(px)
            close(hF);
            return;
        end

        start_t = px(1);
        end_t = start_t + window_duration;

    else
        title('第一次运行：请点击【起点】和【终点】，程序将记录该分析长度');
        
        [px, ~] = ginput(2);

        if length(px) < 2
            close(hF);
            return;
        end

        start_t = min(px);
        end_t = max(px);

        window_duration = end_t - start_t;

        if window_duration <= 0
            close(hF);
            errordlg('选区长度无效，请重新选择。');
            return;
        end

        % 保存固定选区长度
        WINDOW_SETTING.window_duration = window_duration;
        WINDOW_SETTING.fs = fs;
        WINDOW_SETTING.created_time = datestr(now);
        WINDOW_SETTING.note = '第一次两点选择确定的固定分析窗口长度，后续运行只需点击起点。';

        save(window_file, 'WINDOW_SETTING');

        msgbox(sprintf('已记录固定分析长度：%.4f s。后续运行只需点击起点。', window_duration));
    end

    % 根据固定时间窗口截取数据
    final_range = find(t_raw >= start_t & t_raw <= end_t);

    if length(final_range) < 20
        close(hF);
        errordlg('选取的数据段太短，或起点太靠近数据末尾，请重新选择。');
        return;
    end

    y_seg = y_clean(final_range);
    t_seg = t_raw(final_range);

    % 在选区内寻找冲击峰，仅用于后续 Tau 拟合参考，不改变截取范围
    [~, local_peak] = max(abs(y_seg - mean(y_seg)));
    center_pt_local = local_peak;

    % 显示选区颜色
    if strcmp(choice, '1. 提取背景(空瓶)')
        fill_color = [0.8 1 0.8]; % 绿色
    else
        fill_color = [1 0.8 0.8]; % 红色
    end

    patch([min(t_seg) max(t_seg) max(t_seg) min(t_seg)], ...
          [min(y_raw) min(y_raw) max(y_raw) max(y_raw)], ...
          fill_color, 'FaceAlpha', 0.3, 'EdgeColor', 'none');

    % 标记起点和终点
    xline(start_t, 'g--', '起点');
    xline(end_t, 'r--', '终点');

    pause(0.7);
    close(hF);

    % --- 4. 核心处理步骤 ---
    % 第二步：减均值
    y_detrend = y_seg - mean(y_seg);
    
    % 第三步：带通滤波，20 Hz - 2000 Hz
    [b_filt, a_filt] = butter(4, [20 2000]/(fs/2), 'bandpass');
    y_filt = filtfilt(b_filt, a_filt, y_detrend);
    
    % 第四步：加 Tukey 窗，适合短时敲击衰减信号
    L = length(y_filt);

    if L < 20
        errordlg('有效数据段过短，无法进行频谱分析。');
        return;
    end

    w = tukeywin(L, 0.1);
    y_windowed = y_filt .* w;

    % 第五步：FFT
    NFFT = 2^nextpow2(L);
    Y_fft = fft(y_windowed, NFFT);

    P2 = abs(Y_fft / L);
    P1 = P2(1:NFFT/2+1);
    P1(2:end-1) = 2 * P1(2:end-1);

    freq_axis = fs * (0:(NFFT/2)) / NFFT;

    % --- 5. 背景谱减法 ---
    diff_val = 0;
    P1_clean = P1;  % 默认不扣背景

    if strcmp(choice, '1. 提取背景(空瓶)')
        BG_STORAGE.amp = P1;
        BG_STORAGE.freq = freq_axis;
        BG_STORAGE.fs = fs;
        BG_STORAGE.file = f;
        BG_STORAGE.time = datestr(now);
        BG_STORAGE.window_duration = window_duration;

        save(bg_file, 'BG_STORAGE');

        msgbox('背景特征已保存为 BG_STORAGE.mat！请再次运行选择模式2分析实验。');
        return;

    elseif strcmp(choice, '2. 分析实验(对比)')
        if exist(bg_file, 'file')
            load(bg_file, 'BG_STORAGE');

            bg_interp = interp1(BG_STORAGE.freq, BG_STORAGE.amp, freq_axis, 'linear', 0);

            % 频域总能量差值：装液 - 空瓶
            v_idx_temp = freq_axis >= 20 & freq_axis <= 2000;
            diff_val = sum(P1(v_idx_temp).^2) - sum(bg_interp(v_idx_temp).^2);

            % 能量谱减法：逐频点扣除背景能量
            P_clean_power = max(P1.^2 - bg_interp.^2, 0);
            P1_clean = sqrt(P_clean_power);
        else
            warndlg('未找到 BG_STORAGE.mat，当前将按独立分析处理。');
            P1_clean = P1;
            diff_val = 0;
        end
    end

    % --- 6. 指标深度提取 ---
    v_idx = freq_axis >= 20 & freq_axis <= 2000;
    f_v = freq_axis(v_idx);
    A_v = P1_clean(v_idx);

    f_v = f_v(:);
    A_v = A_v(:);
    
    % 主峰频率与幅值
    if isempty(A_v) || all(A_v == 0)
        main_freq = NaN;
        peak_amp = NaN;
        peak_width = NaN;
        centroid = NaN;
    else
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

        % 谱质心：能量加权谱质心
        P_v = A_v.^2;
        centroid = sum(f_v .* P_v) / (sum(P_v) + 1e-12);
    end
    
    % 频段能量，基于扣背景后的频谱 P1_clean
    idx_low = freq_axis >= 50 & freq_axis < 300;
    idx_high = freq_axis >= 300 & freq_axis <= 1000;

    e_low = sum(P1_clean(idx_low).^2);
    e_high = sum(P1_clean(idx_high).^2);
    e_ratio = e_high / (e_low + 1e-12);

    % --- 7. 衰减常数 Tau：限定早期自由衰减段 ---
    env = abs(hilbert(y_filt));
    
    % 对包络进行轻微平滑，减少局部波动
    smooth_win = max(3, round(0.005 * fs));  % 5 ms
    env = movmean(env, smooth_win);

    % 使用选区内冲击峰作为衰减起点
    env_peak = center_pt_local;

    % 如果局部峰位置不合理，则退回使用包络最大值
    if env_peak < 1 || env_peak > length(env)
        [~, env_peak] = max(env);
    end
    
    t_fit = (0:length(env)-env_peak)' / fs;
    y_fit = env(env_peak:end);
    
    % 跳过刚敲击的瞬态，拟合早期自由衰减段
    fit_start = 0.02;
    fit_end   = 0.25;

    % 如果用户选择的数据段很短，自动缩短 fit_end
    if ~isempty(t_fit)
        fit_end = min(fit_end, max(t_fit));
    end
    
    valid_fit = t_fit >= fit_start & ...
                t_fit <= fit_end & ...
                y_fit > 0.05 * max(y_fit) & ...
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

    % --- 8. 生成分析报表 ---
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
    plot(t_seg - t_seg(1), y_filt, 'Color', [0.8 0.8 0.8]);
    hold on;
    plot(t_seg - t_seg(1), env, 'r', 'LineWidth', 1.2);

    % 标记拟合区间
    if ~isnan(tau)
        fit_time_abs = t_seg(env_peak) - t_seg(1) + t_fit(valid_fit);
        fit_env = y_fit(valid_fit);
        plot(fit_time_abs, fit_env, 'b.', 'MarkerSize', 8);
        legend('滤波信号', '包络线', 'Tau拟合点');
    else
        legend('滤波信号', '包络线');
    end

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
        '能量差值', sprintf('%.6f', diff_val), '装液 - 空瓶';
        '固定选区长度', sprintf('%.4f', window_duration), 's (首次记录，后续沿用)';
        '本次实际长度', sprintf('%.4f', t_seg(end)-t_seg(1)), 's'
    };

    uitable(fig, 'Data', data_cell, 'Position', [50, 40, 900, 260], 'FontSize', 10, ...
            'ColumnWidth', {200, 200, 450});
end