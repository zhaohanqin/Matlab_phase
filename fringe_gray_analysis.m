%% fringe_gray_analysis.m
% =========================================================================
% 条纹投影图像灰度变化分析工具（MATLAB 版）
% Fringe Projection Image Gray Value Analysis Tool
%
% 功能：
%   【单图模式】
%   1. 读取条纹投影图像（支持彩色自动转灰度）
%   2. 交互式 ROI 区域选择（鼠标框选）
%   3. 菜单选方向 + 图像上单击选行/列（可视化，无命令行输入）
%   4. 在选定 ROI 内提取灰度剖面
%   5. 所有结果图同时显示并立即保存，窗口保持开启供交互
%
%   【双图对比模式】
%   6. 指定基准图 + 待比较图，使用相同 ROI 和行/列
%   7. 三线对比曲线（基准=红, 待比较=蓝, 误差=绿[右侧独立 Y 轴]）
%   8. 所有结果图同时显示并立即保存，窗口保持开启供交互
%
% 作者: Claude (Anthropic)
% 日期: 2026-03-18（修订：2026-03-20）
% =========================================================================
clear; clc; close all;

%% ★★★ 用户可修改区域 ★★★
RUN_MODE = 'compare';   % 'single' | 'compare'

REF_IMAGE_PATH = './v10.bmp';
CMP_IMAGE_PATH = './v10.bmp';
REF_LABEL      = 'Non Highly Reflective';
CMP_LABEL      = 'Highly Reflective';

SINGLE_IMAGE_PATH = './v10.bmp';

OUTPUT_DIR      = './output';
OUTPUT_BASENAME = 'gray_profile';
EXTRACT_MODE    = 'row';
LINE_INDEX      = 300;
ROI             = [];       % [r0,r1,c0,c1] 或 [] = 全图（1-based）

% true = 可视化交互（框选ROI + 图像点击选行列）
% false = 使用上方手动参数
USE_INTERACTIVE = true;
%% ★★★ 用户可修改区域结束 ★★★

switch RUN_MODE
    case 'single'
        run_single_analysis(SINGLE_IMAGE_PATH, OUTPUT_DIR, OUTPUT_BASENAME, ...
            EXTRACT_MODE, LINE_INDEX, ROI, USE_INTERACTIVE);
    case 'compare'
        run_dual_comparison(REF_IMAGE_PATH, CMP_IMAGE_PATH, ...
            OUTPUT_DIR, OUTPUT_BASENAME, REF_LABEL, CMP_LABEL, ...
            EXTRACT_MODE, LINE_INDEX, ROI, USE_INTERACTIVE);
    otherwise
        error('RUN_MODE=''%s'' 无效', RUN_MODE);
end

%% ========================================================================
%  图像读取
% ========================================================================

function [gray_img, is_color] = load_image(image_path)
    if ~isfile(image_path), error('无法读取图像: %s', image_path); end
    raw_img = imread(image_path);
    if ndims(raw_img) == 3 && size(raw_img,3) >= 3
        is_color = true;
        gray_img = rgb2gray(raw_img);
    else
        is_color = false;
        gray_img = raw_img;
    end
    [h, w] = size(gray_img);
    if is_color
        color_tag = '彩色→灰度';
    else
        color_tag = '灰度';
    end
    fprintf('%s | %s | %d×%d\n', image_path, color_tag, w, h);
end

%% ========================================================================
%  模拟图像生成
% ========================================================================

function fringe = generate_sample_image(save_path, height, width, noise_std)
    if nargin < 2, height = 600; end
    if nargin < 3, width  = 800; end
    if nargin < 4, noise_std = 5.0; end
    [xx, yy] = meshgrid(0:width-1, 0:height-1);
    fringe = 128 + 100*cos(2*pi/40*xx + 0.3*sin(2*pi*yy/height)) ...
             + noise_std*randn(height,width);
    fringe = uint8(max(0, min(255, fringe)));
    [d,~,~] = fileparts(save_path);
    if ~isempty(d) && ~isfolder(d), mkdir(d); end
    imwrite(fringe, save_path);
    fprintf('[INFO] 已生成模拟条纹图像: %s\n', save_path);
