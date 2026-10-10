# Liquid Sloshing Signal Analysis

这是液态样品声振检测课题前期留下的 MATLAB 采集和分析测试代码，主要用于摸清数据链路与可观察的信号特征。**它不是完整仪器软件，也没有经过液体识别性能验证。**

*Early MATLAB test scripts for acquiring and exploring vibration data from liquid-filled containers; not a validated classification system.*

## 代码范围

- `01_Code/Vibration_Dual_Acquirer_v11_5.m`：从串口接收数据，显示实时波形与频谱，分别记录空瓶背景和装液实验信号，并导出 Excel。
- `01_Code/Vibration_Pro_Processor*.m`：交互选取分析区间，对信号进行滤波、FFT 和背景对比，探索主峰、频段能量及自由衰减等特征。仓库保留了多个实验版本，不应视为一个已封装的软件产品。
- `02_Data/`：随仓库公开的实验数据文件；使用前请核对文件格式和实验条件。

## 使用前

1. 准备 MATLAB；处理脚本使用了 Signal Processing Toolbox 中的滤波与窗函数。
2. 若要实时采集，先确认串口固件与脚本的数据帧格式一致，并在采集脚本中把默认串口号、波特率和采样率改为实际设备参数。
3. 若只做离线分析，可以从 `01_Code/` 中选择适合数据格式的处理脚本；不同版本的输入和交互步骤并不完全相同。

当前代码中的部分参数和路径服务于特定实验装置，尚未整理为通用安装包。结果应结合传感器、激励方式和独立实验验证，不宜仅凭本仓库代码推断检测精度。
