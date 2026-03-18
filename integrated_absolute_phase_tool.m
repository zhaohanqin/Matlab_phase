%% integrated_absolute_phase_tool.m
% =========================================================================
% 整合版：绝对相位生成与可视化工具（MATLAB 版）
% Integrated Absolute Phase Generation & Visualization Tool
%
% 整合思路：
%   ① 参考 fringe_gray_analysis.m —— 确定掩码（ROI）、选择要分析的行或列
%   ② 参考 three_frequency_phase_visualization.m —— 读图 + 相位计算
%   ③ 三频改进塔形法 —— 生成绝对相位
%   ④ 对指定行/列的绝对相位进行可视化（剖面曲线 + 2D伪彩色图 + 3D表面图）
%
% 借鉴来源:
%   步骤1: fringe_gray_analysis.py → ROISelector 类
%   步骤2: 单频相位处理工具.py → ImageLoader
%   步骤3: 单频相位处理工具.py → test_multiple_frequencies2
%   步骤4: 绝对相位可视化工具.py → PhaseVisualizer
%
% 对应 Python 源文件: integrated_absolute_phase_tool.py
% 作者: Claude (Anthropic)
% 日期: 2026-03-18
% =========================================================================
clear; clc; close all;

%% ╔════════════════════════════════════════════════════════════════════╗
%  ║                     ★★★ 用户参数区 ★★★                         ║
%  ╚════════════════════════════════════════════════════════════════════╝

% ---- 条纹图像参数 ----
PROJECTION_FOLDER = 'E:\images\PSM_FSM\O2';   % 相移图像文件夹
PHASE_SHIFT_STEP  = 4;                          % 相移步数
ORIENTATION       = 'v';                        % 条纹方向 'h' 或 'v'
FREQ_COMBINATION  = '81-72-64';                 % 频率组合字符串（如 '81-72-64'）

% ---- ROI 掩码参数 ----
ROI_BACKGROUND_IMAGE = '';    % 用于 ROI 选择时显示的背景图路径（空=用首张条纹图）
ROI = [];                      % [r0, r1, c0, c1] 手动指定 ROI，[] = 全图（1-based）
% 示例: ROI = [100, 900, 200, 1600]

% ---- 行列分析参数 ----
EXTRACT_MODE = 'row';          % 'row' 或 'col'
LINE_INDEX   = [];             % [] = 自动根据 POSITION 选择
POSITION     = 'center';       % 'top'/'bottom'/'center'/'quarter'/'three_quarter'

% ---- 输出参数 ----
OUTPUT_DIR   = './integrated_results';
GENERATE_3D  = true;

% ---- 是否使用交互模式 ----
USE_INTERACTIVE = false;       % true = 鼠标框选 ROI

%% ╔════════════════════════════════════════════════════════════════════╗
%  ║                         程序入口                                  ║
%  ╚════════════════════════════════════════════════════════════════════╝

result = run_integrated_pipeline(...
    PROJECTION_FOLDER, PHASE_SHIFT_STEP, ORIENTATION, FREQ_COMBINATION, ...
    ROI_BACKGROUND_IMAGE, ROI, ...
    EXTRACT_MODE, LINE_INDEX, POSITION, ...
    OUTPUT_DIR, GENERATE_3D, USE_INTERACTIVE);

%% ========================================================================
%  步骤一：图像读取
%  （借鉴 单频相位处理工具.py → ImageLoader 类）
% ========================================================================

function ext = detect_image_extension(folder_path, orientation, index)
    % 自动检测文件夹中图像文件的扩展名
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

