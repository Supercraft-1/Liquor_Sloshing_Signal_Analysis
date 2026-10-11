# 信号处理方法

实验与背景分别处理，参数集中在 `src/case_config.m`。下文说明窗口、归一化和指标定义。

## 1. 数据检查与窗口

输入为两列：时间（秒）和未标定 ADC 计数。程序检查数据是否为有限实数、时间是否严格递增、采样间隔是否符合 5000 Hz，以及配置窗口是否完整存在。缺行或异常值不会被静默删除。

实验窗口为 `[0.60, 1.60)` s，背景为 `[0.20, 1.20)` s，各含 5000 点。实验窗口包含多次瞬态响应，背景窗口避开记录起点；两者均预先固定。

CSV 保留整段记录：后续滤波需要窗口前后的样本作为上下文。

## 2. 预处理

对每条完整记录执行：

1. 减去整条记录的均值，移除 ADC 直流偏置。
2. 用 `butter(4, [20, 2000]/2500, 'bandpass')` 设计 Butterworth 带通，转换成 SOS。
3. 用 `filtfilt(sos, gain, x)` 前后向滤波。
4. 截取固定窗口，再减去窗口的残余均值。

单次带通为 8 阶；前后向滤波得到零相位、平方幅频响应。配置中的 20 和 2000 Hz 是单次滤波设计截止点，不表示前后向组合后仍在这些点保持单次的 -3 dB。完整记录先滤波减少人为截窗引入的端点问题，但 `filtfilt` 仍有有限记录的边界效应，并不是实时因果处理。

记录中的尖峰可能来自有效响应，因此保留原样，不使用中值滤波。

时域指标为窗口 AC RMS：

$$
x_{\mathrm{RMS}}=\sqrt{\frac{1}{N}\sum_{n=0}^{N-1}x[n]^2}.
$$

单位为 ADC counts。两个时域子图采用独立纵轴，图中明确标注这一点。

## 3. FFT 幅值谱

每个 5000 点窗口乘以周期 Hann 窗，补零到 8192 点：

$$
X[k]=\operatorname{FFT}_{8192}\{x[n]w[n]\},\qquad
A[k]=\frac{c_k|X[k]|}{\sum_n w[n]}.
$$

其中单边谱的直流与奈奎斯特频点取 $c_k=1$，其他频点取 $c_k=2$。此处用窗系数之和修正相干增益，$A[k]$ 的单位仍为 ADC counts；对于稳定、贴合频点的正弦，幅值接近正弦的峰值幅度。多次瞬态的谱峰不能直接解释为某次冲击的峰值幅度。

频率网格为 $5000/8192=0.6103515625$ Hz。补零细化网格，实际分辨能力由记录长度和 Hann 窗主瓣宽度共同决定。

最大频点在 20–2000 Hz 的实验幅值谱中查找。幅值全为零时，频率返回 `NaN`。

两份记录独立采集，时域相减或幅值平方谱减缺少相位及系统一致性的依据，故分别报告。

## 4. Welch 功率谱

对预处理窗口使用 `pwelch`：

```matlab
window = hann(1000, 'periodic');
[pxx, f] = pwelch(x, window, 500, 2048, 5000, 'onesided');
```

每段 0.20 s、重叠 0.10 s，5000 点恰好覆盖 9 段，不丢弃末尾样本。每段 FFT 的平方幅值按 $f_s\sum w^2$ 归一化，单边谱再进行适当倍增；随后对 9 段平均。因此 $S_{xx}(f)$ 的单位为 **ADC counts²/Hz**，不是 FFT 幅值的单位。

2048 点 FFT 的网格为 2.44140625 Hz；每段时长对应的尺度为 5 Hz，周期 Hann 窗的等效噪声带宽为 7.5 Hz。不能仅根据网格间隔宣称频率分辨率。

Welch 结果描述这一秒内的分段平均功率。记录含有多次瞬态，9 个重叠段并非独立重复实验，因而不用于估计重复实验误差。

Welch 的加窗与重叠会改变不同时间样本的权重。对本例这样的瞬态记录，PSD 全带积分与整窗 AC RMS 的平方不要求精确相等；已知稳定正弦测试用于检查功率归一化是否正确。

## 5. 频段积分、等效 RMS 与占比

对频段 $[f_a,f_b]$：

$$
P_{[f_a,f_b]}=\int_{f_a}^{f_b}S_{xx}(f)\,df,\qquad
x_{\mathrm{RMS,band}}=\sqrt{P_{[f_a,f_b]}}.
$$

积分单位为 ADC counts²，平方根为 ADC counts。它们是均方响应及其等效 RMS；没有传感器标定和力学模型，不能称为焦耳能量、瓦特功率或加速度。

`integrate_psd` 先在精确频段边界上做线性插值，再用梯形积分。这样 20–50、50–300、300–1000、1000–2000 Hz 四段恰好划分 20–2000 Hz；共享边界不会被当作完整频率箱重复计入。边界插值只是数值积分，不是对展示曲线额外平滑。

实验功率占比定义为：

$$
q_i=\frac{P_{\mathrm{experiment},i}}{\sum_j P_{\mathrm{experiment},j}}.
$$

其他指标定义如下。

- PSD 质心：20–2000 Hz 内的 $\int fS_{xx}(f)df/\int S_{xx}(f)df$。
- 高／低频功率比：实验 300–1000 Hz 功率除以 50–300 Hz 功率。
- 质心、占比或比值的分母为零时，返回 `NaN`。

约 50 Hz 的峰同时出现在实验与背景中，其物理来源仍需实验验证。

## 6. 短时分析

`analyze_diagnostics` 读取同一份预处理结果，不改变 FFT、Welch 或汇总指标。它保存 Welch 平均前的逐帧 PSD、20 ms 局部 RMS 及活动区间，并在两条独立 FFT 中匹配邻近强峰。

9 帧 PSD 的平均与 Welch 一致；20 ms 局部 RMS 用于定位幅值变化较大的区间。活动区间和邻近峰供波形复查使用，不能直接视为施力时刻或模态参数。计算细节和输出列见 [短时分析方法](time_diagnostics.md)。

## 7. 复现检查

`run_demo` 读取固定 CSV，调用 `analyze_pair` 得到数值，再由 `export_results` 保存、由 `plot_case` 绘图。绘图不修改分析数据，不对 FFT 做额外平滑。

测试覆盖四部分：

- `test_spectral_method.m`：已知正弦的幅值、功率及频段积分。
- `test_reproducible_case.m`：真实数据、参考指标、重复运行与输出格式。
- `test_time_diagnostics.m`：逐帧功率、活动区间和峰匹配。
- `test_chinese_figures.m`：图形数据、中文标签、色标和零响应坐标。

`run_metadata.json` 保存参数、环境版本和单位定义，`expected/` 保存参考输出。`legacy/` 为原始实验文件归档。

## 参考资料

1. [MathWorks — pwelch：Welch 分段平均、PSD 单位与单边谱缩放](https://www.mathworks.com/help/signal/ref/pwelch.html)。
2. [MathWorks — hann：周期 Hann 窗](https://www.mathworks.com/help/signal/ref/hann.html)。
3. [MathWorks — filtfilt：前后向滤波、平方幅频响应与端点处理](https://www.mathworks.com/help/signal/ref/filtfilt.html)。
4. [MathWorks — fft：单边幅值谱](https://www.mathworks.com/help/matlab/ref/fft.html)。
5. [MathWorks — exportgraphics：高清和矢量导出](https://www.mathworks.com/help/matlab/ref/exportgraphics.html)。
