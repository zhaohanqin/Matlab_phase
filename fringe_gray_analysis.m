%% fringe_gray_analysis.m
% =========================================================================
% 条纹投影图像灰度变化分析工具（MATLAB 版）
% Fringe Projection Image Gray Value Analysis Tool
%
% 功能：
%   【单图模式】
%   1. 读取条纹投影图像（支持彩色自动转灰度）
%   2. 交互式 ROI 区域选择（鼠标框选感兴趣区域）
%   3. 交互式/手动选择提取方向（行/列）及具体行列号
%   4. 在选定 ROI 内提取灰度剖面
%   5. 原始图像标注图与灰度曲线图分别独立保存
%   6. 保存结果为 PNG、MAT 格式
%
%   【双图对比模式】
%   7. 指定基准图 + 待比较图，使用相同 ROI 和行/列
%   8. 三线对比曲线（基准=红, 待比较=蓝, 误差=绿[右侧独立 Y 轴]）
%   9. 双原图并排标注 + 对比曲线图 + 误差曲线图
%   10. 多格式数据导出（PNG / MAT）
%
% 对应 Python 源文件: fringe_gray_analysis.py
% 作者: Claude (Anthropic)
% 日期: 2026-03-18
% =========================================================================
clear; clc; close all;

%% ★★★ 用户可修改区域 ★★★
% 【运行模式】 'single' = 单图分析,  'compare' = 双图对比
RUN_MODE = 'compare';

% ──── 双图对比模式参数 ────
REF_IMAGE_PATH = './v10.bmp';          % 基准正弦条纹图像路径
CMP_IMAGE_PATH = './v10.bmp';          % 待比较条纹图像路径
REF_LABEL      = 'Non Highly Reflective';  % 基准图标签
CMP_LABEL      = 'Highly Reflective';      % 待比较图标签

% ──── 单图模式参数 ────
SINGLE_IMAGE_PATH = './v10.bmp';

% ──── 共享参数 ────
OUTPUT_DIR      = './output';
OUTPUT_BASENAME = 'gray_profile';
EXTRACT_MODE    = 'row';       % 'row' 或 'col'
LINE_INDEX      = 300;         % ROI 内的行/列号（MATLAB 1-based，此处为相对 ROI）
ROI             = [];          % [r0, r1, c0, c1] 或 [] = 全图（1-based）

% 是否使用交互模式（true = 鼠标框选 ROI；false = 使用上面手动参数）
USE_INTERACTIVE = false;
%% ★★★ 用户可修改区域结束 ★★★

%% 主流程
switch RUN_MODE
    case 'single'
        run_single_analysis(SINGLE_IMAGE_PATH, OUTPUT_DIR, OUTPUT_BASENAME, ...
            EXTRACT_MODE, LINE_INDEX, ROI, USE_INTERACTIVE);
    case 'compare'
        run_dual_comparison(REF_IMAGE_PATH, CMP_IMAGE_PATH, ...
            OUTPUT_DIR, OUTPUT_BASENAME, ...
            REF_LABEL, CMP_LABEL, ...
            EXTRACT_MODE, LINE_INDEX, ROI, USE_INTERACTIVE);
    otherwise
        error('RUN_MODE=''%s'' 无效，应为 ''single'' 或 ''compare''', RUN_MODE);
end

%% ========================================================================
%                        图像读取函数
% ========================================================================
function [gray_img, is_color] = load_image(image_path)
    % 读取图像并自动转为灰度图
    % 对应 Python: ImageLoader 类
    if ~isfile(image_path)
        error('无法读取图像: %s', image_path);
    end
    raw_img = imread(image_path);
    if ndims(raw_img) == 3 && size(raw_img, 3) >= 3
        is_color = true;
        gray_img = rgb2gray(raw_img);
    else
        is_color = false;
        gray_img = raw_img;
    end
    [h, w] = size(gray_img);
    color_str = '彩色→灰度';
    if ~is_color, color_str = '灰度'; end
    fprintf('%s | %s | %d×%d\n', image_path, color_str, w, h);