function num_freqs = detect_num_frequencies(folder_path, phase_shift_step, ...
    orientation, image_ext, verbose)
    % 自动检测给定方向下包含多少个频率段
    if nargin < 5, verbose = true; end
    N = phase_shift_step;

    if isempty(image_ext)
        image_ext = detect_image_extension(folder_path, orientation, 1);
        if isempty(image_ext)
            error('在 %s 中未找到以 %s1 开头的图像文件', folder_path, orientation);
        end
    end

    count = 0;
    idx = 1;
    while true
        path = fullfile(folder_path, sprintf('%s%d%s', orientation, idx, image_ext));
        if ~isfile(path), break; end
        count = count + 1;
        idx = idx + 1;
    end

    if count == 0
        error('在 %s 中未找到 %s 开头的 %s 图像', folder_path, orientation, image_ext);
    end
    if mod(count, N) ~= 0
        error('检测到 %d 张图像，不能被 N=%d 整除', count, N);
    end

    num_freqs = count / N;
    if verbose
        fprintf('检测到 %s 方向共有 %d 个频率段，每个频率 %d 步。\n', ...
                upper(orientation), num_freqs, N);
    end
end

function images = load_single_frequency_images(folder_path, phase_shift_step, ...
    orientation, frequency_index, num_frequencies, image_ext)
    % 读取单一频率的一组N步相移条纹图像
    % frequency_index 从 0 开始
    % 返回: H×W×N uint8 数组

    if nargin < 6 || isempty(image_ext)
        image_ext = detect_image_extension(folder_path, orientation, 1);
        if isempty(image_ext)
            error('在 %s 中未找到以 %s1 开头的图像文件', folder_path, orientation);
        end
    end

    N = phase_shift_step;
    if nargin < 5 || isempty(num_frequencies)
        num_frequencies = detect_num_frequencies(folder_path, phase_shift_step, ...
            orientation, image_ext);
    end

    if frequency_index < 0 || frequency_index >= num_frequencies
        error('frequency_index=%d 超出范围 0~%d', frequency_index, num_frequencies - 1);
    end

    start_idx = frequency_index * N + 1;

    % 读取第一张确定尺寸
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

%% ========================================================================
%  步骤二：ROI 选择 & 掩码生成
%  （借鉴 fringe_gray_analysis.py → ROISelector 类）
% ========================================================================

function [roi_bounds, mode, line_index] = select_roi_interactive_phase(bg_img)
    % 交互式 ROI 选择（鼠标框选 + 命令行输入行/列号）
    [h, w] = size(bg_img);

    % 阶段1：鼠标框选 ROI
    fig1 = figure('Name', '阶段 1/2 — 框选 ROI', 'NumberTitle', 'off');
    imshow(bg_img, []);
    title('鼠标拖拽框选 ROI，双击确认（不框选直接关闭=全图）', ...
          'FontSize', 12, 'FontWeight', 'bold');

    roi_bounds = [1, h, 1, w];
    try
        rect = drawrectangle('Color', 'r', 'FaceAlpha', 0.15);
        wait(rect);
        pos = rect.Position;
        c0 = max(1, round(pos(1)));
        r0 = max(1, round(pos(2)));
        c1 = min(w, round(pos(1) + pos(3)));
        r1 = min(h, round(pos(2) + pos(4)));
        if (r1 - r0) >= 2 && (c1 - c0) >= 2
            roi_bounds = [r0, r1, c0, c1];
            fprintf('[INFO] ROI: 行[%d:%d], 列[%d:%d]\n', r0, r1, c0, c1);
        end
    catch
        fprintf('[INFO] 未选择 ROI，使用全图。\n');
    end
    close(fig1);

    % 阶段2：选择行/列
    roi_h = roi_bounds(2) - roi_bounds(1) + 1;
    roi_w = roi_bounds(4) - roi_bounds(3) + 1;
    fprintf('ROI 尺寸: %d×%d\n', roi_w, roi_h);
    mode_input = input('选择方向 (row/col) [row]: ', 's');
    if isempty(mode_input), mode_input = 'row'; end
    mode = mode_input;

    if strcmp(mode, 'row')
        default_idx = round(roi_h / 2);
        idx_input = input(sprintf('输入行号 (1-%d) [%d]: ', roi_h, default_idx), 's');
    else
        default_idx = round(roi_w / 2);
        idx_input = input(sprintf('输入列号 (1-%d) [%d]: ', roi_w, default_idx), 's');
    end
    if isempty(idx_input)
        line_index = default_idx;
    else
        line_index = str2double(idx_input);
    end
    fprintf('[INFO] 选择: mode=%s, line_index=%d\n', mode, line_index);
