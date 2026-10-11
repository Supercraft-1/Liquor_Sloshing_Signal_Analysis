# 液体样品振动分析：文献阅读记录

这里整理 12 篇与频谱估计、瞬态分析、模态识别及声振检测有关的论文，说明各方法对当前记录的适用范围。当前输入为一份实验记录和一份独立背景记录，采样率 5000 Hz，幅值单位为未标定的 ADC 计数。

默认流程采用 FFT、Welch、短时 PSD、局部 RMS 和邻近谱峰匹配。多窗谱、谱峭度及模态方法供后续数据分析参考，尚未纳入运行入口。

更新日期：2026 年 10 月 11 日。计算细节见 [短时分析方法](time_diagnostics.md)。

## 数据概况

两份公开 CSV 分别包含 11264 和 9216 个样本。默认各取一个 1 s 窗口，实验 AC RMS 为 196.9121 ADC counts，背景为 8.2696 ADC counts。实验最大 FFT 频点是 50.0488 Hz，背景在约 50 Hz 附近也有峰。数值来源为 [参考指标](../expected/metrics.csv)，波形见 [实际结果图](../expected/waveform.png)。

这些结果说明实验与背景响应幅度不同，但不能据此断定 50 Hz 是液体特征、瓶体固有频率或电源干扰。频率接近工频只是一条排查线索，需要改变实验条件验证来源。

[原采集界面](../legacy/01_Code/Vibration_Dual_Acquirer_v11_5.m) 的录制按钮分别为“背景（空瓶）”和“实验（带液）”。背景可能包含空瓶及支撑结构的响应。所选文件没有实验条件表，故保留实验／背景命名，不进行谱减。

