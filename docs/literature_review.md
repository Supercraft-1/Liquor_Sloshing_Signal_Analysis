# 液体样品振动记录的文献与算法取舍

本案例是一段实验记录与一段独立背景记录的离线分析。采样率为 5000 Hz，数据仍是未标定的 ADC 计数。记录中有多次瞬态，并非已经确认的单次自由衰减；因此用时间变化辅助解释总体频谱，不把最大谱峰直接改称固有频率。

下面选取 10 篇频谱分析、瞬态检测和模态识别的经典方法论文，以及 2 篇与容器液体振动、农产品声振检测有关的研究和综述。选择依据是方法与本案例的联系，不是按引用量排名。文献中的旋转机械、结构或酒杯实验，不等同于本项目已经具备液体成分识别能力。

调研日期：2026 年 10 月 11 日。当前默认入口保留 FFT／Welch 基准，并加入短时 PSD、响应活动候选和邻近谱峰提示；实现细节见 [诊断方法](time_diagnostics.md)。谱峭度、模态识别及衰减拟合仍是后续有条件的选择，不属于当前输出。

## 现有数据能回答什么

两份公开 CSV 分别包含 11264 和 9216 个样本。默认各取一个 1 s 窗口，实验 AC RMS 为 196.9121 ADC counts，背景为 8.2696 ADC counts。实验最大 FFT 频点是 50.0488 Hz，背景在约 50 Hz 附近也有峰。数值来源为 [参考指标](../expected/metrics.csv)，波形见 [实际结果图](../expected/waveform.png)。

这些结果说明实验与背景响应幅度不同，但不能据此断定 50 Hz 是液体特征、瓶体固有频率或电源干扰。频率接近工频只是一条排查线索，需要改变实验条件验证来源。

[原采集界面](../legacy/01_Code/Vibration_Dual_Acquirer_v11_5.m) 将录制按钮写为“背景（空瓶）”和“实验（带液）”。这提醒我们：背景可能包含空瓶和支撑结构的响应，不只是电子噪声。所选文件没有附带实验条件表，因此仍按实验记录与背景记录命名，不补造样品标签，也不进行谱减。