end

function mask = roi_to_mask(shape, roi_bounds)
    % 将 ROI 矩形区域转换为 bool 掩码
    % shape = [H, W]
    % roi_bounds = [r0, r1, c0, c1]（1-based）
    H = shape(1); W = shape(2);
    mask = false(H, W);
    r0 = max(1, roi_bounds(1));
    r1 = min(H, roi_bounds(2));
    c0 = max(1, roi_bounds(3));
    c1 = min(W, roi_bounds(4));
    mask(r0:r1, c0:c1) = true;
end

%% ========================================================================
%  步骤三：绝对相位计算
%  （借鉴 单频相位处理工具.py → test_multiple_frequencies2）
% ========================================================================

function wrapped_phase = calculate_wrapped_phase(stripe_images)
    % 计算单频 N 步相移数据的包裹相位
    % 输入: stripe_images — H×W×N
    % 输出: wrapped_phase — H×W，范围 [0, 2π)

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
    % 计算两个包裹相位的相位差（外差过程），范围 [0, 2π)
    p1 = phase1 / (2 * pi);
    p2 = phase2 / (2 * pi);
    result = p1 - p2;
    result(result < 0) = result(result < 0) + 1;
    result = result * (2 * pi);
end

function unwrap_phase = unwrap_phase_with_reference(reference_phase, ...
    target_phase, reference_freq, target_freq)
    % 使用参考相位展开高频相位（含去噪校正）
    % 对应 Python: unwrap_phase_with_reference（integrated_absolute_phase_tool.py 版本，含噪声校正）

    ref = reference_phase / (2 * pi);
    tar = target_phase / (2 * pi);
    temp = target_freq / reference_freq * ref;
    k = round(temp - tar);
    unwrap_val = tar + k;

    % 高斯滤波去噪校正（来源: integrated_absolute_phase_tool.py 行322~348）
    gauss_size = 3;
    unwrap_blur = imgaussfilt(unwrap_val, 0.5, 'FilterSize', gauss_size);
    ref_blur    = imgaussfilt(temp, 0.5, 'FilterSize', gauss_size);
    unwrap_noise = unwrap_val - unwrap_blur;
    ref_noise    = temp - ref_blur;

    noise_ratio = abs(unwrap_noise) ./ (abs(ref_noise) + 0.001);
    flag = (abs(unwrap_noise) - abs(ref_noise) > 0.15) & (noise_ratio > 1.5);

    if any(flag(:))
        err = unwrap_val(flag);
        d = unwrap_noise(flag);
        err(d > 0) = err(d > 0) - 1;
        err(d < 0) = err(d < 0) + 1;
        unwrap_val(flag) = err;

        % 二次校正
        unwrap_blur2 = imgaussfilt(unwrap_val, 0.5, 'FilterSize', gauss_size);
        unwrap_noise2 = unwrap_val - unwrap_blur2;
        flag2 = abs(unwrap_noise2) > 0.2;
        if any(flag2(:))
            err2 = unwrap_val(flag2);
            d2 = unwrap_noise2(flag2);
            err2(d2 > 0) = err2(d2 > 0) - 1;
            err2(d2 < 0) = err2(d2 < 0) + 1;
            unwrap_val(flag2) = err2;
        end
    end

    unwrap_phase = unwrap_val * (2 * pi);
end

