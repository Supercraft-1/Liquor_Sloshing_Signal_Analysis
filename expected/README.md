# 参考输出

本目录由仓库根目录的 `run_demo` 实际生成，使用提交的两份 CSV 和 `src/case_config.m` 中的固定参数。

- 三组中文图：`waveform`、`spectrum`、`power`，分别提供 600 dpi PNG 和矢量 PDF。
- `metrics.csv`：完整精度的汇总指标。
- `band_metrics.csv`：PSD 积分功率、等效 RMS 和功率占比。
- `run_metadata.json`：生成参考结果的 MATLAB / 工具箱版本及算法参数。

正常运行写入 `output/`，不会覆盖此目录。测试按容差核对数值，不以图片哈希判断跨平台复现。

如果有意修改算法或参数，先通过解析信号测试并检查图表，再用实际输出更新参考文件；不能只更新参考值来让失败测试通过。