end

%% ========================================================================
%                     模拟条纹图像生成函数
% ========================================================================
function fringe = generate_sample_image(save_path, height, width, noise_std)
    % 生成标准模拟条纹图像
    % 对应 Python: SampleGenerator.generate
    if nargin < 2, height = 600; end
    if nargin < 3, width = 800; end
    if nargin < 4, noise_std = 5.0; end

    [xx, yy] = meshgrid(0:width-1, 0:height-1);
    period = 40.0;
    freq = 2.0 * pi / period;
    phase_mod = 0.3 * sin(2.0 * pi * yy / height);
    fringe = 128.0 + 100.0 * cos(freq * xx + phase_mod);
    fringe = fringe + noise_std * randn(height, width);
    fringe = uint8(max(0, min(255, fringe)));

    [folder, ~, ~] = fileparts(save_path);
    if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
    imwrite(fringe, save_path);
    fprintf('[INFO] 已生成模拟条纹图像: %s\n', save_path);
end

function fringe = generate_highlight_image(save_path, height, width, noise_std)
    % 生成带高反光干扰的模拟条纹图像
    % 对应 Python: SampleGenerator.generate_highlight
    if nargin < 2, height = 600; end
    if nargin < 3, width = 800; end
    if nargin < 4, noise_std = 5.0; end

    [xx, yy] = meshgrid(0:width-1, 0:height-1);
    period = 40.0;
    freq = 2.0 * pi / period;
    phase_mod = 0.3 * sin(2.0 * pi * yy / height);
    fringe_d = 128.0 + 100.0 * cos(freq * xx + phase_mod);
    fringe_d = fringe_d + noise_std * randn(height, width);

    rng(42);
    for k = 1:5
        cy = randi([round(height/4), round(3*height/4)]);
        cx = randi([round(width/4), round(3*width/4)]);
        r = 15 + 35 * rand();
        intensity = 80 + 70 * rand();
        fringe_d = fringe_d + intensity * exp(-((yy-cy).^2 + (xx-cx).^2) / (2*r^2));
    end
    fringe = uint8(max(0, min(255, fringe_d)));

    [folder, ~, ~] = fileparts(save_path);
    if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
    imwrite(fringe, save_path);
    fprintf('[INFO] 已生成高反光模拟条纹图像: %s\n', save_path);
end

%% ========================================================================
%                     ROI 交互选择函数
% ========================================================================
function [roi_bounds, mode, line_index] = select_roi_interactive(gray_img)
    % 交互式 ROI 选择器：鼠标框选 + 手动输入行列号
    % 对应 Python: ROISelector.select_interactive
    [h, w] = size(gray_img);

    % 阶段1：鼠标框选 ROI
    fig1 = figure('Name', '阶段 1/2 — 框选 ROI', 'NumberTitle', 'off');
    imshow(gray_img, []);
    title('鼠标拖拽框选 ROI，双击确认（不框选直接关闭=全图）', ...
          'FontSize', 12, 'FontWeight', 'bold');
    xlabel('Column'); ylabel('Row');

    roi_bounds = [1, h, 1, w];  % 默认全图 [r0, r1, c0, c1]（1-based）
    try
        rect = drawrectangle('Color', 'r', 'FaceAlpha', 0.15);
        % 等待用户双击确认
        wait(rect);
        pos = rect.Position;  % [x, y, width, height]
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
    roi_img = gray_img(roi_bounds(1):roi_bounds(2), roi_bounds(3):roi_bounds(4));
    [rh, rw] = size(roi_img);

    fprintf('ROI 尺寸: %d×%d\n', rw, rh);
    mode_input = input('选择方向 (row/col) [row]: ', 's');
    if isempty(mode_input), mode_input = 'row'; end
    mode = mode_input;

    if strcmp(mode, 'row')
        default_idx = round(rh / 2);
        idx_input = input(sprintf('输入行号 (1-%d) [%d]: ', rh, default_idx), 's');
    else
        default_idx = round(rw / 2);
        idx_input = input(sprintf('输入列号 (1-%d) [%d]: ', rw, default_idx), 's');
    end
    if isempty(idx_input)
        line_index = default_idx;
    else
        line_index = str2double(idx_input);
    end
    fprintf('[INFO] 选择: mode=%s, line_index=%d\n', mode, line_index);