function [absolute_phase, freq_comb] = compute_absolute_phase_3freq(...
    folder, phase_shift_step, orientation, freq_combination, verbose)
    % 三频改进塔形法计算绝对相位
    % 对应 Python: compute_absolute_phase_3freq
    %
    % 流程:
    %   1) 读取三个频率的 N 步相移图像
    %   2) 分别计算包裹相位
    %   3) 两两做相位差（外差）
    %   4) 逐级参考展开

    if nargin < 5, verbose = true; end

    % 自动提取频率组合
    if isempty(freq_combination)
        tokens = regexp(folder, '(\d+-\d+-\d+)', 'tokens');
        if ~isempty(tokens)
            freq_combination = tokens{1}{1};
        else
            freq_combination = 'unknown';
        end
    end
    freq_comb = freq_combination;

    parts = strsplit(freq_combination, '-');
    if length(parts) ~= 3
        error('频率组合 ''%s'' 不包含3个频率', freq_combination);
    end
    freqs = cellfun(@str2double, parts);

    if verbose
        fprintf('\n%s\n', repmat('=', 1, 60));
        fprintf('  三频改进塔形法 —— 绝对相位计算\n');
        fprintf('  文件夹:  %s\n', folder);
        fprintf('  步数:    %d\n', phase_shift_step);
        fprintf('  方向:    %s\n', orientation);
        fprintf('  频率组合: %s  ([%d, %d, %d])\n', freq_combination, freqs(1), freqs(2), freqs(3));
        fprintf('%s\n', repmat('=', 1, 60));
    end

    % 1) 读取三个频率图像
    imgs_highest = load_single_frequency_images(folder, phase_shift_step, orientation, 0);
    imgs_middle  = load_single_frequency_images(folder, phase_shift_step, orientation, 1);
    imgs_lowest  = load_single_frequency_images(folder, phase_shift_step, orientation, 2);

    % 2) 计算包裹相位
    w_highest = calculate_wrapped_phase(imgs_highest);
    w_middle  = calculate_wrapped_phase(imgs_middle);
    w_lowest  = calculate_wrapped_phase(imgs_lowest);
    if verbose, fprintf('✓ 三个频率的包裹相位计算完成\n'); end

    % 3) 外差 —— 两两做相位差
    diff1 = calculate_phase_difference(w_highest, w_middle);   % 等效频率 f1-f2
    diff2 = calculate_phase_difference(w_middle, w_lowest);    % 等效频率 f2-f3
    diff_lowest = calculate_phase_difference(diff1, diff2);    % 最低等效频率
    if verbose, fprintf('✓ 外差相位差计算完成 (diff1, diff2, diff_lowest)\n'); end

    % 4) 逐级参考展开
    f1 = freqs(1); f2 = freqs(2); f3 = freqs(3);
    eq_f1 = f1 - f2;         % diff1 的等效频率
    eq_f2 = f2 - f3;         % diff2 的等效频率
    eq_lowest = eq_f1 - eq_f2;  % 最低等效频率

    % 展开 diff1
    unwrap_diff1 = unwrap_phase_with_reference(diff_lowest, diff1, eq_lowest, eq_f1);

    % 使用展开后的 diff1 展开最高频率
    absolute_phase = unwrap_phase_with_reference(unwrap_diff1, w_highest, eq_f1, f1);

    if verbose
        fprintf('✓ 绝对相位计算完成\n');
        fprintf('  - 绝对相位范围: [%.2f, %.2f] rad\n', ...
                min(absolute_phase(:)), max(absolute_phase(:)));
    end
end

%% ========================================================================
%  步骤四：可视化
%  （借鉴 绝对相位可视化工具.py → PhaseVisualizer 类）
% ========================================================================

function idx = determine_line_index(shape, mode, position, line_index)
    % 确定要分析的行/列索引（1-based）
    H = shape(1); W = shape(2);
    if strcmp(mode, 'row'), dim = H; else, dim = W; end

    if ~isempty(line_index)
        idx = max(1, min(round(line_index), dim));
        return;
    end

    switch position
        case 'top',           idx = round(dim / 10);
        case 'bottom',        idx = round(dim * 9 / 10);
        case 'center',        idx = round(dim / 2);
        case 'quarter',       idx = round(dim / 4);
        case 'three_quarter', idx = round(dim * 3 / 4);
        otherwise,            idx = round(dim / 2);
    end
