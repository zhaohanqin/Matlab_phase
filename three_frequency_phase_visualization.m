%% three_frequency_phase_visualization.m
% =========================================================================
% 三频相位可视化工具（MATLAB 版）
% Three-Frequency Phase Visualization Tool
%
% 功能：
%   1. 读取3个频率的N步相移条纹图像
%   2. 计算三个频率的包裹相位
%   3. 利用多频外差/塔形展开逻辑生成绝对相位
%   4. 读取掩码文件（.mat/.npy 或图像格式），提取掩码区域内的绝对相位
%   5. 保存绝对相位与掩码相位为 .mat 格式
%   6. 在掩码区域上进行可视化显示，并保存图片
%
% 对应 Python 源文件: three_frequency_phase_visualization.py
% 作者: Claude (Anthropic)
% 日期: 2026-03-18
% =========================================================================
clear; clc; close all;

%% ========================= 用户配置区 =========================
IMAGE_FOLDER = 'E:\images\PSM_FSM\O1';     % 条纹图像路径
N_STEP       = 4;                            % 相移步数
FREQUENCIES  = [81, 72, 64];                 % 三个频率 [高, 中, 低]
STRIPE_DIR   = 'v';                          % 'h' 水平或 'v' 垂直

% 掩码文件路径（支持 .mat, .npy, .png, .bmp 等，设为 '' 则不使用掩码）
MASK_PATH = 'integrated_results\mask\mask.bmp';

% 结果保存目录（设为 '' 则默认保存在图像文件夹下的 results 子目录）
SAVE_DIR = '';
%% ==============================================================

try
    [abs_phase, masked_phase, mask] = process_3_frequency_pipeline(...
        IMAGE_FOLDER, N_STEP, FREQUENCIES, STRIPE_DIR, MASK_PATH, SAVE_DIR);
    fprintf('\n--- 处理完成 ---\n');
catch ME
    fprintf('\n❌ 处理出错: %s\n', ME.message);
    rethrow(ME);
end

%% ========================================================================
%  部分 A：来自《单频相位处理工具.py》的核心算法（MATLAB 实现）
% ========================================================================

% ─── 图像加载器 ───
function images = load_single_frequency_images(folder_path, phase_shift_step, ...
    orientation, frequency_index, image_ext)
    % 读取单一频率的一组 N 步相移条纹图像
    % 对应 Python: ImageLoader.load_single_frequency_images
    %
    % 返回: images — H×W×N uint8 数组
    % 注意: frequency_index 从 0 开始（与 Python 保持一致）

    if nargin < 5 || isempty(image_ext)
        image_ext = detect_image_extension(folder_path, orientation, 1);
    end
    if isempty(image_ext)
        error('未找到图像文件，路径: %s', folder_path);
    end

    N = phase_shift_step;
    start_idx = frequency_index * N + 1;

    % 读取第一张确定尺寸
    first_path = fullfile(folder_path, sprintf('%s%d%s', orientation, start_idx, image_ext));
    first_img = imread(first_path);
    if ndims(first_img) == 3
        first_img = rgb2gray(first_img);
    end
    [H, W] = size(first_img);

    images = zeros(H, W, N, 'uint8');
    images(:, :, 1) = first_img;

    for i = 2:N
        img_idx = start_idx + i - 1;
        path = fullfile(folder_path, sprintf('%s%d%s', orientation, img_idx, image_ext));
        img = imread(path);
        if ndims(img) == 3
            img = rgb2gray(img);
        end
        images(:, :, i) = img;
    end
end

function ext = detect_image_extension(folder_path, orientation, index)
    % 自动检测文件夹中图像文件的扩展名
    % 对应 Python: detect_image_extension
    exts = {'.bmp', '.png', '.jpg', '.jpeg'};
    ext = '';
    for k = 1:length(exts)
        path = fullfile(folder_path, sprintf('%s%d%s', orientation, index, exts{k}));
        if isfile(path)
            ext = exts{k};
            return;
        end
    end
end