end

function [roi_bounds, mode, line_index] = select_roi_manual(gray_img, ...
    mode_in, line_index_in, roi_in)
    % 手动指定 ROI 和行/列参数
    % 对应 Python: ROISelector.select_manual
    [h, w] = size(gray_img);

    if isempty(roi_in)
        roi_bounds = [1, h, 1, w];  % 全图（1-based）
    else
        roi_bounds = [max(1, roi_in(1)), min(h, roi_in(2)), ...
                      max(1, roi_in(3)), min(w, roi_in(4))];
    end
    mode = mode_in;
    line_index = line_index_in;
end

%% ========================================================================
%                      灰度剖面提取函数
% ========================================================================
function [profile, pixel_pos, abs_index, stats] = extract_profile(...
    roi_img, mode, line_index, roi_offset)
    % 从 ROI 中提取一行或一列的灰度剖面及统计信息
    % 对应 Python: ProfileExtractor 类
    %
    % roi_offset = [row_offset, col_offset]（ROI 左上角在全图中的位置，1-based）

    [rh, rw] = size(roi_img);
    if strcmp(mode, 'row')
        idx = max(1, min(line_index, rh));
        profile = double(roi_img(idx, :));
        abs_index = roi_offset(1) + idx - 1;
        pixel_pos = (roi_offset(2):(roi_offset(2) + rw - 1));
    else  % col
        idx = max(1, min(line_index, rw));
        profile = double(roi_img(:, idx))';
        abs_index = roi_offset(2) + idx - 1;
        pixel_pos = (roi_offset(1):(roi_offset(1) + rh - 1));
    end

    stats.min_val  = min(profile);
    stats.max_val  = max(profile);
    stats.mean_val = mean(profile);
    stats.std_val  = std(profile);

    dim_name = '行';
    if strcmp(mode, 'col'), dim_name = '列'; end
    fprintf('方向: %s(%s) | 绝对索引: %d | 采样: %d点\n', ...
            dim_name, mode, abs_index, length(profile));
    fprintf('  Min=%.1f, Max=%.1f, Mean=%.1f, Std=%.1f\n', ...
            stats.min_val, stats.max_val, stats.mean_val, stats.std_val);
end

%% ========================================================================
%                     单图可视化函数
% ========================================================================
function annotate_image(ax, gray_img, roi_bounds, mode, abs_index, title_str)
    % 在坐标轴上绘制灰度图 + ROI 框 + 行/列标记
    % 对应 Python: ResultPlotter._annotate
    if nargin < 6, title_str = 'Original Image'; end
    [h, w] = size(gray_img);
    r0 = roi_bounds(1); r1 = roi_bounds(2);
    c0 = roi_bounds(3); c1 = roi_bounds(4);

    imshow(gray_img, [], 'Parent', ax);
    hold(ax, 'on');

    % ROI 框
    if ~(r0 == 1 && r1 == h && c0 == 1 && c1 == w)
        rectangle(ax, 'Position', [c0, r0, c1-c0, r1-r0], ...
                  'EdgeColor', [0 1 0], 'LineWidth', 2, 'LineStyle', '--');
        text(ax, c0, r0-8, 'ROI', 'Color', [0 1 0], 'FontSize', 9, 'FontWeight', 'bold');
    end

    % 行/列标记
    if strcmp(mode, 'row')
        yline(ax, abs_index, 'r-', 'LineWidth', 2);
        if abs_index < h * 0.85
            ty = abs_index + h * 0.02;
        else
            ty = abs_index - h * 0.04;
        end
        text(ax, w * 0.01, ty, sprintf('Row %d', abs_index), ...
             'Color', 'r', 'FontSize', 9, 'FontWeight', 'bold');
    else
        xline(ax, abs_index, 'r-', 'LineWidth', 2);
        if abs_index < w * 0.85
            tx = abs_index + w * 0.01;
        else
            tx = abs_index - w * 0.08;
        end
        text(ax, tx, h * 0.03, sprintf('Col %d', abs_index), ...
             'Color', 'r', 'FontSize', 9, 'FontWeight', 'bold');
    end
    title(ax, title_str, 'FontSize', 13, 'FontWeight', 'bold');
    xlabel(ax, 'Column'); ylabel(ax, 'Row');
    hold(ax, 'off');