end

function fringe = generate_highlight_image(save_path, height, width, noise_std)
    if nargin < 2, height = 600; end
    if nargin < 3, width  = 800; end
    if nargin < 4, noise_std = 5.0; end
    [xx, yy] = meshgrid(0:width-1, 0:height-1);
    fd = 128 + 100*cos(2*pi/40*xx + 0.3*sin(2*pi*yy/height)) ...
         + noise_std*randn(height,width);
    rng(42);
    for k = 1:5
        cy = randi([round(height/4), round(3*height/4)]);
        cx = randi([round(width/4),  round(3*width/4)]);
        r  = 15 + 35*rand();
        fd = fd + (80+70*rand()) * exp(-((yy-cy).^2+(xx-cx).^2)/(2*r^2));
    end
    fringe = uint8(max(0, min(255, fd)));
    [d,~,~] = fileparts(save_path);
    if ~isempty(d) && ~isfolder(d), mkdir(d); end
    imwrite(fringe, save_path);
    fprintf('[INFO] 已生成高反光模拟条纹图像: %s\n', save_path);
end

%% ========================================================================
%  ROI 与行/列选择
% ========================================================================

function [roi_bounds, mode, line_index] = select_roi_interactive(gray_img)
    % 三阶段可视化交互
    %   阶段1：drawrectangle 框选 ROI
    %   阶段2：menu 对话框选方向
    %   阶段3：在 ROI 图像上 ginput(1) 单击选行/列，立即绘出红线确认

    [h, w] = size(gray_img);
    roi_bounds = [1, h, 1, w];

    % ── 阶段1：框选 ROI ──
    fig1 = figure('Name','阶段 1/3 — 框选 ROI','NumberTitle','off');
    imshow(gray_img, []);
    title('拖拽框选 ROI，双击确认（直接关闭 = 全图）', ...
          'FontSize',12,'FontWeight','bold');
    xlabel('Column'); ylabel('Row');
    try
        rect = drawrectangle('Color','r','FaceAlpha',0.15);
        wait(rect);
        pos = rect.Position;
        c0 = max(1, round(pos(1)));
        r0 = max(1, round(pos(2)));
        c1 = min(w, round(pos(1)+pos(3)));
        r1 = min(h, round(pos(2)+pos(4)));
        if (r1-r0)>=2 && (c1-c0)>=2
            roi_bounds = [r0, r1, c0, c1];
        end
    catch
    end
    close(fig1);
    fprintf('[INFO] ROI: 行[%d:%d], 列[%d:%d]\n', ...
            roi_bounds(1),roi_bounds(2),roi_bounds(3),roi_bounds(4));

    % ── 阶段2：菜单选方向 ──
    choice = menu('请选择灰度剖面的提取方向', ...
                  '行 (Row)  — 水平剖面', ...
                  '列 (Col)  — 垂直剖面');
    mode = 'row';
    if choice == 2, mode = 'col'; end
    fprintf('[INFO] 提取方向: %s\n', mode);

    % ── 阶段3：ROI 图像上单击选位置 ──
    roi_img = gray_img(roi_bounds(1):roi_bounds(2), roi_bounds(3):roi_bounds(4));
    [rh, rw] = size(roi_img);

    if strcmp(mode,'row')
        hdr = {'请在图像上 单击一次 以选择要分析的 行 位置', ...
               '（红色水平线标记所选行，按任意键确认关闭）'};
    else
        hdr = {'请在图像上 单击一次 以选择要分析的 列 位置', ...
               '（红色垂直线标记所选列，按任意键确认关闭）'};
    end

    fig2 = figure('Name','阶段 3/3 — 点击选择分析位置','NumberTitle','off');
    imshow(roi_img, []);
    title(hdr, 'FontSize',12,'FontWeight','bold');
    xlabel('Column (pixels)'); ylabel('Row (pixels)');
    drawnow;

    [xc, yc] = ginput(1);
    hold on;
    if strcmp(mode,'row')
        line_index = max(1, min(rh, round(yc)));
        yline(line_index, 'r-', 'LineWidth', 2.5);
        title(sprintf('✔ 已选择第 %d 行（ROI内），按任意键关闭...', line_index), ...
              'FontSize',12,'FontWeight','bold','Color',[0.8 0 0]);
    else
        line_index = max(1, min(rw, round(xc)));
        xline(line_index, 'r-', 'LineWidth', 2.5);
        title(sprintf('✔ 已选择第 %d 列（ROI内），按任意键关闭...', line_index), ...
              'FontSize',12,'FontWeight','bold','Color',[0.8 0 0]);
    end
    hold off; drawnow;
    waitforbuttonpress;
    close(fig2);
    fprintf('[INFO] 最终: mode=%s, line_index=%d\n', mode, line_index);