% ─── 掩码加载器 ───
function mask_bool = load_mask(mask_path)
    % 读取掩码文件，返回逻辑类型的二维数组
    % 对应 Python: MaskLoader.load_mask
    % 支持 .mat, .npy（需特殊处理）, .png, .bmp 等

    if ~isfile(mask_path)
        error('掩码文件不存在: %s', mask_path);
    end

    [~, ~, ext] = fileparts(mask_path);
    ext = lower(ext);

    switch ext
        case '.mat'
            data = load(mask_path);
            fields = fieldnames(data);
            mask = data.(fields{1});  % 取第一个变量
        case '.npy'
            % MATLAB 原生不支持 .npy，尝试使用 Python 接口
            % 或者建议用户先转换为 .mat
            try
                mask = double(py.numpy.load(mask_path));
            catch
                error(['.npy 格式需要 MATLAB Python 接口支持。', ...
                       '请先将掩码转换为 .mat 或 .png 格式。']);
            end
        case {'.png', '.bmp', '.jpg', '.jpeg', '.tif', '.tiff'}
            mask = imread(mask_path);
            if ndims(mask) == 3
                mask = rgb2gray(mask);
            end
        otherwise
            error('不支持的掩码文件格式: %s，请使用 .mat 或 .png', ext);
    end

    mask_bool = logical(mask);
    fprintf('掩码已加载: %s，形状=[%d, %d]，有效像素数=%d\n', ...
            mask_path, size(mask_bool, 1), size(mask_bool, 2), sum(mask_bool(:)));
end

% ─── 相位计算器 ───
function wrapped_phase = calculate_wrapped_phase(stripe_images)
    % 计算单频 N 步相移数据的包裹相位
    % 对应 Python: PhaseCalculator.calculate_single_frequency_wrapped_phase
    %
    % 公式:
    %   φ(x,y) = -arctan2(Σ I_n sin Δφ_n, Σ I_n cos Δφ_n)  → mod 2π
    %
    % 输入: stripe_images — H×W×N uint8 数组
    % 输出: wrapped_phase — H×W double 数组，范围 [0, 2π)

    [H, W, N] = size(stripe_images);
    imgs = double(stripe_images);
    phase_shifts = 2 * pi * (0:(N-1)) / N;

    cos_sum = zeros(H, W);
    sin_sum = zeros(H, W);
    for i = 1:N
        cos_sum = cos_sum + imgs(:, :, i) * cos(phase_shifts(i));
        sin_sum = sin_sum + imgs(:, :, i) * sin(phase_shifts(i));
    end

    wrapped_phase = -atan2(sin_sum, cos_sum);
    wrapped_phase = mod(wrapped_phase, 2 * pi);
end

function result = calculate_phase_difference(phase1, phase2)
    % 计算两个包裹相位的相位差（外差过程）
    % 对应 Python: PhaseCalculator.calculate_phase_difference
    %
    % 输出范围: [0, 2π)

    p1 = phase1 / (2 * pi);
    p2 = phase2 / (2 * pi);
    result = p1 - p2;
    result(result < 0) = result(result < 0) + 1;
    result = result * (2 * pi);
end

function unwrap_phase = unwrap_phase_with_reference(reference_phase, ...
    target_phase, reference_freq, target_freq)
    % 使用参考相位展开高频相位
    % 对应 Python: PhaseCalculator.unwrap_phase_with_reference
    %
    % 输出: 绝对相位（弧度），可大于 2π

    ref = reference_phase / (2 * pi);
    tar = target_phase / (2 * pi);
    temp = target_freq / reference_freq * ref;
    k = round(temp - tar);
    unwrap_phase = (tar + k) * (2 * pi);
end

%% ========================================================================
%  部分 B：可视化与数据保存
% ========================================================================

function save_phase_data(absolute_phase, masked_phase, mask, save_dir)
    % 保存绝对相位数据为 .mat 格式
    % 对应 Python: save_phase_data
    if ~isfolder(save_dir), mkdir(save_dir); end

    % 保存完整绝对相位
    save(fullfile(save_dir, 'absolute_phase.mat'), 'absolute_phase');
    fprintf('  已保存: absolute_phase.mat\n');

    % 保存掩码区域内的绝对相位
    save(fullfile(save_dir, 'masked_absolute_phase.mat'), 'masked_phase');
    fprintf('  已保存: masked_absolute_phase.mat\n');

    % 保存掩码
    mask_uint8 = uint8(mask);
    save(fullfile(save_dir, 'mask.mat'), 'mask', 'mask_uint8');
    fprintf('  已保存: mask.mat\n');

    fprintf('所有数据已保存至: %s\n', save_dir);
