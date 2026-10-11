# 振动信号离线分析：一个可复现的 MATLAB 案例

从一段已采集的实验记录出发，完成固定区间截取、滤波、FFT 和背景频谱对照。数据、参数和参考图都在仓库里，运行入口只有 **`run_demo.m`**。

这是液态样品声振检测课题中的一次信号处理案例。初次运行不需要采集设备，也不需要在几个历史实验版本之间选择。

## 运行

准备 **MATLAB R2025b** 和 **Signal Processing Toolbox**。参考结果已在 Windows 的 MATLAB R2025b / Signal Processing Toolbox 25.2 上实际生成；其他版本尚未逐一验证。示例使用 CSV，不依赖 Excel、串口、Python 或其他工具箱。

1. 点击 **Code → Download ZIP**，下载并解压整个仓库，或用 Git 克隆。
2. 在 MATLAB 中把 **Current Folder（当前文件夹）**切换到包含 `run_demo.m` 的仓库根目录。
3. 在命令窗口输入：

```matlab
run_demo
```

程序自动读取两份示例数据，打印指标，并把六个结果文件写到仓库的 **`output/`**。全程无需选文件、点选区间或保存背景设置；再次运行会更新同名结果。

| 输出文件 | 查看内容 |
| --- | --- |
| `waveform.png` | 原始记录、选定窗口、滤波后的实验与背景波形 |
| `spectrum.png` | 两条单边幅值谱、背景对照谱和低频局部放大 |
| `metrics.csv` | 采样点数、FFT 参数、RMS、谱峰和频段指标 |
| `spectrum.csv` | 每个频点的实验、背景和对照幅值，便于重新作图 |
| `analysis.mat` | `result` 结构体，含参数、选区波形、频谱和指标 |
| `run_metadata.json` | 本次 MATLAB / 工具箱版本及完整处理参数 |

如果出现 `run_demo` 无法识别，检查当前文件夹是否正确；如果提示 `Sloshing:MissingToolbox`，安装并激活 Signal Processing Toolbox。

## 默认分析的是什么数据

`data/example_signal.csv` 来自原文件 `Signal_0512_2320.xlsx`，`data/example_background.csv` 来自 `Background_0512_2319.xlsx`，不是为演示生成的模拟波形。转换仅改变文件格式，完整保留原始时间戳和 ADC 值；来源、样本数和 SHA-256 见 [data/README.md](data/README.md)。

| 参数 | 固定值 |
| --- | --- |
| 采样率 | 5000 Hz |
| 实验区间 | `[0.60, 1.60)` s，即从 0.6000 到 1.5998 s |
| 背景区间 | `[0.00, 1.00)` s，即从 0.0000 到 0.9998 s |
| 每个区间 | 5000 点，窗口长度 1 s |
| 中值滤波 | 5 点，先对整条记录处理再截取区间 |
| 带通滤波 | `butter(4, ...)`，20–2000 Hz；SOS 系数配合 `filtfilt` |
| 窗函数 | Tukey 窗，α = 0.1 |
| FFT 长度 | 8192 点，频率网格间距约 0.61035 Hz |

两个区间长度一致，使用相同的处理和幅值归一化。参数集中写在 `run_demo.m` 中，程序不读取旧版的 `WINDOW_SETTING.mat` 或 `BG_STORAGE.mat`。

## 应当看到的结果

以下图片由提交的代码和示例数据直接生成，参考文件保存在 `expected/`。图中使用英文坐标，避免不同计算机的中文字体影响显示。

### 1. 原始记录与滤波波形

![原始记录、固定窗口与滤波后的实验和背景波形](expected/waveform.png)

上图蓝色部分是固定选中的一秒实验记录，灰色是其余记录。下图把实验与背景各自的窗口起点设为 0，便于比较；它们是两次独立记录，这种对齐不表示同时采样。滤波后实验 RMS 约为 **196.77 ADC counts**，背景约为 **7.98 ADC counts**。

### 2. 频谱与背景对照

![单边幅值谱与低频局部放大](expected/spectrum.png)

上图使用对数纵轴，让幅值较小的背景也能看清；下图放大 20–350 Hz。这个窗口的响应主要集中在低频，20–2000 Hz 搜索范围内的最大对照谱峰落在 **24.41 Hz** 的 FFT 频点。

