# 参考输出

本目录由仓库根目录的 `run_demo` 实际生成，使用提交的两份 CSV 和 `src/case_config.m` 中的固定参数。

- 四组中文图：`waveform`、`spectrum`、`power`、`diagnostics`，分别提供 600 dpi PNG 和 PDF；诊断 PDF 中的谱矩阵为嵌入图像，曲线与文字保留矢量图元。
- `metrics.csv`：完整精度的汇总指标。
- `band_metrics.csv`：PSD 积分功率、等效 RMS 和功率占比。
- `response_candidates.csv`：活动区间、局部 RMS 最大值及缩短支持窗口标记。
- `common_peaks.csv`：邻近强峰的频率、距离与幅值。
- `time_band_metrics.csv`：9 帧的四频段积分，分实验／背景记录。
- `run_metadata.json`：生成参考结果的 MATLAB / 工具箱版本及算法参数。

正常运行写入 `output/`，不会覆盖此目录。测试按容差核对数值，不以图片哈希判断跨平台复现。

如果有意修改算法或参数，先通过解析信号测试并检查图表，再用实际输出更新参考文件；不能只更新参考值来让失败测试通过。