end

function show_phase_line_profile(phase, row_index, position, title_str, save_path)
    % 显示指定行的相位曲线
    % 对应 Python: show_phase_line_profile

    if nargin < 2, row_index = []; end
    if nargin < 3, position = 'center'; end
    if nargin < 4, title_str = '绝对相位走势图'; end
    if nargin < 5, save_path = ''; end

    [height, width] = size(phase);

    if isempty(row_index)
        switch position
            case 'top',    row_index = round(height / 10);
            case 'bottom', row_index = round(height * 9 / 10);
            case 'center', row_index = round(height / 2);
            otherwise,     row_index = round(height / 2);
        end
    end
    row_index = max(1, min(row_index, height));

    line_data = phase(row_index, :);

    fig = figure('Position', [100 200 1200 500], 'Visible', 'off');
    plot(1:width, line_data, 'b', 'LineWidth', 1.5);
    title(sprintf('%s - 第 %d 行', title_str, row_index), 'FontSize', 14);
    xlabel('列索引 (pixels)', 'FontSize', 12);
    ylabel('绝对相位 (rad)', 'FontSize', 12);
    grid on; grid minor;
    set(gca, 'GridAlpha', 0.3);

    if ~isempty(save_path)
        [folder, ~, ~] = fileparts(save_path);
        if ~isfolder(folder), mkdir(folder); end
        exportgraphics(fig, save_path, 'Resolution', 200);
        fprintf('  走势图已保存: %s\n', save_path);
    end
    close(fig);
end

%% ========================================================================
%  部分 C：整合处理流程（核心逻辑）
% ========================================================================