| 指标 | 参考值 |
| --- | ---: |
| 实验滤波 RMS | 196.7661 ADC counts |
| 背景滤波 RMS | 7.9761 ADC counts |
| 最大对照谱峰所在频点 | 24.4141 Hz |
| 对照谱峰幅值 | 76.9698 ADC counts |
| 对照谱的平方幅值加权质心（20–2000 Hz） | 51.6616 Hz |
| 50–300 Hz 的平方幅值和 | 46995.0174 |
| 300–1000 Hz 的平方幅值和 | 391.2688 |
| 高频／低频平方幅值和之比 | 0.00832575 |

完整精度见 [expected/metrics.csv](expected/metrics.csv)。字体和渲染差异可能让 PNG 的像素略有变化，数值核对使用容差，而非图片文件哈希。

## 处理方法与结果含义

```text
原始 CSV → 5 点中值滤波 → 固定窗口 → 减去窗口均值
        → 零相位带通 → Tukey 加窗 → 单边 FFT 幅值谱
        → 实验／背景谱对照 → 指标与图表
```

FFT 除以窗系数之和，再将除直流和奈奎斯特频点之外的单边幅值乘 2。这是经过窗增益修正的**幅值谱**，不是功率谱密度（PSD）。`butter(4, ..., 'bandpass')` 产生 8 阶带通，`filtfilt` 再做前后向滤波，不能将其简称为最终“4 阶滤波”。零填充到 8192 点使频率网格更密，但不会把一秒记录的实际分辨能力提高到 0.61 Hz。

背景对照沿用原实验的逐频点平方谱减思路：

```matlab
contrast = sqrt(max(signal_amplitude.^2 - background_amplitude.^2, 0));
```

负差值置零，用于展示实验幅值相对背景的增加。它不保留相位，也不是把两个独立时域记录直接相减。频段的“平方幅值和”是在相同窗口、相同 FFT 网格下的对比指标，不能解释成焦耳，也不是 PSD 积分。

这段波形含多次激励，因此默认案例不输出单次自由衰减的 Tau。24.41 Hz 只表示本处理流程下的最大谱峰位置；原记录未附完整样品标签和标定信息，不能据此认定瓶体固有频率或推断液体种类。

与历史脚本相比，本入口固定了数据和区间，使用更稳定的 SOS 滤波表示，并统一了窗增益归一化，所以参考幅值不必与旧版界面的显示完全相同。

## 核对复现结果

在 MATLAB 的仓库根目录运行：

```matlab
results = runtests('tests');
assertSuccess(results);
```

检查包括参考指标、CSV 与原始 Excel 的一致性、更换当前文件夹后重复运行、已知频率正弦信号、幅值缩放，以及缺失窗口、错误采样率和 NaN 等输入。参数或数据不满足条件时，程序明确报错，不丢弃数据后继续生成结果。

仓库还配置了 [GitHub Actions 自动复现](https://github.com/Supercraft-1/Liquor_Sloshing_Signal_Analysis/actions/workflows/reproduce.yml)：在独立的 Ubuntu 环境安装固定的 MATLAB R2025b 和工具箱，运行相同检查及 `run_demo`，并将结果作为 `matlab-case-results` 附件保存 7 天。每次更新主分支都会触发检查。

## 文件位置

```text
run_demo.m           唯一公开运行入口：固定参数、读取数据、导出图表
src/analyze_pair.m   数值处理与输入校验
data/                已提交的两份 CSV 与来源说明
expected/            实际运行生成的参考图、指标和环境记录
tests/               可复现性与输入异常检查
tools/               原始 Excel 转 CSV 的开发工具，初次运行无需使用
legacy/              原始采集代码、历史分析版本与 Excel 记录
output/              本次运行的结果，自动创建，不提交 Git
```

原实验文件按原样移入 `legacy/`，不加入默认运行路径。公开案例的入口、数据和说明均独立于这些历史版本。

## 相关函数

- [readtable：读取表格](https://www.mathworks.com/help/matlab/ref/readtable.html)
- [filtfilt：零相位前后向滤波](https://www.mathworks.com/help/signal/ref/filtfilt.html)
- [fft：离散傅里叶变换与单边谱示例](https://www.mathworks.com/help/matlab/ref/fft.html)
- [exportgraphics：导出结果图](https://www.mathworks.com/help/matlab/ref/exportgraphics.html)

代码与随仓库公开的数据采用 [MIT License](LICENSE)。