end

function phase_norm = normalize_phase_to_2pi(phase, periods)
    % 将绝对相位归一化到 [0, 2π] 范围
    max_p = max(phase(:), [], 'omitnan');
    min_p = min(phase(:), [], 'omitnan');
    if max_p <= 2 * pi && min_p >= 0
        phase_norm = phase;
    else
        phase_norm = phase / periods;
    end
end

function visualize_line_profile(phase, mask, mode, idx, save_folder, ...
    freq_combination, periods, position)
    % 可视化指定行/列的绝对相位剖面
    % 对应 Python: visualize_line_profile

    if ~isfolder(save_folder), mkdir(save_folder); end

    % 归一化到 [0, 2π]
    phase_norm = normalize_phase_to_2pi(phase, periods);

    % 应用掩码
    display_phase = phase_norm;
    if ~isempty(mask) && isequal(size(mask), size(phase_norm))
        display_phase(~mask) = NaN;
    end

    [H, W] = size(phase_norm);
    if strcmp(mode, 'row')
        line_data = display_phase(idx, :);
        pixel_pos = 1:W;
        label_x = '列索引 (pixels)';
        label_y = '相位值 (rad, 0-2π)';
        direction_text = sprintf('行 %d', idx);
    else
        line_data = display_phase(:, idx)';
        pixel_pos = 1:H;
        label_x = '行索引 (pixels)';
        label_y = '相位值 (rad, 0-2π)';
        direction_text = sprintf('列 %d', idx);
    end

    valid = line_data(~isnan(line_data));
    if ~isempty(valid)
        mean_val = mean(valid);
        std_val  = std(valid);
    else
        mean_val = 0; std_val = 0;
    end

    mask_suffix = '';
    if ~isempty(mask), mask_suffix = '（使用掩码后）'; end

    % ================================================================
    % 图 1：相位剖面曲线
    % ================================================================
    fig_c = figure('Position', [50 200 1600 600], 'Visible', 'off');
    plot(pixel_pos, line_data, 'b', 'LineWidth', 1.5);
    hold on;
    title(sprintf('绝对相位变化曲线 — %s（%s位置）%s\n频率组合: %s', ...
          direction_text, position, mask_suffix, freq_combination), ...
          'FontSize', 14);
    xlabel(label_x, 'FontSize', 12);
    ylabel(label_y, 'FontSize', 12);
    ylim([0, 2*pi]);
    grid on; set(gca, 'GridAlpha', 0.3, 'GridLineStyle', '--');

    if ~isempty(valid)
        yline(mean_val, 'r--', 'LineWidth', 1.5, ...
              'Label', sprintf('Mean=%.4f', mean_val));
    end

    % 统计信息框
    txt = sprintf('Mean=%.4f  Std=%.4f  Points=%d', mean_val, std_val, length(valid));
    text(0.02, 0.95, txt, 'Units', 'normalized', 'FontSize', 10, ...
         'VerticalAlignment', 'top', 'FontName', 'FixedWidth', ...
         'BackgroundColor', [1 1 0.8], 'EdgeColor', [0.5 0.5 0.5], 'Margin', 4);
    legend('Phase', sprintf('Mean=%.4f', mean_val), 'FontSize', 10);
    hold off;

    curve_path = fullfile(save_folder, sprintf('phase_line_%s%d_curve.png', mode, idx));
    exportgraphics(fig_c, curve_path, 'Resolution', 300);
    fprintf('[SAVE] 相位剖面曲线: %s\n', curve_path);
    close(fig_c);

    % ================================================================
    % 图 2：2D 相位伪彩色图 + 标记线
    % ================================================================
    fig_i = figure('Position', [50 100 1200 1000], 'Visible', 'off');
    imagesc(display_phase);
    colormap(viridis_colormap());
    caxis([0, 2*pi]);
    hold on;

    title(sprintf('绝对相位图像（归一化到0-2π）%s\n频率组合: %s', ...
          mask_suffix, freq_combination), 'FontSize', 14);
    xlabel('列索引 (pixels)', 'FontSize', 12);
    ylabel('行索引 (pixels)', 'FontSize', 12);
    axis image;

    if strcmp(mode, 'row')
        yline(idx, 'r--', 'LineWidth', 2, 'Label', sprintf('选择的行: %d', idx));
    else
        xline(idx, 'r--', 'LineWidth', 2, 'Label', sprintf('选择的列: %d', idx));
    end

    c = colorbar;
    c.Label.String = '相位值 (rad, 0-2π)';
    hold off;

    image_path = fullfile(save_folder, sprintf('phase_line_%s%d_image.png', mode, idx));
    exportgraphics(fig_i, image_path, 'Resolution', 300);
    fprintf('[SAVE] 相位伪彩色图: %s\n', image_path);
    close(fig_i);