end

function fig = plot_single_image(gray_img, roi_bounds, mode, abs_index, save_path)
    % 生成原始图像标注图
    % 对应 Python: ResultPlotter.plot_image
    fig = figure('Position', [100 100 1000 800], 'Visible', 'off');
    ax = axes(fig);
    annotate_image(ax, gray_img, roi_bounds, mode, abs_index);
    if ~isempty(save_path)
        [folder, ~, ~] = fileparts(save_path);
        if ~isfolder(folder), mkdir(folder); end
        exportgraphics(fig, save_path, 'Resolution', 200);
        fprintf('[SAVE] 原始图像: %s\n', save_path);
    end
end

function fig = plot_single_curve(profile, pixel_pos, mode, abs_index, stats, save_path)
    % 生成灰度曲线图
    % 对应 Python: ResultPlotter.plot_curve
    fig = figure('Position', [100 100 1200 600], 'Visible', 'off');
    ax = axes(fig);
    plot(ax, pixel_pos, profile, 'Color', [0.145 0.388 0.922], 'LineWidth', 1.2);
    hold(ax, 'on');
    yline(ax, stats.mean_val, 'r--', 'LineWidth', 1, ...
          'Label', sprintf('Mean=%.1f', stats.mean_val));

    if strcmp(mode, 'row')
        title(ax, sprintf('Gray Value along Row %d', abs_index), ...
              'FontSize', 13, 'FontWeight', 'bold');
        xlabel(ax, 'Column Index', 'FontSize', 11);
    else
        title(ax, sprintf('Gray Value along Column %d', abs_index), ...
              'FontSize', 13, 'FontWeight', 'bold');
        xlabel(ax, 'Row Index', 'FontSize', 11);
    end
    ylabel(ax, 'Gray Value', 'FontSize', 11);
    ylim(ax, [-5, 265]);
    xlim(ax, [pixel_pos(1), pixel_pos(end)]);
    grid(ax, 'on'); ax.GridAlpha = 0.3;
    legend(ax, 'Gray Value', sprintf('Mean=%.1f', stats.mean_val), ...
           'Location', 'northeast', 'FontSize', 10);

    % 统计信息框
    txt = sprintf('Min=%.0f Max=%.0f Mean=%.1f Std=%.1f', ...
                  stats.min_val, stats.max_val, stats.mean_val, stats.std_val);
    text(ax, 0.02, 0.95, txt, 'Units', 'normalized', 'FontSize', 9, ...
         'VerticalAlignment', 'top', 'FontName', 'FixedWidth', ...
         'BackgroundColor', [1 1 0.8], 'EdgeColor', [0.5 0.5 0.5], ...
         'Margin', 4);
    hold(ax, 'off');

    if ~isempty(save_path)
        [folder, ~, ~] = fileparts(save_path);
        if ~isfolder(folder), mkdir(folder); end
        exportgraphics(fig, save_path, 'Resolution', 200);
        fprintf('[SAVE] 灰度曲线: %s\n', save_path);
    end
end