end

function [roi_bounds, mode, line_index] = select_roi_manual(gray_img, ...
    mode_in, line_index_in, roi_in)
    [h, w] = size(gray_img);
    if isempty(roi_in)
        roi_bounds = [1, h, 1, w];
    else
        roi_bounds = [max(1,roi_in(1)), min(h,roi_in(2)), ...
                      max(1,roi_in(3)), min(w,roi_in(4))];
    end
    mode       = mode_in;
    line_index = line_index_in;
end

%% ========================================================================
%  灰度剖面提取
% ========================================================================

function [profile, pixel_pos, abs_index, stats] = extract_profile(...
    roi_img, mode, line_index, roi_offset)

    [rh, rw] = size(roi_img);
    if strcmp(mode,'row')
        idx       = max(1, min(line_index, rh));
        profile   = double(roi_img(idx,:));
        abs_index = roi_offset(1) + idx - 1;
        pixel_pos = roi_offset(2) : (roi_offset(2)+rw-1);
    else
        idx       = max(1, min(line_index, rw));
        profile   = double(roi_img(:,idx))';
        abs_index = roi_offset(2) + idx - 1;
        pixel_pos = roi_offset(1) : (roi_offset(1)+rh-1);
    end

    stats.min_val  = min(profile);
    stats.max_val  = max(profile);
    stats.mean_val = mean(profile);
    stats.std_val  = std(profile);

    dim_name = '行'; if strcmp(mode,'col'), dim_name='列'; end
    fprintf('方向: %s(%s) | 绝对索引: %d | 采样: %d点\n', ...
            dim_name, mode, abs_index, length(profile));
    fprintf('  Min=%.1f  Max=%.1f  Mean=%.1f  Std=%.1f\n', ...
            stats.min_val, stats.max_val, stats.mean_val, stats.std_val);
end

%% ========================================================================
%  可视化辅助（共用）
% ========================================================================

function annotate_image(ax, gray_img, roi_bounds, mode, abs_index, title_str)
    if nargin < 6, title_str = 'Original Image'; end
    [h, w] = size(gray_img);
    r0=roi_bounds(1); r1=roi_bounds(2); c0=roi_bounds(3); c1=roi_bounds(4);

    imshow(gray_img, [], 'Parent', ax);
    hold(ax,'on');

    if ~(r0==1 && r1==h && c0==1 && c1==w)
        rectangle(ax, 'Position',[c0,r0,c1-c0,r1-r0], ...
                  'EdgeColor',[0 1 0],'LineWidth',2,'LineStyle','--');
        text(ax, c0, r0-8, 'ROI', 'Color',[0 1 0],'FontSize',9,'FontWeight','bold');
    end

    if strcmp(mode,'row')
        yline(ax, abs_index, 'r-', 'LineWidth',2);
        ty = abs_index + h*0.02; if abs_index >= h*0.85, ty = abs_index - h*0.04; end
        text(ax, w*0.01, ty, sprintf('Row %d',abs_index), ...
             'Color','r','FontSize',9,'FontWeight','bold');
    else
        xline(ax, abs_index, 'r-', 'LineWidth',2);
        tx = abs_index + w*0.01; if abs_index >= w*0.85, tx = abs_index - w*0.08; end
        text(ax, tx, h*0.03, sprintf('Col %d',abs_index), ...
             'Color','r','FontSize',9,'FontWeight','bold');
    end
    title(ax, title_str,'FontSize',13,'FontWeight','bold');
    xlabel(ax,'Column'); ylabel(ax,'Row');
    hold(ax,'off');
end