end

function visualize_3d_surface(phase, mask, save_folder, freq_combination, ...
    periods, downsample_factor)
    % 生成绝对相位 3D 表面图
    % 对应 Python: visualize_3d_surface

    if ~isfolder(save_folder), mkdir(save_folder); end

    phase_norm = normalize_phase_to_2pi(phase, periods);
    display_phase = phase_norm;
    if ~isempty(mask) && isequal(size(mask), size(phase_norm))
        display_phase(~mask) = NaN;
    end

    [H, W] = size(display_phase);
    if nargin < 6 || isempty(downsample_factor)
        max_dim = max(H, W);
        if max_dim > 1000
            downsample_factor = max(1, floor(max_dim / 500));
        else
            downsample_factor = 1;
        end
    end

    if downsample_factor > 1
        phase_3d = display_phase(1:downsample_factor:end, 1:downsample_factor:end);
        x_3d = 1:downsample_factor:W;
        y_3d = 1:downsample_factor:H;
        % 确保尺寸匹配
        x_3d = x_3d(1:size(phase_3d, 2));
        y_3d = y_3d(1:size(phase_3d, 1));
    else
        phase_3d = display_phase;
        x_3d = 1:W;
        y_3d = 1:H;
    end

    [X, Y] = meshgrid(x_3d, y_3d);

    fig = figure('Position', [50 50 1200 900], 'Visible', 'off');
    surf(X, Y, phase_3d, 'EdgeColor', 'none', 'FaceAlpha', 0.9);
    colormap(viridis_colormap());
    title(sprintf('绝对相位 3D 表面图（%s）', freq_combination), ...
          'FontSize', 14);
    xlabel('X (pixels)');
    ylabel('Y (pixels)');
    zlabel('相位值 (rad, 0-2π)');
    zlim([0, 2*pi]);
    colorbar;
    view([-37.5, 30]);
    lighting gouraud;
    camlight('headlight');

    path_3d = fullfile(save_folder, sprintf('phase_3d_surface_%s.png', freq_combination));
    exportgraphics(fig, path_3d, 'Resolution', 300);
    fprintf('[SAVE] 3D 表面图: %s\n', path_3d);
    close(fig);
end

%% ========================================================================
%  主流程：整合所有步骤
% ========================================================================