%% ========================================================================
%                     双图对比可视化函数
% ========================================================================
function fig = plot_dual_images(ref_gray, cmp_gray, roi_bounds, mode, ...
    abs_index, ref_label, cmp_label, save_path)
    % 图1：两张原图并排标注
    % 对应 Python: ComparisonPlotter.plot_dual_images
    fig = figure('Position', [50 100 1800 700], 'Visible', 'off');
    ax1 = subplot(1, 2, 1);
    annotate_image(ax1, ref_gray, roi_bounds, mode, abs_index, ref_label);
    ax2 = subplot(1, 2, 2);
    annotate_image(ax2, cmp_gray, roi_bounds, mode, abs_index, cmp_label);
    if ~isempty(save_path)
        [folder, ~, ~] = fileparts(save_path);
        if ~isfolder(folder), mkdir(folder); end
        exportgraphics(fig, save_path, 'Resolution', 200);
        fprintf('[SAVE] 双原图标注: %s\n', save_path);
    end
end

function fig = plot_single_annotated(gray_img, roi_bounds, mode, abs_index, ...
    label_str, save_path)
    % 生成单张原图标注图（1920×1080）
    % 对应 Python: ComparisonPlotter.plot_single_annotated
    fig = figure('Position', [50 50 1920 1080], 'Visible', 'off');
    ax = axes(fig);
    annotate_image(ax, gray_img, roi_bounds, mode, abs_index, label_str);
    if ~isempty(save_path)
        [folder, ~, ~] = fileparts(save_path);
        if ~isfolder(folder), mkdir(folder); end
        set(fig, 'PaperPositionMode', 'auto');
        print(fig, save_path, '-dpng', '-r100');
        fprintf('[SAVE] 单图标注(%s): %s (1920×1080)\n', label_str, save_path);
    end
end

function fig = plot_comparison_curve(ref_profile, cmp_profile, pixel_pos, ...
    mode, abs_index, ref_label, cmp_label, ref_stats, cmp_stats, save_path)
    % 图2：三线对比曲线（双 Y 轴）
    % 对应 Python: ComparisonPlotter.plot_comparison_curve
    err = cmp_profile - ref_profile;

    fig = figure('Position', [50 50 1920 1080], 'Visible', 'off');
    axL = axes(fig);

    % 左 Y 轴：灰度值
    yyaxis(axL, 'left');
    l1 = plot(axL, pixel_pos, ref_profile, 'Color', [0.863 0.149 0.149], ...
              'LineWidth', 3.5, 'DisplayName', ref_label);
    hold(axL, 'on');
    l2 = plot(axL, pixel_pos, cmp_profile, 'Color', [0.145 0.388 0.922], ...
              'LineWidth', 1.6, 'DisplayName', cmp_label);
    ylabel(axL, 'Pixel Gray Value', 'FontSize', 13, 'Color', 'r');
    axL.YColor = [0.8 0 0];
    ylim(axL, [-60, 270]);

    % 右 Y 轴：误差
    yyaxis(axL, 'right');
    l3 = plot(axL, pixel_pos, err, 'Color', [0.086 0.639 0.290], ...
              'LineWidth', 1.3, 'DisplayName', 'Error (Diff)');
    emax = max(max(abs(err)) * 1.3, 1.0);
    ylabel(axL, 'Error Value (Diff)', 'FontSize', 13, 'Color', [0 0.6 0]);
    axL.YColor = [0 0.5 0];
    ylim(axL, [-emax, emax]);

    % 标题和坐标轴
    if strcmp(mode, 'row')
        xlabel(axL, 'Pixel Coordinates (Column)', 'FontSize', 12);
        title(axL, sprintf('Dual-Image Comparison — Row %d', abs_index), ...
              'FontSize', 15, 'FontWeight', 'bold');
    else
        xlabel(axL, 'Pixel Coordinates (Row)', 'FontSize', 12);
        title(axL, sprintf('Dual-Image Comparison — Column %d', abs_index), ...
              'FontSize', 15, 'FontWeight', 'bold');
    end
    xlim(axL, [pixel_pos(1), pixel_pos(end)]);
    grid(axL, 'on'); axL.GridAlpha = 0.2;

    legend([l1, l2, l3], 'Location', 'northeast', 'FontSize', 12);

    % 统计信息框
    rmse = sqrt(mean(err.^2));
    mae = mean(abs(err));
    txt = sprintf('Ref:  Mean=%.1f, Std=%.1f\nCmp:  Mean=%.1f, Std=%.1f\nErr:  RMSE=%.1f, MAE=%.1f, |Max|=%.1f', ...
                  ref_stats.mean_val, ref_stats.std_val, ...
                  cmp_stats.mean_val, cmp_stats.std_val, ...
                  rmse, mae, max(abs(err)));
    yyaxis(axL, 'left');
    text(axL, 0.02, 0.95, txt, 'Units', 'normalized', 'FontSize', 10, ...
         'VerticalAlignment', 'top', 'FontName', 'FixedWidth', ...
         'BackgroundColor', [1 1 0.8], 'EdgeColor', [0.5 0.5 0.5], 'Margin', 4);
    hold(axL, 'off');

    if ~isempty(save_path)
        [folder, ~, ~] = fileparts(save_path);
        if ~isfolder(folder), mkdir(folder); end
        set(fig, 'PaperPositionMode', 'auto');
        print(fig, save_path, '-dpng', '-r100');
        fprintf('[SAVE] 对比曲线: %s (1920×1080)\n', save_path);
    end
