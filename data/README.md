# 示例数据来源

两份 CSV 由原实验 Excel 转换，保留完整时间列与 ADC 值。Excel 在 `legacy/02_Data/`。

| 公开案例文件 | 原文件 | 样本数 | 时间范围 |
| --- | --- | ---: | --- |
| `example_signal.csv` | `Signal_0512_2320.xlsx` | 11264 | 0–2.2526 s |
| `example_background.csv` | `Background_0512_2319.xlsx` | 9216 | 0–1.8430 s |

列名为 `Time_s`（秒）和 `ADC_Value`（未经电压或加速度标定的 ADC 计数），采样间隔为 0.0002 s，即 5000 Hz。默认入口固定取实验记录的 `[0.60, 1.60)` s 和背景记录的 `[0.20, 1.20)` s，各 5000 点。先对完整记录滤波再截取这两个区间；背景窗口避开了记录起点。

原采集程序使用 Signal 和 Background 文件名。文件未附液体浓度、温度、瓶体、传感器标定及激励条件表，样例沿用“实验记录／背景记录”名称。背景原始值范围为 2026–2080 ADC 计数。

来源版本：[5def4b6](https://github.com/Supercraft-1/Liquor_Sloshing_Signal_Analysis/tree/5def4b6ce1d7afc62e8a784b082a7ed63eed7990)。如需核对转换，可在仓库根目录运行 `addpath('tools'); prepare_example_data`；工具会逐项检查导出前后的 ADC 值与时间戳。正常复现不需要执行这一步。

## SHA-256

```text
example_signal.csv
c258481affd3f63b93c083915186e08a8568ec49ab9f9694e7168e65c7dd91e6

example_background.csv
53a9dc70e3f6b7d5a2a011fac8bcc2a688c09f4ace0940396587319e699fd806

Signal_0512_2320.xlsx
408040a10a4bee8f14e7b74322cbf0f398b196aa46e72fbd4291ada2ad5054dc

Background_0512_2319.xlsx
297f7180b51e556b8fe534f067201e2b5b5ca1ae4d7687a7acb1850b0ee5863c
```
