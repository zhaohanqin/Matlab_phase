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
%   6. 所有可视化窗口同时显示并立即保存，窗口保持开启供自由交互
%      （可使用工具栏放大/平移，或点击图像查看具体相位值）
%
% 对应 Python 源文件: three_frequency_phase_visualization.py
% 日期: 2026-03-18（修订：2026-03-20）
% =========================================================================
clear; clc; close all;

%% ========================= 用户配置区 =========================
IMAGE_FOLDER = 'H:\images\PSM_FSM\O1';
N_STEP       = 4;
FREQUENCIES  = [81, 72, 64];
STRIPE_DIR   = 'v';

MASK_PATH = 'H:\code\Matlab_phase\integrated_results\mask\mask.mat';

SAVE_DIR = '';
%% ==============================================================

try
    [abs_phase, masked_phase, mask] = process_3_frequency_pipeline(...
        IMAGE_FOLDER, N_STEP, FREQUENCIES, STRIPE_DIR, MASK_PATH, SAVE_DIR);
    fprintf('\n--- 处理完成，所有图窗已保存并保持开启，可自由交互查看 ---\n');
catch ME
    fprintf('\n❌ 处理出错: %s\n', ME.message);
    rethrow(ME);
end

%% ========================================================================
%  图像读取
% ========================================================================

function images = load_single_frequency_images(folder_path, phase_shift_step, ...
    orientation, frequency_index, image_ext)

    if nargin < 5 || isempty(image_ext)
        image_ext = detect_image_extension(folder_path, orientation, 1);
    end
    if isempty(image_ext)
        error('未找到图像文件，路径: %s', folder_path);
    end

    N = phase_shift_step;
    start_idx = frequency_index * N + 1;

    first_path = fullfile(folder_path, sprintf('%s%d%s', orientation, start_idx, image_ext));
    first_img = imread(first_path);
    if ndims(first_img) == 3, first_img = rgb2gray(first_img); end
    [H, W] = size(first_img);

    images = zeros(H, W, N, 'uint8');
    images(:, :, 1) = first_img;
    for i = 2:N
        img_idx = start_idx + i - 1;
        path = fullfile(folder_path, sprintf('%s%d%s', orientation, img_idx, image_ext));
        img = imread(path);
        if ndims(img) == 3, img = rgb2gray(img); end
        images(:, :, i) = img;
    end
end

function ext = detect_image_extension(folder_path, orientation, index)
    exts = {'.bmp', '.png', '.jpg', '.jpeg'};
    ext = '';
    for k = 1:length(exts)
        path = fullfile(folder_path, sprintf('%s%d%s', orientation, index, exts{k}));
        if isfile(path), ext = exts{k}; return; end
    end
end

function mask_bool = load_mask(mask_path)
    if ~isfile(mask_path)
        error('掩码文件不存在: %s', mask_path);
    end
    [~, ~, ext] = fileparts(mask_path);
    ext = lower(ext);

    switch ext
        case '.mat'
            data = load(mask_path);
            fields = fieldnames(data);
            mask = data.(fields{1});
        case '.npy'
            try
                mask = double(py.numpy.load(mask_path));
            catch
                error('.npy 格式需要 MATLAB Python 接口，请先转为 .mat 或 .png。');
            end
        case {'.png','.bmp','.jpg','.jpeg','.tif','.tiff'}
            mask = imread(mask_path);
            if ndims(mask) == 3, mask = rgb2gray(mask); end
        otherwise
            error('不支持的掩码格式: %s', ext);
    end

    mask_bool = logical(mask);
    fprintf('掩码已加载: %s，形状=[%d, %d]，有效像素=%d\n', ...
            mask_path, size(mask_bool,1), size(mask_bool,2), sum(mask_bool(:)));
end

%% ========================================================================
%  相位计算
% ========================================================================

function wrapped_phase = calculate_wrapped_phase(stripe_images)
    [H, W, N] = size(stripe_images);
    imgs = double(stripe_images);
    phase_shifts = 2 * pi * (0:(N-1)) / N;
    cos_sum = zeros(H, W);
    sin_sum = zeros(H, W);
    for i = 1:N
        cos_sum = cos_sum + imgs(:,:,i) * cos(phase_shifts(i));
        sin_sum = sin_sum + imgs(:,:,i) * sin(phase_shifts(i));
    end
    wrapped_phase = mod(-atan2(sin_sum, cos_sum), 2*pi);
end