function result = run_integrated_pipeline(...
    projection_folder, phase_shift_step, orientation, freq_combination, ...
    roi_background_image, roi, ...
    extract_mode, line_index, position, ...
    output_dir, generate_3d, use_interactive)
    % 整合版主流程
    % 对应 Python: run_integrated_pipeline

    fprintf('%s\n', repmat('=', 1, 70));
    fprintf('  整合版：绝对相位生成与可视化流程\n');
    fprintf('%s\n', repmat('=', 1, 70));

    % ═══════════════════════════════════════════════════════════
    % STEP 1：ROI 选择 → 掩码
    % ═══════════════════════════════════════════════════════════
    mask = [];
    roi_bounds = [];

    % 确定背景图
    if ~isempty(roi_background_image) && isfile(roi_background_image)
        bg_img = imread(roi_background_image);
        if ndims(bg_img) == 3, bg_img = rgb2gray(bg_img); end
    else
        img_ext = detect_image_extension(projection_folder, orientation, 1);
        if isempty(img_ext)
            error('在 %s 中未找到条纹图像', projection_folder);
        end
        bg_path = fullfile(projection_folder, sprintf('%s1%s', orientation, img_ext));
        bg_img = imread(bg_path);
        if ndims(bg_img) == 3, bg_img = rgb2gray(bg_img); end
    end
    [bg_h, bg_w] = size(bg_img);

    interactive_roi = false;
    if use_interactive && isempty(roi)
        fprintf('\n[STEP 1] 交互式 ROI 选择...\n');
        [roi_bounds, extract_mode, line_index] = select_roi_interactive_phase(bg_img);
        interactive_roi = true;
        fprintf('  交互结果: ROI=[%d,%d,%d,%d], mode=%s, line_index=%d\n', ...
                roi_bounds, extract_mode, line_index);
    elseif ~isempty(roi)
        fprintf('\n[STEP 1] 手动指定 ROI: [%d,%d,%d,%d]\n', roi);
        roi_bounds = [max(1, roi(1)), min(bg_h, roi(2)), ...
                      max(1, roi(3)), min(bg_w, roi(4))];
        fprintf('  ROI 边界: 行[%d:%d], 列[%d:%d]\n', ...
                roi_bounds(1), roi_bounds(2), roi_bounds(3), roi_bounds(4));
    else
        fprintf('\n[STEP 1] 未指定 ROI，使用全图（不使用掩码）。\n');
    end

    % 检查 ROI 是否为全图
    if ~isempty(roi_bounds)
        is_full = (roi_bounds(1) == 1 && roi_bounds(2) == bg_h && ...
                   roi_bounds(3) == 1 && roi_bounds(4) == bg_w);
        if is_full
            roi_bounds = [];
            fprintf('  ROI 为全图，等同于不使用掩码。\n');
        else
            ratio = (roi_bounds(2) - roi_bounds(1) + 1) * ...
                    (roi_bounds(4) - roi_bounds(3) + 1) / (bg_h * bg_w) * 100;
            fprintf('  ROI 占比: %.2f%%\n', ratio);
        end
    end

    % ═══════════════════════════════════════════════════════════
    % STEP 2：读取图像 & 计算绝对相位
    % ═══════════════════════════════════════════════════════════
    fprintf('\n[STEP 2] 读取图像并计算绝对相位...\n');
    [absolute_phase, freq_comb] = compute_absolute_phase_3freq(...
        projection_folder, phase_shift_step, orientation, freq_combination, true);

    % 生成掩码
    if ~isempty(roi_bounds)
        mask = roi_to_mask(size(absolute_phase), roi_bounds);
        mask_dir = fullfile(output_dir, 'mask');
        if ~isfolder(mask_dir), mkdir(mask_dir); end
        % 保存掩码
        mask_uint8 = uint8(mask) * 255;
        imwrite(mask_uint8, fullfile(mask_dir, 'mask.bmp'));
        save(fullfile(mask_dir, 'mask.mat'), 'mask');
        fprintf('  ROI 掩码已保存到: %s\n', mask_dir);
    end

    % 保存绝对相位
    phase_dir = fullfile(output_dir, 'phase_data');
    if ~isfolder(phase_dir), mkdir(phase_dir); end
    save(fullfile(phase_dir, sprintf('absolute_phase_%s.mat', freq_comb)), ...
         'absolute_phase');
    fprintf('  绝对相位已保存: %s\n', phase_dir);

    % ═══════════════════════════════════════════════════════════
    % STEP 3：确定分析行/列
    % ═══════════════════════════════════════════════════════════
    fprintf('\n[STEP 3] 确定分析方向和索引...\n');

    if interactive_roi && ~isempty(roi_bounds)
        % 交互模式下 line_index 是 ROI 内部索引，转换为全图绝对索引
        if strcmp(extract_mode, 'row')
            idx = roi_bounds(1) + line_index - 1;
            idx = max(1, min(idx, size(absolute_phase, 1)));
        else
            idx = roi_bounds(3) + line_index - 1;
            idx = max(1, min(idx, size(absolute_phase, 2)));
        end
    else
        idx = determine_line_index(size(absolute_phase), extract_mode, position, line_index);
    end

    if strcmp(extract_mode, 'row'), dim_name = '行'; else, dim_name = '列'; end
    fprintf('  分析方向: %s (%s)\n', dim_name, extract_mode);
    fprintf('  索引: %d\n', idx);
    if interactive_roi
        fprintf('  (来自交互式 ROI 选择)\n');
    else
        fprintf('  位置策略: %s\n', position);
    end

    % ═══════════════════════════════════════════════════════════
    % STEP 4：可视化
    % ═══════════════════════════════════════════════════════════
    parts = strsplit(freq_comb, '-');
    if length(parts) >= 1
        freq_vals = cellfun(@str2double, parts);
        highest_freq = max(freq_vals);
    else
        highest_freq = 1;
    end
    periods = double(highest_freq);

    vis_dir = fullfile(output_dir, 'visualization');

    fprintf('\n[STEP 4] 可视化（归一化周期数: %.0f）...\n', periods);
    visualize_line_profile(absolute_phase, mask, extract_mode, idx, ...
        vis_dir, freq_comb, periods, position);

    if generate_3d
        fprintf('\n[STEP 4-3D] 生成 3D 表面图...\n');
        visualize_3d_surface(absolute_phase, mask, vis_dir, freq_comb, periods);
    end

    % ═══════════════════════════════════════════════════════════
    % 完成
    % ═══════════════════════════════════════════════════════════
    fprintf('\n%s\n', repmat('=', 1, 70));
    fprintf('  ✓ 整合流程全部完成！\n');
    fprintf('  输出目录: %s\n', output_dir);
    if ~isempty(mask)
        fprintf('  - ROI 掩码:   %s\n', fullfile(output_dir, 'mask'));
    end
    fprintf('  - 相位数据:   %s\n', fullfile(output_dir, 'phase_data'));
    fprintf('  - 可视化:     %s\n', fullfile(output_dir, 'visualization'));
    fprintf('%s\n', repmat('=', 1, 70));

    % 返回结果
    result.absolute_phase = absolute_phase;
    result.mask = mask;
    result.roi_bounds = roi_bounds;
    result.freq_combination = freq_comb;
    result.line_index = idx;
    result.extract_mode = extract_mode;
    result.output_dir = output_dir;
end

%% ========================================================================
%  辅助函数：viridis 颜色映射
% ========================================================================
function cmap = viridis_colormap()
    % 生成 viridis 风格颜色映射（MATLAB 2023b+ 内置了 viridis，
    % 此处提供兼容版本供旧版本 MATLAB 使用）
    try
        cmap = viridis(256);
    catch
        % 手动近似 viridis
        n = 256;
        t = linspace(0, 1, n)';
        % 近似 viridis 的 RGB 控制点
        R = [0.267004, 0.282327, 0.253935, 0.206756, 0.163625, ...
             0.127568, 0.134692, 0.266941, 0.477504, 0.741388, 0.993248];
        G = [0.004874, 0.140926, 0.265254, 0.371758, 0.471457, ...
             0.566949, 0.658636, 0.748751, 0.821444, 0.873449, 0.906157];
        B = [0.329415, 0.457517, 0.529983, 0.553117, 0.558148, ...
             0.550556, 0.517649, 0.440573, 0.318195, 0.150164, 0.143936];
        ctrl = linspace(0, 1, length(R))';
        cmap = [interp1(ctrl, R', t), interp1(ctrl, G', t), interp1(ctrl, B', t)];
        cmap = max(0, min(1, cmap));
    end
end
