# 参考输出

本目录保存 `run_demo` 对示例数据的参考结果。参数在 `src/case_config.m`。

- 四组中文图：`waveform`、`spectrum`、`power`、`diagnostics`，均提供 600 dpi PNG。前三组 PDF 保留矢量曲线和文字，短时分析 PDF 使用 600 dpi 图像导出。
- `metrics.csv`：完整精度的汇总指标。
- `band_metrics.csv`：PSD 积分功率、等效 RMS 和功率占比。
- `response_candidates.csv`：活动区间、局部 RMS 最大值及缩短支持窗口标记。
- `common_peaks.csv`：邻近强峰的频率、距离与幅值。
- `time_band_metrics.csv`：9 帧的四频段积分，分实验／背景记录。
- `run_metadata.json`：生成参考结果的 MATLAB / 工具箱版本及算法参数。

运行结果写入 `output/`。测试按容差核对数值，图像可能受系统字体影响。

修改算法或参数后，先运行解析信号测试并检查结果，再更新对应参考文件。