function result = calculate_phase_difference(phase1, phase2)
    p1 = phase1 / (2*pi);
    p2 = phase2 / (2*pi);
    result = p1 - p2;
    result(result < 0) = result(result < 0) + 1;
    result = result * (2*pi);
end

function unwrap_phase = unwrap_phase_with_reference(reference_phase, ...
    target_phase, reference_freq, target_freq)
    ref = reference_phase / (2*pi);
    tar = target_phase  / (2*pi);
    temp = target_freq / reference_freq * ref;
    k = round(temp - tar);
    unwrap_phase = (tar + k) * (2*pi);
end

%% ========================================================================
%  数据保存
% ========================================================================

function save_phase_data(absolute_phase, masked_phase, mask, save_dir)
    if ~isfolder(save_dir), mkdir(save_dir); end

    % ── 以 phase_data 变量名保存，与 phase_visualization.m 兼容 ──
    phase_data = absolute_phase;
    save(fullfile(save_dir,'absolute_phase.mat'), 'phase_data');
    fprintf('  已保存: absolute_phase.mat  (变量名: phase_data)\n');

    phase_data = masked_phase;
    save(fullfile(save_dir,'masked_absolute_phase.mat'), 'phase_data');
    fprintf('  已保存: masked_absolute_phase.mat  (变量名: phase_data)\n');

    mask_uint8 = uint8(mask);
    save(fullfile(save_dir,'mask.mat'), 'mask','mask_uint8');
    fprintf('  已保存: mask.mat\n');

    fprintf('  数据已保存至: %s\n', save_dir);
end

%% ========================================================================
%  核心流程
% ========================================================================

