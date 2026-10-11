function Vibration_Dual_Acquirer_v11_5
    % --- 1. 参数与界面配置 ---
    fs = 5000; framePoints = 1024;
    s = []; isRecording = false; 
    allDataBuffer = []; lastUpdateTime = tic;

    fig = figure('Name', '振动采集与双文件导出系统', 'NumberTitle', 'off', ...
        'MenuBar', 'none', 'Position', [100, 100, 1150, 750], 'Color', [0.96 0.96 0.96]);

    % 控制面板
    ctrlPanel = uipanel(fig, 'Title', '采集控制 (导出两个Excel)', 'Position', [0.02, 0.4, 0.22, 0.55]);
    uicontrol(ctrlPanel, 'Style', 'text', 'String', '串口号:', 'Position', [10, 260, 50, 20]);
    portEdit = uicontrol(ctrlPanel, 'Style', 'edit', 'String', 'COM6', 'Position', [70, 260, 80, 25]);
    
    uicontrol(ctrlPanel, 'Style', 'pushbutton', 'String', '1. 连接串口', 'Position', [10, 210, 190, 35], ...
        'Callback', @connectDevice);
    
    % 分离的两个录制按钮
    bgBtn = uicontrol(ctrlPanel, 'Style', 'pushbutton', 'String', '录制: 背景(空瓶)', ...
        'Position', [10, 150, 190, 45], 'Enable', 'off', 'Callback', @(s,e)toggleRecord(s,'Background'));
    
    sigBtn = uicontrol(ctrlPanel, 'Style', 'pushbutton', 'String', '录制: 实验(带液)', ...
        'Position', [10, 90, 190, 45], 'Enable', 'off', 'Callback', @(s,e)toggleRecord(s,'Signal'));

    uicontrol(ctrlPanel, 'Style', 'pushbutton', 'String', '断开/复位', 'Position', [10, 30, 190, 35], ...
        'Callback', @disconnectDevice);

    % 绘图区
    ax1 = axes(fig, 'Position', [0.3, 0.58, 0.65, 0.35]); grid on;
    hLineTime = plot(ax1, zeros(1, fs), 'LineWidth', 1); ylim(ax1, [0 4096]);
    title(ax1, '实时时域 (1.0s)'); 
    
    ax2 = axes(fig, 'Position', [0.3, 0.12, 0.65, 0.35]); grid on;
    hLineFreq = plot(ax2, zeros(1, 513), 'Color', [0.85, 0.33, 0.1]);
    title(ax2, '实时频谱 (0-1000Hz)'); xlim(ax2, [0 1000]);

    uicontrol(fig, 'Style', 'pushbutton', 'String', '深度对比分析 (需选两个文件)', ...
        'Position', [20, 50, 220, 50], 'Callback', @deepComparison);

    %% --- 核心采集逻辑 ---
    function connectDevice(~, ~), try
        s = serialport(portEdit.String, 460800); % 匹配你之前代码的波特率
        s.Timeout = 0.1; flush(s);
        set([bgBtn, sigBtn], 'Enable', 'on');
        runMonitor();
    catch ME, errordlg(['连接失败: ' ME.message]); end; end

    function runMonitor()
        tempBuf = zeros(1, fs);
        while ~isempty(s) && ishandle(fig)
            while s.NumBytesAvailable >= (framePoints * 2 + 4)
                head = read(s, 2, "uint8");
                if head(1) == 170 && head(2) == 85
                    read(s, 2, "uint8"); 
                    raw = read(s, framePoints, "uint16");
                    if isRecording, allDataBuffer = [allDataBuffer, double(raw)]; end
                    tempBuf = [tempBuf(framePoints+1:end), double(raw)];
                else, read(s, 1, "uint8"); end
            end
            if toc(lastUpdateTime) > 0.05
                set(hLineTime, 'YData', tempBuf);
                Y = fft(tempBuf - mean(tempBuf)); P = abs(Y(1:513))/fs;
                set(hLineFreq, 'YData', P);
                drawnow limitrate; lastUpdateTime = tic;
            end
            pause(0.005);
        end
    end

    function toggleRecord(src, type)
        if ~isRecording
            allDataBuffer = []; isRecording = true;
            set(src, 'String', ['录制中(点击停止)...'], 'BackgroundColor', [1 0.6 0.6]);
            set([bgBtn, sigBtn], 'Enable', 'off'); set(src, 'Enable', 'on');
        else
            isRecording = false;
            set(src, 'String', ['录制: ', type], 'BackgroundColor', [0.94 0.94 0.94]);
            set([bgBtn, sigBtn], 'Enable', 'on');
            % 保存为对应的 Excel
            saveExcel(type);
        end
    end

    function saveExcel(type)
        if isempty(allDataBuffer), return; end
        % 默认文件名
        defaultName = [type, '_', datestr(now, 'mmdd_HHMM'), '.xlsx'];
        [file, path] = uiputfile('*.xlsx', ['保存', type, '数据'], defaultName);
        if isequal(file, 0), return; end
        
        t_col = (0:length(allDataBuffer)-1)'/fs;
        writetable(table(t_col, allDataBuffer', 'VariableNames', {'Time_s', 'ADC_Value'}), ...
            fullfile(path, file));
        fprintf('已保存 %s 数据到: %s\n', type, file);
    end

    function disconnectDevice(~, ~)
        if ~isempty(s), delete(s); s = []; end
        set([bgBtn, sigBtn], 'Enable', 'off');
    end

    %% --- 深度对比分析 (自动关联背景和信号) ---
    function deepComparison(~, ~)
        msgbox('请先选择【背景(空瓶)】文件，再选择【信号】文件');
        [f_bg, p_bg] = uigetfile('*.xlsx', '第一步：选择背景(空瓶)Excel');
        if isequal(f_bg, 0), return; end
        [f_sig, p_sig] = uigetfile('*.xlsx', '第二步：选择实验信号Excel');
        if isequal(f_sig, 0), return; end
        
        % 读取数据
        d_bg = readtable(fullfile(p_bg, f_bg));
        d_sig = readtable(fullfile(p_sig, f_sig));
        
        % 信号段提取 (自动对齐冲击点)
        y_s = d_sig.ADC_Value - mean(d_sig.ADC_Value);
        [~, max_i] = max(abs(y_s));
        s_idx = max(1, max_i-200); e_idx = min(length(y_s), s_idx+2000);
        ya_sig = y_s(s_idx:e_idx);
        
        % 背景段提取 (取前 2000 点)
        ya_bg = d_bg.ADC_Value(1:min(2001, end)) - mean(d_bg.ADC_Value);
        
        % FFT 能量对比
        L = length(ya_sig);
        P_sig = abs(fft(ya_sig .* hann(L)')/L).^2;
        P_bg = abs(fft(ya_bg(1:L) .* hann(L)')/L).^2;
        f_ax = fs*(0:L/2)/L;
        
        % 绘图展示差值
        resF = figure('Name', '双文件能量对比报告', 'Color', 'w');
        subplot(2,1,1);
        plot(f_ax, P_sig(1:length(f_ax)), 'r', 'DisplayName', '实验信号'); hold on;
        plot(f_ax, P_bg(1:length(f_ax)), 'k--', 'DisplayName', '背景噪声');
        xlim([0 1000]); title('能量谱对比 (PSD)'); legend; grid on;
        
        subplot(2,1,2);
        diff_P = P_sig - P_bg;
        plot(f_ax, diff_P(1:length(f_ax)), 'b');
        xlim([0 1000]); title('净信号能量 (实验 - 背景)'); grid on;
        
        % 指标显示
        total_diff = sum(diff_P(f_ax > 20));
        text(500, max(diff_P)*0.8, sprintf('净能量增量: %.4f', total_diff), ...
            'FontSize', 12, 'FontWeight', 'bold', 'Color', 'r');
    end
end