end

function fig = plot_error_curve(err, pixel_pos, mode, abs_index, save_path)
    % 图3：单独误差分布图
    % 对应 Python: ComparisonPlotter.plot_error_curve
    fig = figure('Position', [50 50 1920 1080], 'Visible', 'off');
    ax = axes(fig);

    % 正值区域填充绿色，负值区域填充红色
    hold(ax, 'on');
    pos_idx = err >= 0;
    neg_idx = err < 0;
    err_pos = err; err_pos(neg_idx) = 0;
    err_neg = err; err_neg(pos_idx) = 0;
    area(ax, pixel_pos, err_pos, 'FaceColor', [0.086 0.639 0.290], ...
         'FaceAlpha', 0.3, 'EdgeColor', 'none');
    area(ax, pixel_pos, err_neg, 'FaceColor', [0.863 0.149 0.149], ...
         'FaceAlpha', 0.3, 'EdgeColor', 'none');
    plot(ax, pixel_pos, err, 'Color', [0.086 0.639 0.290], ...
         'LineWidth', 1.4, 'DisplayName', 'Error');
    yline(ax, 0, 'k-', 'LineWidth', 0.8);

    if strcmp(mode, 'row')
        xlabel(ax, 'Pixel Coordinates (Column)', 'FontSize', 12);
        title(ax, sprintf('Error Distribution — Row %d', abs_index), ...
              'FontSize', 15, 'FontWeight', 'bold');
    else
        xlabel(ax, 'Pixel Coordinates (Row)', 'FontSize', 12);
        title(ax, sprintf('Error Distribution — Column %d', abs_index), ...
              'FontSize', 15, 'FontWeight', 'bold');
    end
    ylabel(ax, 'Error (Comparison − Reference)', 'FontSize', 12);
    xlim(ax, [pixel_pos(1), pixel_pos(end)]);
    grid(ax, 'on'); ax.GridAlpha = 0.3;
    legend(ax, 'Location', 'northeast', 'FontSize', 12);

    rmse = sqrt(mean(err.^2));
    mae = mean(abs(err));
    txt = sprintf('RMSE=%.2f  MAE=%.2f  Max=%.1f  Min=%.1f', ...
                  rmse, mae, max(err), min(err));
    text(ax, 0.02, 0.95, txt, 'Units', 'normalized', 'FontSize', 10, ...
         'VerticalAlignment', 'top', 'FontName', 'FixedWidth', ...
         'BackgroundColor', [1 1 0.8], 'EdgeColor', [0.5 0.5 0.5], 'Margin', 4);
    hold(ax, 'off');

    if ~isempty(save_path)
        [folder, ~, ~] = fileparts(save_path);
        if ~isfolder(folder), mkdir(folder); end
        set(fig, 'PaperPositionMode', 'auto');
        print(fig, save_path, '-dpng', '-r100');
        fprintf('[SAVE] 误差曲线: %s (1920×1080)\n', save_path);
    end
