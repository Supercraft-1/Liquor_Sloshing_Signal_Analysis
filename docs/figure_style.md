# 图表格式

图宽 18 cm，白底，中文无衬线字体，常规字号约 8 pt。PNG 导出为 600 dpi。波形、FFT 和功率谱 PDF 保留矢量曲线和文字；含谱矩阵的 `diagnostics.pdf` 使用 600 dpi 图像导出。

## 曲线与坐标

实验曲线为黑色，背景曲线为蓝色。频谱用实线和虚线区分，频段积分用实心圆和空心方块区分。坐标轴采用细线、向外刻度，不显示网格。条件及计算细节放在图注中。

实验和背景波形各用独立纵轴；频谱共用坐标。频段积分按独立频段画点。样例只有一对记录，未绘制重复实验误差条。对数轴省略非正值，数值文件保留这些值。

## 短时谱

两幅谱图共用频率范围、dB 色标和连续蓝灰色阶。低值为浅蓝灰，高值为深蓝，色阶不包含纯白或纯黑。亮度随 PSD 增大单调降低，避免局部明暗反转。

颜色范围为 80 dB，超过显示范围的数值仍完整保存到 CSV。谱矩阵按实际帧和频率箱显示，不做插值。活动区间使用浅灰底色，峰值位置用空心圆标记。

## 字体与导出

支持 Noto Sans SC／Noto Sans CJK SC、Microsoft YaHei UI／Microsoft JhengHei，以及 macOS 的 PingFang SC／Heiti SC。缺少中文字体时程序报错。

绘图固定使用浅色主题，不随 MATLAB 桌面主题改变。静态中文字体在 PDF 中的字重较稳定；部分 Linux 环境会将文字转成轮廓，投稿前应检查目标环境的字体嵌入。

含图像的图窗强制使用矢量模式时可能出现细线伪影，参见 [MathWorks 导出说明](https://www.mathworks.com/help/matlab/ref/exportgraphics.html)。短时谱 PDF 因此采用高清图像模式。

排版参考 [Nature 科研图指南](https://research-figure-guide.nature.com/figures/preparing-figures-our-specifications/)；主题设置见 [MathWorks 文档](https://www.mathworks.com/help/matlab/creating_plots/graphics-and-app-themes.html)。