%% ========================================================================
%  单图模式图表（显示+保存，保持开启）
% ========================================================================

function fig = plot_single_image(gray_img, roi_bounds, mode, abs_index, save_path)
    fig = figure('Position',[100 100 1000 800],'Visible','on', ...
                 'Name','原始图像标注','NumberTitle','off');
    annotate_image(axes(fig), gray_img, roi_bounds, mode, abs_index);
    drawnow;
    if ~isempty(save_path)
        ensure_dir(save_path);
        exportgraphics(fig, save_path,'Resolution',200);
        fprintf('[SAVE] 原始图像: %s\n', save_path);
    end
end

function fig = plot_single_curve(profile, pixel_pos, mode, abs_index, stats, save_path)
    fig = figure('Position',[100 100 1200 600],'Visible','on', ...
                 'Name',sprintf('灰度剖面曲线  (%s %d)', ...
                 char('Row'*strcmp(mode,'row')+'Col'*strcmp(mode,'col')), abs_index), ...
                 'NumberTitle','off');
    ax = axes(fig);
    plot(ax, pixel_pos, profile, 'Color',[0.145 0.388 0.922],'LineWidth',1.2);
    hold(ax,'on');
    yline(ax, stats.mean_val,'r--','LineWidth',1, ...
          'Label',sprintf('Mean=%.1f',stats.mean_val));

    if strcmp(mode,'row')
        title(ax, sprintf('Gray Value along Row %d',abs_index),'FontSize',13,'FontWeight','bold');
        xlabel(ax,'Column Index','FontSize',11);
    else
        title(ax, sprintf('Gray Value along Column %d',abs_index),'FontSize',13,'FontWeight','bold');
        xlabel(ax,'Row Index','FontSize',11);
    end
    ylabel(ax,'Gray Value','FontSize',11);
    ylim(ax,[-5,265]); xlim(ax,[pixel_pos(1),pixel_pos(end)]);
    grid(ax,'on'); ax.GridAlpha=0.3;
    legend(ax,'Gray Value',sprintf('Mean=%.1f',stats.mean_val), ...
           'Location','northeast','FontSize',10);
    txt = sprintf('Min=%.0f  Max=%.0f  Mean=%.1f  Std=%.1f', ...
                  stats.min_val,stats.max_val,stats.mean_val,stats.std_val);
    text(ax,0.02,0.95,txt,'Units','normalized','FontSize',9, ...
         'VerticalAlignment','top','FontName','FixedWidth', ...
         'BackgroundColor',[1 1 0.8],'EdgeColor',[0.5 0.5 0.5],'Margin',4);
    hold(ax,'off');
    drawnow;

    if ~isempty(save_path)
        ensure_dir(save_path);
        exportgraphics(fig, save_path,'Resolution',200);
        fprintf('[SAVE] 灰度曲线: %s\n', save_path);
    end
end

%% ========================================================================
%  双图模式图表（显示+保存，保持开启）
% ========================================================================

function fig = plot_dual_images(ref_gray, cmp_gray, roi_bounds, mode, ...
    abs_index, ref_label, cmp_label, save_path)
    fig = figure('Position',[50 100 1800 700],'Visible','on', ...
                 'Name','双原图标注对比','NumberTitle','off');
    ax1 = subplot(1,2,1); annotate_image(ax1, ref_gray, roi_bounds, mode, abs_index, ref_label);
    ax2 = subplot(1,2,2); annotate_image(ax2, cmp_gray, roi_bounds, mode, abs_index, cmp_label);
    drawnow;
    if ~isempty(save_path)
        ensure_dir(save_path);
        exportgraphics(fig, save_path,'Resolution',200);
        fprintf('[SAVE] 双原图标注: %s\n', save_path);
    end
end

function fig = plot_single_annotated(gray_img, roi_bounds, mode, abs_index, ...
    label_str, save_path)
    fig = figure('Position',[50 50 1920 1080],'Visible','on', ...
                 'Name',label_str,'NumberTitle','off');
    annotate_image(axes(fig), gray_img, roi_bounds, mode, abs_index, label_str);
    drawnow;
    if ~isempty(save_path)
        ensure_dir(save_path);
        set(fig,'PaperPositionMode','auto');
        print(fig, save_path,'-dpng','-r100');
        fprintf('[SAVE] 单图标注(%s): %s\n', label_str, save_path);
    end