end

%% ========================================================================
%                        数据导出函数
% ========================================================================
function export_single_data(profile, pixel_pos, mode, abs_index, ...
    stats, roi_bounds, img_shape, save_dir, basename)
    % 单图数据导出
    % 对应 Python: DataExporter.export_mat_single

    if ~isfolder(save_dir), mkdir(save_dir); end
    mat_path = fullfile(save_dir, [basename, '.mat']);
    save(mat_path, 'profile', 'pixel_pos', 'mode', 'abs_index', ...
         'stats', 'roi_bounds', 'img_shape');
    fprintf('[SAVE] MAT: %s\n', mat_path);
end

function export_comparison_data(ref_profile, cmp_profile, err, ...
    pixel_pos, mode, abs_index, ref_stats, cmp_stats, roi_bounds, ...
    img_shape, save_dir, basename)
    % 双图对比数据导出
    % 对应 Python: DataExporter.export_mat_comparison

    if ~isfolder(save_dir), mkdir(save_dir); end

    rmse = sqrt(mean(err.^2));
    mae = mean(abs(err));
    mat_path = fullfile(save_dir, [basename, '.mat']);
    save(mat_path, 'ref_profile', 'cmp_profile', 'err', 'pixel_pos', ...
         'mode', 'abs_index', 'ref_stats', 'cmp_stats', ...
         'roi_bounds', 'img_shape', 'rmse', 'mae');
    fprintf('[SAVE] MAT: %s\n', mat_path);
end

%% ========================================================================
%                      单图分析主控函数
% ========================================================================
function run_single_analysis(image_path, output_dir, basename, ...
    extract_mode, line_index, roi, use_interactive)
    % 对应 Python: FringeAnalyzer 类
    fprintf('==============================================================\n');
    fprintf('  单图灰度分析\n');
    fprintf('==============================================================\n');

    if ~isfile(image_path)
        fprintf('[WARN] 图像不存在，自动生成: %s\n', image_path);
        generate_sample_image(image_path);
    end
    [gray_img, ~] = load_image(image_path);

    if use_interactive
        [roi_bounds, mode, lidx] = select_roi_interactive(gray_img);
    else
        [roi_bounds, mode, lidx] = select_roi_manual(gray_img, ...
            extract_mode, line_index, roi);
    end

    roi_img = gray_img(roi_bounds(1):roi_bounds(2), roi_bounds(3):roi_bounds(4));
    roi_offset = [roi_bounds(1), roi_bounds(3)];
    [profile, pixel_pos, abs_index, stats] = extract_profile(...
        roi_img, mode, lidx, roi_offset);

    % 可视化
    fig1 = plot_single_image(gray_img, roi_bounds, mode, abs_index, ...
        fullfile(output_dir, [basename, '_image.png']));
    close(fig1);

    fig2 = plot_single_curve(profile, pixel_pos, mode, abs_index, stats, ...
        fullfile(output_dir, [basename, '_curve.png']));
    close(fig2);

    % 数据导出
    export_single_data(profile, pixel_pos, mode, abs_index, stats, ...
        roi_bounds, size(gray_img), output_dir, basename);

    fprintf('\n单图分析完成！输出目录: %s\n', output_dir);
end