function [absolute_phase, masked_phase, mask] = process_3_frequency_pipeline(...
    folder_path, phase_step, freq_list, orientation, mask_path, save_dir)

    fprintf('--- 开始处理: %s ---\n', folder_path);

    if isempty(save_dir)
        save_dir = fullfile(folder_path, 'results');
    end
    if ~isfolder(save_dir), mkdir(save_dir); end

    %% ── Step 1：读取图像，计算包裹相位 ──
    fprintf('Step 1: 读取图像并计算包裹相位...\n');
    imgs_h = load_single_frequency_images(folder_path, phase_step, orientation, 0);
    imgs_m = load_single_frequency_images(folder_path, phase_step, orientation, 1);
    imgs_l = load_single_frequency_images(folder_path, phase_step, orientation, 2);

    w_phase_h = calculate_wrapped_phase(imgs_h);
    w_phase_m = calculate_wrapped_phase(imgs_m);
    w_phase_l = calculate_wrapped_phase(imgs_l);

    %% ── Step 2：多频外差与相位展开 ──
    fprintf('Step 2: 多频外差与相位展开...\n');
    phi12        = calculate_phase_difference(w_phase_h, w_phase_m);
    phi23        = calculate_phase_difference(w_phase_m, w_phase_l);
    phi_low      = calculate_phase_difference(phi12,     phi23);
    f12          = freq_list(1) - freq_list(2);
    f23          = freq_list(2) - freq_list(3);
    f_final      = abs(f12 - f23);
    unwrap_phi12   = unwrap_phase_with_reference(phi_low, phi12, f_final, f12);
    absolute_phase = unwrap_phase_with_reference(unwrap_phi12, w_phase_h, f12, freq_list(1));

    %% ── Step 3：掩码处理 ──
    if ~isempty(mask_path) && isfile(mask_path)
        fprintf('Step 3: 加载掩码...\n');
        mask = load_mask(mask_path);
        if ~isequal(size(mask), size(absolute_phase))
            error('掩码尺寸不匹配！');
        end
        masked_phase = nan(size(absolute_phase));
        masked_phase(mask) = absolute_phase(mask);
    else
        fprintf('Step 3: 无掩码，使用全场。\n');
        mask = true(size(absolute_phase));
        masked_phase = absolute_phase;
    end

    %% ── Step 4：保存数据 ──
    fprintf('Step 4: 保存数据...\n');
    save_phase_data(absolute_phase, masked_phase, mask, save_dir);

    %% ── Step 5：生成所有可视化图（立即保存，窗口保持开启） ──
    fprintf('Step 5: 生成可视化图像...\n');

    % has_mask：掩码并非全图 true 时，才视为真正启用了掩码
    has_mask = ~all(mask(:));

    % display_phase：有掩码则区域外置 NaN，无掩码则等于 absolute_phase
    display_phase = absolute_phase;
    if has_mask
        display_phase(~mask) = NaN;
    end

    % ── 打印相位统计信息（基于实际显示区域，排除 NaN） ──
    valid_all  = display_phase(~isnan(display_phase));
    phase_min  = min(valid_all);
    phase_max  = max(valid_all);
    fprintf('\nAbsolute phase range:\n');
    fprintf('  Min = %.6f rad (%.3fπ)\n', phase_min, phase_min/pi);
    fprintf('  Max = %.6f rad (%.3fπ)\n', phase_max, phase_max/pi);
    fprintf('  Peak-to-peak = %.6f rad (%.3fπ)\n', ...
            phase_max-phase_min, (phase_max-phase_min)/pi);

    % ── 图1：绝对相位 3D 表面图 ──
    % 有掩码时仅显示掩码区域，无掩码时显示全场
    figure;
    surf(display_phase, 'EdgeColor', 'none');
    shading interp;
    colormap(parula);
    colorbar;
    view(3);
    axis tight;
    xlabel('X (pixel)');
    ylabel('Y (pixel)');
    zlabel('Absolute Phase (rad)');
    title(sprintf('Absolute Phase Map  [%.2fπ , %.2fπ]', ...
          phase_min/pi, phase_max/pi));
    drawnow;
    exportgraphics(gcf, fullfile(save_dir,'absolute_phase_3d.png'), 'Resolution',200);
    fprintf('  已保存: absolute_phase_3d.png\n');

    % ── 图2：绝对相位 2D 伪彩色图 ──
    % 有掩码：区域外透明（AlphaData + 白底）；无掩码：直接显示全场
    figure;
    if has_mask
        imagesc(display_phase, 'AlphaData', double(mask));
        set(gca, 'Color', 'w');
        fig2_title = sprintf('掩码区域绝对相位图  (最高频率: %d)', freq_list(1));
    else
        imagesc(display_phase);
        fig2_title = sprintf('绝对相位图  (最高频率: %d)', freq_list(1));
    end
    colormap(parula);
    title(fig2_title, 'FontSize', 14);
    xlabel('列索引 (pixels)', 'FontSize', 12);
    ylabel('行索引 (pixels)', 'FontSize', 12);
    c2 = colorbar; c2.Label.String = 'Absolute Phase (rad)';
    axis image;
    drawnow;
    exportgraphics(gcf, fullfile(save_dir,'absolute_phase_masked.png'), 'Resolution',200);
    fprintf('  已保存: absolute_phase_masked.png\n');

    % ── 图3：中心行相位走势 ──
    % 有掩码时剖面含 NaN（掩码外），统计量跳过 NaN；无掩码时全行有效
    position = 'center';
    [height, width] = size(display_phase);
    center_row = round(height / 2);
    line_data  = display_phase(center_row, :);

    valid_line = line_data(~isnan(line_data));
    line_min   = min(valid_line);
    line_max   = max(valid_line);
    line_mean  = mean(valid_line);
    line_std   = std(valid_line);

    fprintf('\n正在生成相位变化曲线图...\n');
    fprintf('  选择行索引（纵坐标）: %d (位置: %s)\n', center_row, position);
    fprintf('  相位范围: [%.4f, %.4f] rad\n', line_min, line_max);
    fprintf('  相位变化: %.4f rad\n', line_max - line_min);
    fprintf('  平均值: %.4f rad\n', line_mean);
    fprintf('  标准差: %.4f rad\n', line_std);

    figure;
    plot(1:width, line_data, 'b-', 'LineWidth', 1.5);
    hold on;
    plot([1, width], [line_mean, line_mean], '--r', 'LineWidth', 2, ...
         'DisplayName', sprintf('平均值: %.4f', line_mean));
    title(sprintf('绝对相位变化曲线 - 第 %d 行（%s位置）', center_row, position), ...
          'FontSize', 16);
    xlabel('列索引 (pixels)', 'FontSize', 14);
    ylabel('相位值 (rad)', 'FontSize', 14);
    grid on;
    grid minor;
    legend('Location', 'best', 'FontSize', 12);
    hold off;
    drawnow;
    exportgraphics(gcf, fullfile(save_dir,'phase_line_profile_masked.png'), 'Resolution',200);
    fprintf('  已保存: phase_line_profile_masked.png\n');
    fprintf('✓ 相位变化曲线图生成完成\n');

    fprintf('\n✔ 所有结果已保存至: %s\n', save_dir);
    fprintf('✔ 共 3 个图窗均已保持开启，可自由放大、平移或点击查看具体相位值。\n');
end