end

function fig = plot_comparison_curve(ref_profile, cmp_profile, pixel_pos, ...
    mode, abs_index, ref_label, cmp_label, ref_stats, cmp_stats, save_path)
    err = cmp_profile - ref_profile;

    if strcmp(mode,'row')
        win_name = sprintf('对比曲线  Row %d', abs_index);
    else
        win_name = sprintf('对比曲线  Col %d', abs_index);
    end

    fig = figure('Position',[50 50 1920 1080],'Visible','on', ...
                 'Name',win_name,'NumberTitle','off');
    axL = axes(fig);

    yyaxis(axL,'left');
    l1 = plot(axL, pixel_pos, ref_profile, ...
              'Color',[0.863 0.149 0.149],'LineWidth',3.5,'DisplayName',ref_label);
    hold(axL,'on');
    l2 = plot(axL, pixel_pos, cmp_profile, ...
              'Color',[0.145 0.388 0.922],'LineWidth',1.6,'DisplayName',cmp_label);
    ylabel(axL,'Pixel Gray Value','FontSize',13,'Color','r');
    axL.YColor=[0.8 0 0]; ylim(axL,[-60,270]);

    yyaxis(axL,'right');
    l3 = plot(axL, pixel_pos, err, ...
              'Color',[0.086 0.639 0.290],'LineWidth',1.3,'DisplayName','Error (Diff)');
    emax = max(max(abs(err))*1.3, 1.0);
    ylabel(axL,'Error Value (Diff)','FontSize',13,'Color',[0 0.6 0]);
    axL.YColor=[0 0.5 0]; ylim(axL,[-emax,emax]);

    if strcmp(mode,'row')
        xlabel(axL,'Pixel Coordinates (Column)','FontSize',12);
        title(axL,sprintf('Dual-Image Comparison — Row %d',abs_index), ...
              'FontSize',15,'FontWeight','bold');
    else
        xlabel(axL,'Pixel Coordinates (Row)','FontSize',12);
        title(axL,sprintf('Dual-Image Comparison — Column %d',abs_index), ...
              'FontSize',15,'FontWeight','bold');
    end
    xlim(axL,[pixel_pos(1),pixel_pos(end)]);
    grid(axL,'on'); axL.GridAlpha=0.2;
    legend([l1,l2,l3],'Location','northeast','FontSize',12);

    rmse = sqrt(mean(err.^2)); mae = mean(abs(err));
    txt = sprintf('Ref:  Mean=%.1f, Std=%.1f\nCmp:  Mean=%.1f, Std=%.1f\nErr:  RMSE=%.1f, MAE=%.1f, |Max|=%.1f', ...
                  ref_stats.mean_val,ref_stats.std_val, ...
                  cmp_stats.mean_val,cmp_stats.std_val, ...
                  rmse,mae,max(abs(err)));
    yyaxis(axL,'left');
    text(axL,0.02,0.95,txt,'Units','normalized','FontSize',10, ...
         'VerticalAlignment','top','FontName','FixedWidth', ...
         'BackgroundColor',[1 1 0.8],'EdgeColor',[0.5 0.5 0.5],'Margin',4);
    hold(axL,'off');
    drawnow;

    if ~isempty(save_path)
        ensure_dir(save_path);
        set(fig,'PaperPositionMode','auto');
        print(fig, save_path,'-dpng','-r100');
        fprintf('[SAVE] 对比曲线: %s\n', save_path);
    end
end