若确实是在不同装液状态下采集，两次记录对应的被测系统本身就可能不同。此时相减得到的残差不能自动解释为纯液体响应。酒杯装液研究也显示，液体会改变容器液体耦合系统的共振特性。[Jundt 等，2006](https://phys.unsw.edu.au/music/people/publications/Jundtetal2006.pdf)

## 频谱估计与时间变化

### 1 Welch 分段平均功率谱

**Welch, P. D. (1967).** The use of fast Fourier transform for the estimation of power spectra: A method based on time averaging over short, modified periodograms. *IEEE Transactions on Audio and Electroacoustics*, 15(2), 70–73. [DOI](https://doi.org/10.1109/TAU.1967.1161901) · [IBM 原作者出版记录与摘要](https://research.ibm.com/publications/the-use-of-fast-fourier-transform-for-the-estimation-of-power-spectra-a-method-based-on-time-averaging-over-short-modified-periodograms)

方法把记录分段、加窗，计算修正周期图后再平均，用较稳定的估计代替单段周期图。段长影响频率细节，平均又会弱化各段的时间差别。

**本项目取舍：** 保留现有 Welch PSD 作为总体描述，同时保存平均前的逐帧 PSD，观察反复响应是否集中在少数时刻。9 个相互重叠的段不是 9 次独立实验，不能据此画重复实验的误差条。

### 2 Harris 窗函数分析

**Harris, F. J. (1978).** On the Use of Windows for Harmonic Analysis with the Discrete Fourier Transform. *Proceedings of the IEEE*, 66(1), 51–83. [DOI](https://doi.org/10.1109/PROC.1978.10837) · [论文全文](https://www.fceia.unr.edu.ar/prodivoz/Harris_1978.pdf)

这篇论文系统讨论窗函数的泄漏、主瓣、旁瓣、相干增益和等效噪声带宽。窗函数不只是让图更平滑，还改变可分辨的频率结构和幅值尺度。

**本项目取舍：** 延续周期 Hann 窗。幅值谱按窗系数之和归一化，PSD 按采样率与窗平方和归一化。补零只细化频率网格；新增短时分析也不能把 FFT 点距写成实际频率分辨率。

### 3 Thomson 多窗谱估计

**Thomson, D. J. (1982).** Spectrum Estimation and Harmonic Analysis. *Proceedings of the IEEE*, 70(9), 1055–1096. [DOI](https://doi.org/10.1109/PROC.1982.12433) · [论文全文](https://www.math.ucdavis.edu/~saito/data/ONR15/thomson_spect-est-harm-anal.pdf)

多窗法使用离散扁长球序列窗，即 DPSS，在指定带宽内综合多个谱估计。论文也讨论了连续谱中的窄带线谱分析。

**本项目取舍：** 可作为窄峰的后续交叉检查，但不替换唯一默认流程。时间带宽积决定平滑程度，必须公开设置；短记录不会因换成多窗法就获得额外观测信息。识别出线谱，也不等于识别出机械模态。

### 4 Allen 与 Rabiner 短时傅里叶分析

**Allen, J. B., & Rabiner, L. R. (1977).** A Unified Approach to Short-Time Fourier Analysis and Synthesis. *Proceedings of the IEEE*, 65(11), 1558–1564. [DOI](https://doi.org/10.1109/PROC.1977.10770) · [原作者提供的论文全文](https://web.ece.ucsb.edu/Faculty/Rabiner/ece259/Reprints/122_unified_approach_to_STFT.pdf)

短时傅里叶变换在滑动窗口内计算频谱，把整段频谱扩展为时间频率表示。时间定位和频率分辨能力受同一个窗口限制。

**本项目取舍：** 采用短时 PSD，观察持续的窄带成分与短暂的宽带响应。复用现有 Welch 的 0.20 s Hann 窗与 0.10 s 步长，让逐帧平均能与基准 PSD 核对；另用较短的局部 RMS 窗观察响应突变，不让一套窗口承担两种不同任务。

## 瞬态检测与分析频带

### 5 Antoni 谱峭度理论

**Antoni, J. (2006).** The spectral kurtosis: a useful tool for characterising non-stationary signals. *Mechanical Systems and Signal Processing*, 20(2), 282–307. [DOI](https://doi.org/10.1016/j.ymssp.2004.09.001) · [出版商摘要与方法预览](https://www.sciencedirect.com/science/article/pii/S0888327004001517)

谱峭度用频率相关的高阶统计量补充 PSD，帮助定位瞬态出现的频带；论文给出了与短时傅里叶表示相联系的估计方法。

**本项目取舍：** 先保留逐帧谱，检查时间变化，再考虑谱峭度。只有几次冲击的短记录不足以支持稳定的高阶统计判断；较高的谱峭度也不能说明液体类型或检测精度。

### 6 Antoni 与 Randall 谱峭度应用

**Antoni, J., & Randall, R. B. (2006).** The spectral kurtosis: application to the vibratory surveillance and diagnostics of rotating machines. *Mechanical Systems and Signal Processing*, 20(2), 308–331. [DOI](https://doi.org/10.1016/j.ymssp.2004.09.002) · [出版商摘要与方法预览](https://www.sciencedirect.com/science/article/pii/S0888327004001529)

论文用谱峭度和峭度图选择更适于瞬态检测的频带，再进行包络分析。其应用对象是产生反复冲击的旋转机械故障。

**本项目取舍：** 借鉴“先确认频带，再分析包络”的顺序，不照搬轴承故障结论。带通频带、包络处理和背景假设都要明确。不能先遍历频带挑出最漂亮的衰减曲线，再把它当作整段响应的物理参数。

### 7 Antoni 快速峭度图

**Antoni, J. (2007).** Fast computation of the kurtogram for the detection of transient faults. *Mechanical Systems and Signal Processing*, 21(1), 108–124. [DOI](https://doi.org/10.1016/j.ymssp.2005.12.002) · [出版商摘要与方法预览](https://www.sciencedirect.com/science/article/pii/S0888327005002414)

快速峭度图在频带中心与带宽的组合上搜索突发性较强的成分，减少全面搜索的计算量。

**本项目取舍：** 暂不作为自动去噪入口。短记录在大量频带中取最大值，容易把偶然尖峰选出来。先比较固定频带的逐次响应，再用独立重复实验验证选带是否稳定；不能以峭度升高本身证明处理更好。

## 从响应谱到模态参数

### 8 Juang 与 Pappa 特征系统实现算法

**Juang, J. N., & Pappa, R. S. (1985).** An Eigensystem Realization Algorithm (ERA) for modal parameter identification and model reduction. *JPL Proceedings of the Workshop on Identification and Control of Flexible Space Structures*, Vol. 3. [NASA 原作者会议论文记录](https://ntrs.nasa.gov/citations/19850022899) · [会议版全文](https://ntrs.nasa.gov/api/citations/19850022899/downloads/19850022899.pdf)

ERA 用脉冲响应或自由初始状态响应构造 Hankel 矩阵，借助奇异值分解建立状态空间模型，再提取模态参数。原论文还使用精度指标区分系统模态和噪声模态。

**本项目取舍：** 适合后续已经确认激励结束的自由响应分析，不直接套在多次激励混合区间上。必须检查模型阶次、区间变化与重构误差，不能只输出一组特征值。这里链接的是 NASA 收录的会议版，不与同年的期刊版混写。

### 9 Peeters 与 De Roeck 随机系统识别综述

**Peeters, B., & De Roeck, G. (2001).** Stochastic System Identification for Operational Modal Analysis: A Review. *Journal of Dynamic Systems, Measurement, and Control*, 123(4), 659–667. [DOI](https://doi.org/10.1115/1.1410370) · [论文全文](https://people.duke.edu/~hpgavin/SystemID/References/Peeters-JDSC-2001.pdf)

综述介绍输出型模态识别，包括协方差驱动和数据驱动的随机子空间方法，并讨论模型阶次稳定性。文中明确指出：输入中的主导周期成分可能被误识别为系统固有频率。

**本项目取舍：** 这是不能把当前约 50 Hz 谱峰直接当作模态的关键依据。未测量输入，并不意味着任意激励都满足随机识别假设。若以后采用 SSI，应重新设计采集条件，保留更长记录并检查稳定图与独立重复结果。

### 10 Brincker 等频域分解

**Brincker, R., Zhang, L., & Andersen, P. (2001).** Modal identification of output-only systems using frequency domain decomposition. *Smart Materials and Structures*, 10(3), 441–445. [DOI](https://doi.org/10.1088/0964-1726/10/3/303) · [作者所在大学的论文记录与摘要](https://vbn.aau.dk/da/publications/modal-identification-of-output-only-systems-using-frequency-domai-2/) · [作者存档全文](https://vbn.aau.dk/files/203990023/Modal_Identification_of_Output_Only_Systems_using_Frequency_Domain_Decomposition.pdf)

FDD 对响应的谱密度矩阵进行分解，以提取不同模态对应的成分，而不是只在一条 PSD 上找峰。

**本项目取舍：** 当前单通道数据不提供空间振型。实验记录与背景记录是两次独立采集，不能拼成同步双通道谱矩阵。未来有同步加速度和声压数据时，才有条件利用互谱及跨通道结构进一步分析。

## 容器液体与声振检测

### 11 Jundt 等装液酒杯振动

**Jundt, G., Radu, A., Fort, E., Duda, J., Vach, H., & Fletcher, N. (2006).** Vibrational modes of partly filled wine glasses. *The Journal of the Acoustical Society of America*, 119(6), 3793–3798. [DOI](https://doi.org/10.1121/1.2198183) · [原作者团队提供的论文全文](https://phys.unsw.edu.au/music/people/publications/Jundtetal2006.pdf)

研究使用振动测量与全息干涉观察酒杯装液后的共振和振型变化。液体的附加作用会降低该实验系统的共振频率，并影响相近正交模态的同时激发。

**本项目取舍：** 测得的是容器、液体及边界条件共同作用的响应。装液高度、容器几何、壁厚和支撑方式必须记录；不同液体的峰差不能脱离这些条件解释。这篇论文也不是对所有瓶体或低频晃荡的通用标定公式。

### 12 Zhang 等农产品声振检测综述

**Zhang, W., Lv, Z., & Xiong, S. (2018).** Nondestructive quality evaluation of agro-products using acoustic vibration methods—A review. *Critical Reviews in Food Science and Nutrition*, 58(14), 2386–2397. [DOI](https://doi.org/10.1080/10408398.2017.1324830) · [出版商摘要](https://www.tandfonline.com/doi/abs/10.1080/10408398.2017.1324830)

综述将声振无损检测分为激励、采集和处理三个部分，讨论冲击与强迫激励、接触与非接触测量等方案。文章在线发表于 2017 年，期刊卷期年份为 2018 年。

**本项目取舍：** 检测效果不能只靠末端算法改善。先稳定激励和测量条件，再评价特征的重复性。这篇综述涉及农产品质量评价，不作为本样例已经实现液体浓度识别的证据。

第 5、6、7、12 项的讨论依据出版商公开摘要与预览，不涉及付费全文中未核对的参数或实验结论。

## 已加入默认入口的诊断方法

### 保留基准并输出短时功率谱

沿用当前滤波顺序与固定分析窗口，不改动现有 FFT、Welch 和频段指标。新增逐帧 PSD 的目的，是解释整体结果怎样由时间变化形成，而不是为了得到更平滑的曲线。

对第 $m$ 帧，使用与当前 Welch 相同的周期 Hann 窗，计算

$$
P_m[k]=\frac{c_k\left|\operatorname{FFT}\{x_m[n]w[n]\}\right|^2}{f_s\sum_n w[n]^2},
$$

其中 $c_k$ 在直流和奈奎斯特频点取 1，其余单边频点取 2，单位为 ADC counts²/Hz。对这 9 帧取平均应与现有 `pwelch` 结果一致。逐帧频段积分可以显示哪一段时间贡献了较多均方响应。[Welch，1967](https://research.ibm.com/publications/the-use-of-fast-fourier-transform-for-the-estimation-of-power-spectra-a-method-based-on-time-averaging-over-short-modified-periodograms)

0.20 s 窗会把瞬态的影响扩展到一段时间，不能把谱图亮带的起点当成精确的施力时刻。时间中心、窗长、重叠和频率尺度应随结果一同导出。[Allen 与 Rabiner，1977](https://web.ece.ucsb.edu/Faculty/Rabiner/ece259/Reprints/122_unified_approach_to_STFT.pdf)

### 检测响应突变而不是宣称找到激励

当前采用 20 ms 局部 RMS，以中位数、MAD 和相对幅度上升设置阈值；间隔不超过 40 ms 的超阈值区间合并，实际活动样本少于 6 ms 时舍弃。系数是集中配置的工程筛选规则，不是上述文献提供的通用最优阈值。已知突变、稳定正弦和零信号用于测试候选定位与零值处理；真实记录的候选位置可与波形核对。

候选不能自动等同于激励时刻。较大的幅值可能来自持续振动、饱和、碰撞或其他干扰；零相位滤波还可能把瞬态影响扩展到其前后。相邻候选过近、响应持续重叠和靠近记录边缘时，应明确标注，不能强行生成互相独立的自由衰减段。

### 标出实验与背景的邻近谱峰

分别寻找两条记录中达到各自最大幅值 5% 的显著局部峰，在 2 Hz 容差内按最近距离进行一对一匹配。容差取 1 s Hann 主瓣零点间宽度的一半，不是统计置信区间；报告的是邻近峰候选，不使用“已确认工频”“已消除噪声”或“样品固有频率”。

不默认加入 50 Hz 陷波，也不将背景 PSD 从实验 PSD 扣除。若共同成分确实来自电源或装置，应通过关闭激励、更换供电、改变装液高度或改变支撑等实验来验证；若峰随被测系统改变，就需要保留它。[Peeters 与 De Roeck，2001](https://people.duke.edu/~hpgavin/SystemID/References/Peeters-JDSC-2001.pdf)

## 后续有条件的自由衰减拟合

下一阶段只有在激励已经结束、下一次激励之前存在足够长的响应、分析频带合理且信号仍高于可用噪声参考时，才考虑衰减拟合。孤立的近似单模态响应可用

$$
x(t)=A e^{-\alpha t}\cos(2\pi f_d t+\phi)
$$

描述。这里 $f_d$ 是阻尼振动频率，单位为 Hz，$\alpha>0$ 是指数衰减率，单位为 s⁻¹。此时 $\tau=1/\alpha$，并有

$$
f_n=\frac{\sqrt{(2\pi f_d)^2+\alpha^2}}{2\pi},\qquad
\zeta=\frac{\alpha}{\sqrt{(2\pi f_d)^2+\alpha^2}}.
$$

这是单模态线性自由响应模型，不适用于持续驱动、反复激励或明显多模态拍频的整段信号。拟合后必须检查残差、区间变化及重复实验稳定性；条件不满足时不输出阻尼比或衰减时间。多模态自由响应才进一步考虑 ERA 等方法。[Juang 与 Pappa，1985](https://ntrs.nasa.gov/api/citations/19850022899/downloads/19850022899.pdf)

## 需要补充的采集信息

算法可以改善估计和解释，不能恢复从未记录的实验条件。后续数据至少应附带以下信息。

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

## 改进效果怎样核对

首先核对单位与数学性质，再核对真实数据上的解释能力。新增算法的验收至少应包括：

- 原有 14 项参考指标保持在既定数值容差内，原始 CSV 哈希不变。
- 逐帧 PSD 平均与当前 Welch 一致；完整单边频率箱求和乘以频点间隔，应等于 $\sum_n (x[n]w[n])^2/\sum_n w[n]^2$，而非未经加权的整窗 RMS 平方。
- 稳定正弦、已知突变与零信号分别验证持续谱峰、候选定位和零值处理；改变幅值时保持正确的平方功率尺度。
- 实验与背景含同频已知正弦时，给出邻近峰提示，但不自动删除它；相距超过匹配容差的峰不应匹配，容差内的不同频率仍仅为候选。
- 分段不足、候选重叠和记录边缘情况给出明确状态，不产生伪造的衰减参数。
- 所有结果仍由同一个 `run_demo` 入口导出，图与数值采用相同参数，并说明哪些结果只是候选。

合成信号用于检验算法，不替换公开实验数据。真实样品的区分能力最终需要独立、条件明确的重复测量验证。