function [absolute_phase, masked_phase, mask] = process_3_frequency_pipeline(...
    folder_path, phase_step, freq_list, orientation, mask_path, save_dir)
    % 核心流程：输入条纹 -> 绝对相位计算 -> 掩码处理 -> 保存与可视化
    % 对应 Python: process_3_frequency_pipeline
    %
    % 参数:
    %   folder_path : 条纹图像所在文件夹路径
    %   phase_step  : 相移步数 N
    %   freq_list   : 三个频率 [高, 中, 低]
    %   orientation : 条纹方向 'h'/'v'
    %   mask_path   : 掩码文件路径，'' 则不使用掩码
    %   save_dir    : 结果保存目录，'' 则默认 folder_path/results

    fprintf('--- 开始处理: %s ---\n', folder_path);

    if isempty(save_dir)
        save_dir = fullfile(folder_path, 'results');
    end
    if ~isfolder(save_dir), mkdir(save_dir); end

    % =====================================================================
    % 1. 读取条纹图并计算包裹相位
    % =====================================================================
    fprintf('Step 1: 正在读取条纹图像并计算包裹相位...\n');
    imgs_h = load_single_frequency_images(folder_path, phase_step, orientation, 0);
    imgs_m = load_single_frequency_images(folder_path, phase_step, orientation, 1);
    imgs_l = load_single_frequency_images(folder_path, phase_step, orientation, 2);

    w_phase_h = calculate_wrapped_phase(imgs_h);
    w_phase_m = calculate_wrapped_phase(imgs_m);
    w_phase_l = calculate_wrapped_phase(imgs_l);

    % =====================================================================
    % 2. 多频外差与相位展开
    % =====================================================================
    fprintf('Step 2: 正在进行多频外差与相位展开...\n');
    phi12 = calculate_phase_difference(w_phase_h, w_phase_m);
    phi23 = calculate_phase_difference(w_phase_m, w_phase_l);
    phi_final_low = calculate_phase_difference(phi12, phi23);

    f_diff12 = freq_list(1) - freq_list(2);
    f_diff23 = freq_list(2) - freq_list(3);
    f_final  = abs(f_diff12 - f_diff23);

    unwrap_phi12 = unwrap_phase_with_reference(phi_final_low, phi12, f_final, f_diff12);
    absolute_phase = unwrap_phase_with_reference(unwrap_phi12, w_phase_h, f_diff12, freq_list(1));

    % =====================================================================
    % 3. 掩码处理
    % =====================================================================
    if ~isempty(mask_path) && isfile(mask_path)
        fprintf('Step 3: 正在加载掩码并提取掩码区域相位...\n');
        mask = load_mask(mask_path);

        if ~isequal(size(mask), size(absolute_phase))
            error('掩码尺寸 [%d,%d] 与相位图尺寸 [%d,%d] 不匹配！', ...
                size(mask,1), size(mask,2), size(absolute_phase,1), size(absolute_phase,2));
        end

        masked_phase = nan(size(absolute_phase));
        masked_phase(mask) = absolute_phase(mask);
    else
        fprintf('Step 3: 未指定掩码文件，将使用全场数据...\n');
        mask = true(size(absolute_phase));
        masked_phase = absolute_phase;
    end

    % =====================================================================
    % 4. 保存数据
    % =====================================================================
    fprintf('Step 4: 正在保存相位数据...\n');
    save_phase_data(absolute_phase, masked_phase, mask, save_dir);

    % =====================================================================
    % 5. 可视化并保存图片
    % =====================================================================
    fprintf('Step 5: 生成可视化图像并保存...\n');

    % --- 5a. 全场绝对相位图 ---
    fig1 = figure('Position', [100 100 800 600], 'Visible', 'off');
    imagesc(absolute_phase); colormap(jet); colorbar;
    title(sprintf('全场绝对相位图 (频率: %d)', freq_list(1)), 'FontSize', 14);
    c = colorbar; c.Label.String = '弧度 (rad)';
    axis image;
    path_full = fullfile(save_dir, 'absolute_phase_full.png');
    exportgraphics(fig1, path_full, 'Resolution', 200);
    fprintf('  已保存: %s\n', path_full);
    close(fig1);

    % --- 5b. 掩码区域绝对相位图 ---
    fig2 = figure('Position', [100 100 800 600], 'Visible', 'off');
    display_phase = absolute_phase;
    display_phase(~mask) = NaN;
    imagesc(display_phase, 'AlphaData', mask);
    colormap(jet); colorbar;
    title(sprintf('掩码区域绝对相位图 (频率: %d)', freq_list(1)), 'FontSize', 14);
    c = colorbar; c.Label.String = '弧度 (rad)';
    set(gca, 'Color', 'w');
    axis image;
    path_masked = fullfile(save_dir, 'absolute_phase_masked.png');
    exportgraphics(fig2, path_masked, 'Resolution', 200);
    fprintf('  已保存: %s\n', path_masked);
    close(fig2);

    % --- 5c. 掩码叠加对比图 ---
    fig3 = figure('Position', [50 100 1600 600], 'Visible', 'off');

    subplot(1, 2, 1);
    imagesc(absolute_phase); colormap(jet);
    title('全场绝对相位', 'FontSize', 13);
    xlabel('列索引 (pixels)'); ylabel('行索引 (pixels)');
    axis image; colorbar;

    subplot(1, 2, 2);
    imagesc(display_phase, 'AlphaData', mask);
    colormap(jet);
    title('掩码区域绝对相位', 'FontSize', 13);
    xlabel('列索引 (pixels)'); ylabel('行索引 (pixels)');
    set(gca, 'Color', 'w');
    axis image; colorbar;

    sgtitle(sprintf('绝对相位对比 (频率: %d)', freq_list(1)), 'FontSize', 15);
    path_compare = fullfile(save_dir, 'phase_comparison.png');
    exportgraphics(fig3, path_compare, 'Resolution', 200);
    fprintf('  已保存: %s\n', path_compare);
    close(fig3);

    % --- 5d. 掩码区域中心行相位走势 ---
    show_phase_line_profile(masked_phase, [], 'center', ...
        '掩码区域绝对相位中心行走势', ...
        fullfile(save_dir, 'phase_line_profile_masked.png'));

    fprintf('\n所有结果已保存至: %s\n', save_dir);
end