function fig = plot_error_curve(err, pixel_pos, mode, abs_index, save_path)
    if strcmp(mode,'row')
        win_name = sprintf('误差分布  Row %d', abs_index);
    else
        win_name = sprintf('误差分布  Col %d', abs_index);
    end

    fig = figure('Position',[50 50 1920 1080],'Visible','on', ...
                 'Name',win_name,'NumberTitle','off');
    ax = axes(fig);
    hold(ax,'on');

    err_pos = err; err_pos(err<0) = 0;
    err_neg = err; err_neg(err>=0) = 0;
    area(ax, pixel_pos, err_pos,'FaceColor',[0.086 0.639 0.290],'FaceAlpha',0.3,'EdgeColor','none');
    area(ax, pixel_pos, err_neg,'FaceColor',[0.863 0.149 0.149],'FaceAlpha',0.3,'EdgeColor','none');
    plot(ax, pixel_pos, err,'Color',[0.086 0.639 0.290],'LineWidth',1.4,'DisplayName','Error');
    yline(ax,0,'k-','LineWidth',0.8);

    if strcmp(mode,'row')
        xlabel(ax,'Pixel Coordinates (Column)','FontSize',12);
        title(ax,sprintf('Error Distribution — Row %d',abs_index),'FontSize',15,'FontWeight','bold');
    else
        xlabel(ax,'Pixel Coordinates (Row)','FontSize',12);
        title(ax,sprintf('Error Distribution — Column %d',abs_index),'FontSize',15,'FontWeight','bold');
    end
    ylabel(ax,'Error (Comparison − Reference)','FontSize',12);
    xlim(ax,[pixel_pos(1),pixel_pos(end)]);
    grid(ax,'on'); ax.GridAlpha=0.3;
    legend(ax,'Location','northeast','FontSize',12);

    rmse = sqrt(mean(err.^2)); mae = mean(abs(err));
    txt = sprintf('RMSE=%.2f  MAE=%.2f  Max=%.1f  Min=%.1f', ...
                  rmse,mae,max(err),min(err));
    text(ax,0.02,0.95,txt,'Units','normalized','FontSize',10, ...
         'VerticalAlignment','top','FontName','FixedWidth', ...
         'BackgroundColor',[1 1 0.8],'EdgeColor',[0.5 0.5 0.5],'Margin',4);
    hold(ax,'off');
    drawnow;

    if ~isempty(save_path)
        ensure_dir(save_path);
        set(fig,'PaperPositionMode','auto');
        print(fig, save_path,'-dpng','-r100');
        fprintf('[SAVE] 误差曲线: %s\n', save_path);
    end
end

%% ========================================================================
%  数据导出
% ========================================================================

function export_single_data(profile, pixel_pos, mode, abs_index, ...
    stats, roi_bounds, img_shape, save_dir, basename)
    if ~isfolder(save_dir), mkdir(save_dir); end
    mat_path = fullfile(save_dir,[basename,'.mat']);
    save(mat_path,'profile','pixel_pos','mode','abs_index','stats','roi_bounds','img_shape');
    fprintf('[SAVE] MAT: %s\n', mat_path);
end

function export_comparison_data(ref_profile, cmp_profile, err, ...
    pixel_pos, mode, abs_index, ref_stats, cmp_stats, roi_bounds, ...
    img_shape, save_dir, basename)
    if ~isfolder(save_dir), mkdir(save_dir); end
    rmse = sqrt(mean(err.^2)); mae = mean(abs(err));
    mat_path = fullfile(save_dir,[basename,'.mat']);
    save(mat_path,'ref_profile','cmp_profile','err','pixel_pos', ...
         'mode','abs_index','ref_stats','cmp_stats','roi_bounds','img_shape','rmse','mae');
    fprintf('[SAVE] MAT: %s\n', mat_path);
end

function ensure_dir(file_path)
    [d,~,~] = fileparts(file_path);
    if ~isempty(d) && ~isfolder(d), mkdir(d); end
end

%% ========================================================================
%  单图分析主控
% ========================================================================

