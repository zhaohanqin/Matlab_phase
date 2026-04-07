# Matlab_phase

## 项目概览

这个仓库是一组面向结构光/条纹投影相位处理的 MATLAB 脚本，主要覆盖以下几类工作：

- 三频条纹图像读取、包裹相位计算与绝对相位展开
- ROI 选择、灰度剖面分析与结果可视化
- `.mat` / `.npy` 数据查看与格式转换
- PLY 点云浏览、误差对比与结果导出

仓库当前更像“实验脚本集合”而不是可直接安装的 MATLAB 工程：多数脚本通过直接运行文件启动，参数在文件头部手动配置，适合做实验验证、结果对比和可视化分析。

## 仓库快速导航

### 推荐先看

- `integrated_absolute_phase_tool.m`
  一体化入口，串起 ROI 选择、三频相位计算、绝对相位生成和结果保存，是最接近完整流程的主脚本。
- `three_frequency_phase_visualization.m`
  聚焦三频相位处理本身，适合单独查看三频图像到绝对相位的处理链路。
- `fringe_gray_analysis.m`
  用于条纹图像灰度剖面分析，适合检查高反光/非高反光区域的灰度变化。

### 结果与示例数据

- `integrated_results/`
  集成流程的输出目录，包含掩码、相位数据和可视化结果。
- `output/`
  灰度分析脚本输出的图片和 `.mat` 中间结果。
- 根目录下若干 `.mat` / `.bmp`
  包含示例相位结果和测试图像，可直接作为查看与可视化脚本的输入。

## 核心流程

仓库中比较完整的处理链大致如下：

1. 准备条纹投影图像序列，按固定命名方式放在目录中。
2. 在 `integrated_absolute_phase_tool.m` 或 `three_frequency_phase_visualization.m` 中配置图像目录、步数、频率组合和输出目录。
3. 读取多步相移图像并计算各频率的包裹相位。
4. 基于三频外差/分层展开逻辑生成绝对相位。
5. 结合 ROI 或掩码提取有效区域，并输出 `.mat`、曲线图、伪彩色图、可选 3D 表面图。
6. 使用可视化/比较脚本进一步分析单组结果、多组结果或点云误差。

如果只想看结果而不重新跑流程，优先使用以下脚本：

- `phase_visualization.m`
- `phase_2d_visualization_compare2d.m`
- `wrapped_phase_2d_visualization_compare2d.m`
- `mat_visualization.m`

## 目录与关键文件说明

### 顶层脚本

- `integrated_absolute_phase_tool.m`
  集成版相位处理工具。脚本内部包含 ROI 交互选择、行/列提取、相位计算与输出保存逻辑，默认输出到 `./integrated_results`。如果你只想从仓库里找一个“主入口”，优先看这个文件。

- `three_frequency_phase_visualization.m`
  三频相位处理与可视化脚本。更偏算法主链验证，适合在已有掩码的前提下单独跑三频图像到绝对相位的计算与展示。

- `fringe_gray_analysis.m`
  条纹图像灰度剖面分析工具。支持单图模式和双图对比模式，能交互式选择 ROI 与行/列，并输出灰度曲线、对比图和误差图，适合分析高反光区域对条纹质量的影响。

- `phase_visualization.m`
  单个相位矩阵的 3D/2D 可视化脚本。用于快速查看某个 `.mat` 相位结果的范围、表面形态和指定行剖面。

- `phase_2d_visualization_compare2d.m`
  多个绝对相位结果的对比脚本。会分别生成 3D 表面图，并在同一张 2D 图中比较指定行的相位曲线，适合横向比较不同算法或参数。

- `wrapped_phase_2d_visualization_compare2d.m`
  多个包裹相位结果的对比脚本。除了曲线比较外，还会统计相位跳变情况，适合观察包裹相位质量。

- `phase_Compare.m`
  两组绝对相位的逐点误差分析脚本。会计算 RMS、Success Rate 和误差点数量，并生成 3D 误差标记图，适合验证展开结果差异。

- `mat_visualization.m`
  通用 `.mat` 文件查看器。可列出变量并按维度自动选择可视化方式，适合作为数据探查工具。