%% ========================================================================
%                      双图对比主控函数
% ========================================================================
function run_dual_comparison(ref_path, cmp_path, output_dir, basename, ...
    ref_label, cmp_label, extract_mode, line_index, roi, use_interactive)
    % 对应 Python: DualImageComparator 类
    fprintf('==============================================================\n');
    fprintf('  条纹投影图像灰度分析 — 双图对比模式\n');
    fprintf('  Dual-Image Comparison\n');
    fprintf('==============================================================\n');

    if ~isfile(ref_path)
        fprintf('[WARN] 基准图不存在，自动生成: %s\n', ref_path);
        generate_sample_image(ref_path);
    end
    if ~isfile(cmp_path)
        fprintf('[WARN] 待比较图不存在，自动生成高反光版: %s\n', cmp_path);
        generate_highlight_image(cmp_path);
    end

    [ref_gray, ~] = load_image(ref_path);
    [cmp_gray, ~] = load_image(cmp_path);

    if ~isequal(size(ref_gray), size(cmp_gray))
        error('尺寸不一致! %s vs %s', mat2str(size(ref_gray)), mat2str(size(cmp_gray)));
    end

    if use_interactive
        [roi_bounds, mode, lidx] = select_roi_interactive(ref_gray);
    else
        [roi_bounds, mode, lidx] = select_roi_manual(ref_gray, ...
            extract_mode, line_index, roi);
    end

    roi_offset = [roi_bounds(1), roi_bounds(3)];
    ref_roi = ref_gray(roi_bounds(1):roi_bounds(2), roi_bounds(3):roi_bounds(4));
    cmp_roi = cmp_gray(roi_bounds(1):roi_bounds(2), roi_bounds(3):roi_bounds(4));

    [ref_profile, ref_pos, ref_abs, ref_stats] = extract_profile(ref_roi, mode, lidx, roi_offset);
    [cmp_profile, cmp_pos, cmp_abs, cmp_stats] = extract_profile(cmp_roi, mode, lidx, roi_offset);

    err = cmp_profile - ref_profile;
    rmse = sqrt(mean(err.^2));
    mae = mean(abs(err));
    fprintf('\n【基准图】 %s\n', ref_label);
    fprintf('【待比较】 %s\n', cmp_label);
    fprintf('【误  差】 RMSE=%.2f, MAE=%.2f, |Max|=%.1f\n', rmse, mae, max(abs(err)));

    if ~isfolder(output_dir), mkdir(output_dir); end

    % 可视化
    p1 = fullfile(output_dir, [basename, '_images.png']);
    p2 = fullfile(output_dir, [basename, '_compare.png']);
    p3 = fullfile(output_dir, [basename, '_error.png']);
    p4 = fullfile(output_dir, [basename, '_ref.png']);
    p5 = fullfile(output_dir, [basename, '_cmp.png']);

    fig1 = plot_dual_images(ref_gray, cmp_gray, roi_bounds, mode, ...
        ref_abs, ref_label, cmp_label, p1);
    close(fig1);

    fig2 = plot_comparison_curve(ref_profile, cmp_profile, ref_pos, ...
        mode, ref_abs, ref_label, cmp_label, ref_stats, cmp_stats, p2);
    close(fig2);

    fig3 = plot_error_curve(err, ref_pos, mode, ref_abs, p3);
    close(fig3);

    fig4 = plot_single_annotated(ref_gray, roi_bounds, mode, ref_abs, ref_label, p4);
    close(fig4);

    fig5 = plot_single_annotated(cmp_gray, roi_bounds, mode, ref_abs, cmp_label, p5);
    close(fig5);

    % 数据导出
    export_comparison_data(ref_profile, cmp_profile, err, ref_pos, ...
        mode, ref_abs, ref_stats, cmp_stats, roi_bounds, ...
        size(ref_gray), output_dir, basename);

    fprintf('\n-------------------------------------------------------\n');
    fprintf('  对比分析完成！输出文件：\n');
    fprintf('    双原图标注 : %s\n', p1);
    fprintf('    基准图单独 : %s\n', p4);
    fprintf('    比较图单独 : %s\n', p5);
    fprintf('    对比曲线   : %s\n', p2);
    fprintf('    误差分布   : %s\n', p3);
    fprintf('    数据 MAT   : %s\n', fullfile(output_dir, [basename, '.mat']));
    fprintf('-------------------------------------------------------\n');
    fprintf('  误差: RMSE=%.4f, MAE=%.4f\n', rmse, mae);
    fprintf('==============================================================\n');
end