function run_single_analysis(image_path, output_dir, basename, ...
    extract_mode, line_index, roi, use_interactive)

    fprintf('==========================\n  单图灰度分析\n==========================\n');

    if ~isfile(image_path)
        fprintf('[WARN] 图像不存在，自动生成: %s\n', image_path);
        generate_sample_image(image_path);
    end
    [gray_img, ~] = load_image(image_path);

    if use_interactive
        [roi_bounds, mode, lidx] = select_roi_interactive(gray_img);
    else
        [roi_bounds, mode, lidx] = select_roi_manual(gray_img, extract_mode, line_index, roi);
    end

    roi_img   = gray_img(roi_bounds(1):roi_bounds(2), roi_bounds(3):roi_bounds(4));
    roi_offset= [roi_bounds(1), roi_bounds(3)];
    [profile, pixel_pos, abs_index, stats] = ...
        extract_profile(roi_img, mode, lidx, roi_offset);

    % 所有图一起生成，立即保存，不关闭
    plot_single_image(gray_img, roi_bounds, mode, abs_index, ...
        fullfile(output_dir, [basename,'_image.png']));

    plot_single_curve(profile, pixel_pos, mode, abs_index, stats, ...
        fullfile(output_dir, [basename,'_curve.png']));

    export_single_data(profile, pixel_pos, mode, abs_index, stats, ...
        roi_bounds, size(gray_img), output_dir, basename);

    fprintf('\n✔ 单图分析完成！输出目录: %s\n', output_dir);
    fprintf('✔ 所有图窗已保持开启，可自由交互查看。\n');
end

%% ========================================================================
%  双图对比主控
% ========================================================================

function run_dual_comparison(ref_path, cmp_path, output_dir, basename, ...
    ref_label, cmp_label, extract_mode, line_index, roi, use_interactive)

    fprintf('==================================================\n');
    fprintf('  条纹投影图像灰度分析 — 双图对比模式\n');
    fprintf('==================================================\n');

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
        error('尺寸不一致！%s vs %s', mat2str(size(ref_gray)), mat2str(size(cmp_gray)));
    end

    if use_interactive
        [roi_bounds, mode, lidx] = select_roi_interactive(ref_gray);
    else
        [roi_bounds, mode, lidx] = select_roi_manual(ref_gray, extract_mode, line_index, roi);
    end

    roi_offset = [roi_bounds(1), roi_bounds(3)];
    ref_roi = ref_gray(roi_bounds(1):roi_bounds(2), roi_bounds(3):roi_bounds(4));
    cmp_roi = cmp_gray(roi_bounds(1):roi_bounds(2), roi_bounds(3):roi_bounds(4));

    [ref_profile, ref_pos, ref_abs, ref_stats] = extract_profile(ref_roi, mode, lidx, roi_offset);
    [cmp_profile, ~,       ~,       cmp_stats] = extract_profile(cmp_roi, mode, lidx, roi_offset);

    err  = cmp_profile - ref_profile;
    rmse = sqrt(mean(err.^2));
    mae  = mean(abs(err));
    fprintf('\n【基准图】 %s\n【待比较】 %s\n', ref_label, cmp_label);
    fprintf('【误  差】 RMSE=%.2f, MAE=%.2f, |Max|=%.1f\n', rmse, mae, max(abs(err)));

    if ~isfolder(output_dir), mkdir(output_dir); end

    p1 = fullfile(output_dir,[basename,'_images.png']);
    p2 = fullfile(output_dir,[basename,'_compare.png']);
    p3 = fullfile(output_dir,[basename,'_error.png']);
    p4 = fullfile(output_dir,[basename,'_ref.png']);
    p5 = fullfile(output_dir,[basename,'_cmp.png']);

    % 所有图一起生成，立即保存，不关闭
    plot_dual_images(ref_gray, cmp_gray, roi_bounds, mode, ref_abs, ...
                     ref_label, cmp_label, p1);

    plot_comparison_curve(ref_profile, cmp_profile, ref_pos, mode, ref_abs, ...
                          ref_label, cmp_label, ref_stats, cmp_stats, p2);

    plot_error_curve(err, ref_pos, mode, ref_abs, p3);

    plot_single_annotated(ref_gray, roi_bounds, mode, ref_abs, ref_label, p4);
    plot_single_annotated(cmp_gray, roi_bounds, mode, ref_abs, cmp_label, p5);

    export_comparison_data(ref_profile, cmp_profile, err, ref_pos, mode, ref_abs, ...
        ref_stats, cmp_stats, roi_bounds, size(ref_gray), output_dir, basename);

    fprintf('\n✔ 对比分析完成！RMSE=%.4f, MAE=%.4f\n', rmse, mae);
    fprintf('✔ 所有图窗已保持开启，可自由交互查看（放大/平移/点击查值）。\n');
end