- `npy_to_mat_converter.m`
  将 Python/NumPy 输出的 `.npy` 转为 MATLAB `.mat`。脚本依赖 MATLAB 的 Python 接口与 `numpy`，适合把外部算法结果接入本仓库的可视化流程。

- `pointcloud_compare.m`
  两个 PLY 点云的最近邻误差对比工具。支持阈值分色、误差统计、直方图和着色点云导出，适合比较重建结果。

- `ply_pointcloud_viewer.m`
  基于 `uifigure` 的 PLY 点云查看器，带基本信息显示、下采样、重置视角和截图保存功能。

- `display_ply_pointcloud.m`
  轻量级交互点云查看脚本。偏命令式使用方式，适合快速查看单个点云文件。

### 结果目录

- `integrated_results/mask/`
  集成流程生成的掩码结果。

- `integrated_results/phase_data/`
  集成流程输出的相位 `.mat` 数据，通常是后续可视化脚本的直接输入。

- `integrated_results/visualization/`
  集成流程自动保存的曲线图、伪彩色图和 3D 图等结果。

- `output/`
  `fringe_gray_analysis.m` 的输出目录，当前包含灰度剖面对比图和 `gray_profile.mat` 等中间结果。

这些目录主要是“运行产物目录”，阅读仓库时不需要逐个查看其中的图片或数据文件，优先关注生成这些结果的脚本。

## 文件之间的关系

- `integrated_absolute_phase_tool.m` 明显复用了 `fringe_gray_analysis.m` 中的交互思路，以及 `three_frequency_phase_visualization.m` 的相位计算主链。
- `phase_visualization.m`、`phase_2d_visualization_compare2d.m`、`wrapped_phase_2d_visualization_compare2d.m`、`phase_Compare.m` 都依赖已经生成好的 `.mat` 相位结果，因此它们更偏后处理和分析。
- `npy_to_mat_converter.m` 提供了从 Python 结果进入 MATLAB 分析链的桥接能力。
- `ply_pointcloud_viewer.m`、`display_ply_pointcloud.m`、`pointcloud_compare.m` 构成了点云查看与误差分析的独立分支，与相位主流程并行存在。

## 运行方式

## 环境要求

- MATLAB R2019b 或更高版本更稳妥
- 点云相关脚本通常需要 Computer Vision Toolbox
- `pointcloud_compare.m` 还可能依赖 Statistics and Machine Learning Toolbox
- `npy_to_mat_converter.m` 需要可用的 Python 环境和 `numpy`

## 使用方式

本仓库没有统一入口函数，通常按以下方式使用：

1. 打开 MATLAB，并将当前工作目录切到仓库根目录。
2. 根据目标任务打开对应脚本。
3. 在脚本顶部修改输入路径、输出路径、频率参数、行列索引或交互开关。
4. 直接运行整个脚本。

## 配置注意事项

- 多个脚本里仍写有本机绝对路径，例如 `H:\images\...`、`H:\code\Matlab_phase\...`。换机器后需要先改这些路径。
- 相位类脚本默认假设图像按固定命名规则排序，例如 `v1.bmp`、`v2.bmp` 等；使用前需要确认图像组织方式匹配脚本逻辑。
- 一些脚本使用交互式 UI（`uigetfile`、`drawrectangle`、鼠标点击选点），更适合桌面 MATLAB 环境，不适合纯无界面批处理。

## 从哪里开始阅读

如果你第一次接触这个仓库，建议按下面顺序看：

1. `integrated_absolute_phase_tool.m`
2. `three_frequency_phase_visualization.m`
3. `fringe_gray_analysis.m`
4. `phase_visualization.m` 和 `phase_2d_visualization_compare2d.m`
5. 点云相关脚本 `pointcloud_compare.m` / `ply_pointcloud_viewer.m`

如果你的目标只是复用已有结果做展示或对比，直接从可视化脚本开始会更高效。

## 当前仓库特征与维护建议

- 仓库以单文件脚本为主，适合实验迭代，但公共逻辑目前有重复。
- 如果后续继续维护，优先可以考虑把“图像读取”“ROI 选择”“相位加载”“结果保存”等逻辑抽成公共函数。
- 现有脚本头部中文注释存在编码历史问题；后续如果继续整理，建议统一为 UTF-8 编码保存。