若确实是在不同装液状态下采集，两次记录对应的被测系统本身就可能不同。此时相减得到的残差不能自动解释为纯液体响应。酒杯装液研究也显示，液体会改变容器液体耦合系统的共振特性。[Jundt 等，2006](https://phys.unsw.edu.au/music/people/publications/Jundtetal2006.pdf)

## 频谱估计与时间变化

### 1 Welch 分段平均功率谱

**Welch, P. D. (1967).** The use of fast Fourier transform for the estimation of power spectra: A method based on time averaging over short, modified periodograms. *IEEE Transactions on Audio and Electroacoustics*, 15(2), 70–73. [DOI](https://doi.org/10.1109/TAU.1967.1161901) · [IBM 原作者出版记录与摘要](https://research.ibm.com/publications/the-use-of-fast-fourier-transform-for-the-estimation-of-power-spectra-a-method-based-on-time-averaging-over-short-modified-periodograms)

方法把记录分段、加窗，计算修正周期图后再平均，用较稳定的估计代替单段周期图。段长影响频率细节，平均又会弱化各段的时间差别。

本例使用 Welch 描述总体功率，另保留平均前的 9 帧 PSD，检查主要响应集中在哪些时刻。重叠段不视为独立重复实验。

### 2 Harris 窗函数分析

**Harris, F. J. (1978).** On the Use of Windows for Harmonic Analysis with the Discrete Fourier Transform. *Proceedings of the IEEE*, 66(1), 51–83. [DOI](https://doi.org/10.1109/PROC.1978.10837) · [论文全文](https://www.fceia.unr.edu.ar/prodivoz/Harris_1978.pdf)

这篇论文系统讨论窗函数的泄漏、主瓣、旁瓣、相干增益和等效噪声带宽。窗函数不只是让图更平滑，还改变可分辨的频率结构和幅值尺度。

代码采用周期 Hann 窗：幅值谱除以窗系数之和，PSD 除以采样率与窗平方和。两种归一化分别对应幅值和功率。补零后的频点间隔与实际分辨能力分开报告。

### 3 Thomson 多窗谱估计

**Thomson, D. J. (1982).** Spectrum Estimation and Harmonic Analysis. *Proceedings of the IEEE*, 70(9), 1055–1096. [DOI](https://doi.org/10.1109/PROC.1982.12433) · [论文全文](https://www.math.ucdavis.edu/~saito/data/ONR15/thomson_spect-est-harm-anal.pdf)

多窗法使用离散扁长球序列窗，即 DPSS，在指定带宽内综合多个谱估计。论文也讨论了连续谱中的窄带线谱分析。

多窗法可用于核对窄峰的稳定性。应用时需报告时间带宽积及窗数，并比较带宽变化对峰位置的影响。识别到线谱后，仍需结合激励和结构信息判断来源。

### 4 Allen 与 Rabiner 短时傅里叶分析

**Allen, J. B., & Rabiner, L. R. (1977).** A Unified Approach to Short-Time Fourier Analysis and Synthesis. *Proceedings of the IEEE*, 65(11), 1558–1564. [DOI](https://doi.org/10.1109/PROC.1977.10770) · [原作者提供的论文全文](https://web.ece.ucsb.edu/Faculty/Rabiner/ece259/Reprints/122_unified_approach_to_STFT.pdf)

短时傅里叶变换在滑动窗口内计算频谱，把整段频谱扩展为时间频率表示。时间定位和频率分辨能力受同一个窗口限制。

短时 PSD 采用 0.20 s Hann 窗和 0.10 s 步长，与 Welch 共用分帧参数，便于核对逐帧平均。幅值突变则用 20 ms 局部 RMS 观察，兼顾频率描述与时间定位。

## 瞬态检测与分析频带

### 5 Antoni 谱峭度理论

**Antoni, J. (2006).** The spectral kurtosis: a useful tool for characterising non-stationary signals. *Mechanical Systems and Signal Processing*, 20(2), 282–307. [DOI](https://doi.org/10.1016/j.ymssp.2004.09.001) · [出版商摘要与方法预览](https://www.sciencedirect.com/science/article/pii/S0888327004001517)

谱峭度用频率相关的高阶统计量补充 PSD，帮助定位瞬态出现的频带；论文给出了与短时傅里叶表示相联系的估计方法。

当前记录仅包含少量瞬态，先用逐帧谱观察变化。进一步估计谱峭度需要更长记录或独立重复测量，以检查高阶统计量的稳定性。

### 6 Antoni 与 Randall 谱峭度应用

**Antoni, J., & Randall, R. B. (2006).** The spectral kurtosis: application to the vibratory surveillance and diagnostics of rotating machines. *Mechanical Systems and Signal Processing*, 20(2), 308–331. [DOI](https://doi.org/10.1016/j.ymssp.2004.09.002) · [出版商摘要与方法预览](https://www.sciencedirect.com/science/article/pii/S0888327004001529)

论文用谱峭度和峭度图选择更适于瞬态检测的频带，再进行包络分析。其应用对象是产生反复冲击的旋转机械故障。

可借鉴频带选择与包络分析的处理顺序，但旋转机械的重复故障冲击与本例的瞬态响应并非同类实验。选带应结合响应机理，并在独立记录上验证；拟合某个频带的包络时，需保留频带及背景条件。

### 7 Antoni 快速峭度图

**Antoni, J. (2007).** Fast computation of the kurtogram for the detection of transient faults. *Mechanical Systems and Signal Processing*, 21(1), 108–124. [DOI](https://doi.org/10.1016/j.ymssp.2005.12.002) · [出版商摘要与方法预览](https://www.sciencedirect.com/science/article/pii/S0888327005002414)

快速峭度图在频带中心与带宽的组合上搜索突发性较强的成分，减少全面搜索的计算量。

大量频带中的最大峭度可能来自偶然尖峰。对当前短记录，固定频带比较更便于复查；自动选带需要独立重复实验验证其稳定性。

## 从响应谱到模态参数

### 8 Juang 与 Pappa 特征系统实现算法

**Juang, J. N., & Pappa, R. S. (1985).** An Eigensystem Realization Algorithm (ERA) for modal parameter identification and model reduction. *JPL Proceedings of the Workshop on Identification and Control of Flexible Space Structures*, Vol. 3. [NASA 原作者会议论文记录](https://ntrs.nasa.gov/citations/19850022899) · [会议版全文](https://ntrs.nasa.gov/api/citations/19850022899/downloads/19850022899.pdf)

ERA 用脉冲响应或自由初始状态响应构造 Hankel 矩阵，借助奇异值分解建立状态空间模型，再提取模态参数。原论文还使用精度指标区分系统模态和噪声模态。

ERA 适用于激励结束后的自由响应，应用前需确认有效区间，再检查模型阶次、区间变化和重构误差。本文引用 NASA 收录的会议版。

### 9 Peeters 与 De Roeck 随机系统识别综述

**Peeters, B., & De Roeck, G. (2001).** Stochastic System Identification for Operational Modal Analysis: A Review. *Journal of Dynamic Systems, Measurement, and Control*, 123(4), 659–667. [DOI](https://doi.org/10.1115/1.1410370) · [论文全文](https://people.duke.edu/~hpgavin/SystemID/References/Peeters-JDSC-2001.pdf)

综述介绍输出型模态识别，包括协方差驱动和数据驱动的随机子空间方法，并讨论模型阶次稳定性。文中明确指出：输入中的主导周期成分可能被误识别为系统固有频率。

约 50 Hz 的主导峰也可能来自输入周期成分。采用 SSI 前需要检查激励假设、延长记录，并通过稳定图和独立重复测量核对识别结果。

### 10 Brincker 等频域分解

**Brincker, R., Zhang, L., & Andersen, P. (2001).** Modal identification of output-only systems using frequency domain decomposition. *Smart Materials and Structures*, 10(3), 441–445. [DOI](https://doi.org/10.1088/0964-1726/10/3/303) · [作者所在大学的论文记录与摘要](https://vbn.aau.dk/da/publications/modal-identification-of-output-only-systems-using-frequency-domai-2/) · [作者存档全文](https://vbn.aau.dk/files/203990023/Modal_Identification_of_Output_Only_Systems_using_Frequency_Domain_Decomposition.pdf)

FDD 对响应的谱密度矩阵进行分解，以提取不同模态对应的成分，而不是只在一条 PSD 上找峰。

FDD 的谱矩阵依赖同步多通道响应。当前实验与背景为两次独立的单通道记录，不能拼成此类矩阵；同步加速度和声压采集可为后续互谱分析提供条件。

## 容器液体与声振检测

### 11 Jundt 等装液酒杯振动

**Jundt, G., Radu, A., Fort, E., Duda, J., Vach, H., & Fletcher, N. (2006).** Vibrational modes of partly filled wine glasses. *The Journal of the Acoustical Society of America*, 119(6), 3793–3798. [DOI](https://doi.org/10.1121/1.2198183) · [原作者团队提供的论文全文](https://phys.unsw.edu.au/music/people/publications/Jundtetal2006.pdf)

研究使用振动测量与全息干涉观察酒杯装液后的共振和振型变化。液体的附加作用会降低该实验系统的共振频率，并影响相近正交模态的同时激发。

解释装液后的谱峰变化，需要同时记录装液高度、容器几何、壁厚和支撑方式。该研究对象为酒杯的耦合振动，其结果不能直接外推到任意瓶体或低频液体晃荡。

### 12 Zhang 等农产品声振检测综述

**Zhang, W., Lv, Z., & Xiong, S. (2018).** Nondestructive quality evaluation of agro-products using acoustic vibration methods—A review. *Critical Reviews in Food Science and Nutrition*, 58(14), 2386–2397. [DOI](https://doi.org/10.1080/10408398.2017.1324830) · [出版商摘要](https://www.tandfonline.com/doi/abs/10.1080/10408398.2017.1324830)

综述将声振无损检测分为激励、采集和处理三个部分，讨论冲击与强迫激励、接触与非接触测量等方案。文章在线发表于 2017 年，期刊卷期年份为 2018 年。

这篇综述提示，应将激励一致性、测量条件和特征重复性一并纳入实验设计。研究对象虽不同，但对声振检测的采集流程仍有参考价值。

第 5、6、7、12 项的讨论依据出版商公开摘要与预览，不涉及付费全文中未核对的参数或实验结论。

## 当前实现

### 短时功率谱

逐帧 PSD 沿用基准流程的滤波顺序和固定窗口，显示各时段对总体谱的贡献。

对第 $`m`$ 帧，使用与当前 Welch 相同的周期 Hann 窗，计算

```math
P_m[k]=\frac{c_k\left|\mathrm{FFT}\{x_m[n]w[n]\}\right|^2}{f_s\sum_n w[n]^2},
```

其中 $`c_k`$ 在直流和奈奎斯特频点取 1，其余单边频点取 2，单位为 ADC counts²/Hz。对这 9 帧取平均应与现有 `pwelch` 结果一致。逐帧频段积分可以显示哪一段时间贡献了较多均方响应。[Welch，1967](https://research.ibm.com/publications/the-use-of-fast-fourier-transform-for-the-estimation-of-power-spectra-a-method-based-on-time-averaging-over-short-modified-periodograms)

0.20 s 窗会扩展瞬态在谱图中的时间范围，因此条带起点只能近似反映响应变化。输出保留帧起止、中心及频率坐标，窗口和重叠参数见运行元数据。[Allen 与 Rabiner，1977](https://web.ece.ucsb.edu/Faculty/Rabiner/ece259/Reprints/122_unified_approach_to_STFT.pdf)

### 活动区间

当前采用 20 ms 局部 RMS，以中位数、MAD 和相对幅度上升设置阈值；间隔不超过 40 ms 的超阈值区间合并，实际活动样本少于 6 ms 时舍弃。系数是集中配置的工程筛选规则，不是上述文献提供的通用最优阈值。已知突变、稳定正弦和零信号用于测试候选定位与零值处理；真实记录的候选位置可与波形核对。

较大幅值可能来自激励、持续振动、饱和或碰撞。滤波也会扩展瞬态的影响。因此活动区间仅用于复查波形，靠近记录边缘的候选另作标记。

### 邻近谱峰

分别寻找峰高和显著度达到各自带内最大幅值 5% 的局部峰，在 2 Hz 容差内按最近距离一对一匹配。容差为 1 s Hann 主瓣零点间宽度的一半，不代表频率置信区间。

不默认加入 50 Hz 陷波，也不将背景 PSD 从实验 PSD 扣除。若共同成分确实来自电源或装置，应通过关闭激励、更换供电、改变装液高度或改变支撑等实验来验证；若峰随被测系统改变，就需要保留它。[Peeters 与 De Roeck，2001](https://people.duke.edu/~hpgavin/SystemID/References/Peeters-JDSC-2001.pdf)

## 自由衰减拟合的条件

下一阶段只有在激励已经结束、下一次激励之前存在足够长的响应、分析频带合理且信号仍高于可用噪声参考时，才考虑衰减拟合。孤立的近似单模态响应可用

```math
x(t)=A e^{-\alpha t}\cos(2\pi f_d t+\phi)
```

描述。这里 $`f_d`$ 是阻尼振动频率，单位为 Hz，$`\alpha>0`$ 是指数衰减率，单位为 s⁻¹。此时 $`\tau=1/\alpha`$，并有

```math
f_n=\frac{\sqrt{(2\pi f_d)^2+\alpha^2}}{2\pi},\qquad
\zeta=\frac{\alpha}{\sqrt{(2\pi f_d)^2+\alpha^2}}.
```

这是单模态线性自由响应模型，不适用于持续驱动、反复激励或明显多模态拍频的整段信号。拟合后必须检查残差、区间变化及重复实验稳定性；条件不满足时不输出阻尼比或衰减时间。多模态自由响应才进一步考虑 ERA 等方法。[Juang 与 Pappa，1985](https://ntrs.nasa.gov/api/citations/19850022899/downloads/19850022899.pdf)

## 需要补充的采集信息

后续采集建议附带以下信息。

| 信息 | 对处理的影响 |
| --- | --- |
| 样品编号、成分或浓度、温度、装液高度或质量 | 判断峰和衰减变化是否来自样品，而非其他条件 |
| 容器尺寸与材料、夹持或支撑位置、传感器安装位置 | 控制结构与边界条件变化 |
| 激励方式、幅度、作用时刻、停止时刻 | 区分受迫响应和自由响应；有条件时同步记录力 |
| 传感器标定、模拟增益、ADC 范围、抗混叠滤波 | 确定物理单位、削顶判断和可用频带 |
| 硬件采样时钟、帧编号、丢包信息 | 检查真实采样连续性 |
| 独立重复实验编号和采集顺序 | 评价重复性，避免把同一记录的多个窗口当作独立样品 |

原采集代码用样本序号除以采样率构造时间列。因而 CSV 等间隔检查只能核对导出后的时间列，不能证明串口没有丢帧；这一点需要采集端的帧计数或硬件时间信息解决。也不能仅凭绘图纵轴范围推断 ADC 位数或削顶阈值。

如以后建立分类模型，应按样品或独立实验分组划分训练与测试数据，同一条原始记录切出的窗口不能同时进入两边。当前只有一对无完整条件标签的公开案例，适合验证处理方法，不适合报告液体分类准确率。

## 验证

代码测试和参考输出核对以下项目。

- 原有 14 项参考指标保持在既定数值容差内，原始 CSV 哈希不变。
- 逐帧 PSD 平均与当前 Welch 一致；完整单边频率箱求和乘以频点间隔，应等于 $`\sum_n (x[n]w[n])^2/\sum_n w[n]^2`$，而非未经加权的整窗 RMS 平方。
- 稳定正弦、已知突变与零信号分别验证持续谱峰、候选定位和零值处理；改变幅值时保持正确的平方功率尺度。
- 实验与背景含同频已知正弦时，给出邻近峰提示，但不自动删除它；相距超过匹配容差的峰不应匹配，容差内的不同频率仍仅为候选。
- 分段不足、匹配竞争和边缘支持等情况处理一致。
- 所有结果由 `run_demo` 导出，图与数值采用相同参数。

合成信号用于检验算法，不替换公开实验数据。真实样品的区分能力最终需要独立、条件明确的重复测量验证。
