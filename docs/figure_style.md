# 图表排版说明

图是 `run_demo` 的实际输出，不是概念插画。绘图函数只读取分析结果，不平滑曲线、不重新拟合数据，也不改变窗口、频率网格和归一化方式。

## 本例的取舍

- 18 cm 宽白底图，中文无衬线字体，字号约 8 pt；PNG 600 dpi，PDF 矢量导出。
- 黑色实验曲线、蓝色背景曲线；频谱同时用实线／虚线区分，便于灰度阅读。
- 小号子图标识、黑色文字、细坐标轴；移除大标题、背景网格、阴影与彩色说明框。详细条件放在 README 图注和方法说明中。
- 频段积分用对数纵轴的散点表示，实心圆／空心方块区分两份独立记录。不同频段不连线；没有重复样本，故不画误差条。
- 实验与背景波形采用独立纵轴，明确标注；频谱使用同一坐标进行对照。零值仅在对数图上留空，数值文件保留原值。

采用 Noto Sans SC 或 Noto Sans CJK SC；Windows 也支持 Microsoft YaHei UI／Microsoft JhengHei，macOS 支持 PingFang SC／Heiti SC。没有可用中文字体时明确报错，避免生成方框乱码。不同系统的字体细节可能不同，复现以数值和图形内容为准。

## 参考

参考 [Nature 的科研图准备指南](https://research-figure-guide.nature.com/figures/preparing-figures-our-specifications/) 关于去除无关装饰、清晰轴标签、可访问配色和矢量导出的原则。中文标签和网页阅读字号是本项目的选择，**不声称已满足某期刊的全部投稿规格**。

[Huang 等，Nature 626, 512–516 (2024)](https://www.nature.com/articles/s41586-023-06997-3) 中的噪声功率谱及其详细图注，可作为“同一坐标比较测量曲线、将解释移入图注”的组织参考；其物理系统与本例不同，不能据此类推检测性能。

PDF 在 Windows 上导出并检查中文。优先使用静态中文字体，避免部分可变字体在 PDF 中被映射到过细字重。绘图固定为浅色主题，坐标区显式设为白底，不受 MATLAB 桌面深色设置影响；依据见 [MathWorks 图形主题说明](https://www.mathworks.com/help/matlab/creating_plots/graphics-and-app-themes.html)。

MATLAB 在某些 Linux 环境会将字体转成轮廓；这仍是矢量图，但文字不一定可搜索。需要可编辑文字的投稿版本，应在目标环境单独检查字体嵌入。
