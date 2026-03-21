%% integrated_absolute_phase_tool.m
% =========================================================================
% 整合版：绝对相位生成与可视化工具（MATLAB 版）
% Integrated Absolute Phase Generation & Visualization Tool
%
% 整合思路：
%   ① 参考 fringe_gray_analysis.m —— 确定掩码（ROI）、选择要分析的行或列
%   ② 参考 three_frequency_phase_visualization.m —— 读图 + 相位计算
%   ③ 三频改进塔形法 —— 生成绝对相位
%   ④ 所有可视化结果同时显示并立即保存，窗口保持开启供自由交互
%
% 作者: Claude (Anthropic)
% 日期: 2026-03-18（修订：2026-03-20）
% =========================================================================
clear; clc; close all;

%% ╔════════════════════════════════════════════════════════════════╗
%  ║                    ★★★ 用户参数区 ★★★                       ║
%  ╚════════════════════════════════════════════════════════════════╝

PROJECTION_FOLDER = 'H:\images\PSM_FSM\O2';
PHASE_SHIFT_STEP  = 4;
ORIENTATION       = 'v';
FREQ_COMBINATION  = '81-72-64';

ROI_BACKGROUND_IMAGE = '';
ROI = [];

EXTRACT_MODE = 'row';
LINE_INDEX   = [];
POSITION     = 'center';

OUTPUT_DIR   = './integrated_results';
GENERATE_3D  = true;

USE_INTERACTIVE = true;

%% ╔════════════════════════════════════════════════════════════════╗
%  ║                        程序入口                               ║
%  ╚════════════════════════════════════════════════════════════════╝

result = run_integrated_pipeline(...
    PROJECTION_FOLDER, PHASE_SHIFT_STEP, ORIENTATION, FREQ_COMBINATION, ...
    ROI_BACKGROUND_IMAGE, ROI, ...
    EXTRACT_MODE, LINE_INDEX, POSITION, ...
    OUTPUT_DIR, GENERATE_3D, USE_INTERACTIVE);

%% ========================================================================
%  Step 1：图像读取
% ========================================================================

function ext = detect_image_extension(folder_path, orientation, index)
    exts = {'.bmp','.png','.jpg','.jpeg'};
    ext = '';
    for k = 1:length(exts)
        if isfile(fullfile(folder_path, sprintf('%s%d%s',orientation,index,exts{k})))
            ext = exts{k}; return;
        end
    end
end

function num_freqs = detect_num_frequencies(folder_path, phase_shift_step, ...
    orientation, image_ext, verbose)
    if nargin < 5, verbose = true; end
    if isempty(image_ext)
        image_ext = detect_image_extension(folder_path, orientation, 1);
        if isempty(image_ext)
            error('在 %s 中未找到以 %s1 开头的图像文件', folder_path, orientation);
        end
    end
    count = 0; idx = 1;
    while isfile(fullfile(folder_path, sprintf('%s%d%s',orientation,idx,image_ext)))
        count = count + 1; idx = idx + 1;
    end
    if count == 0, error('未找到图像'); end
    if mod(count, phase_shift_step) ~= 0
        error('图像数量 %d 不能被步数 %d 整除', count, phase_shift_step);
    end
    num_freqs = count / phase_shift_step;
    if verbose
        fprintf('检测到 %s 方向共 %d 个频率段，每频率 %d 步。\n', ...
                upper(orientation), num_freqs, phase_shift_step);
    end
end

function images = load_single_frequency_images(folder_path, phase_shift_step, ...
    orientation, frequency_index, num_frequencies, image_ext)

    if nargin < 6 || isempty(image_ext)
        image_ext = detect_image_extension(folder_path, orientation, 1);
        if isempty(image_ext)
            error('在 %s 中未找到图像文件', folder_path);
        end
    end
    N = phase_shift_step;
    if nargin < 5 || isempty(num_frequencies)
        num_frequencies = detect_num_frequencies(folder_path, N, orientation, image_ext, false);
    end
    if frequency_index < 0 || frequency_index >= num_frequencies
        error('frequency_index=%d 超出范围 0~%d', frequency_index, num_frequencies-1);
    end

    start_idx = frequency_index * N + 1;
    first_path = fullfile(folder_path, sprintf('%s%d%s',orientation,start_idx,image_ext));
    first_img = imread(first_path);
    if ndims(first_img)==3, first_img=rgb2gray(first_img); end
    [H,W] = size(first_img);

    images = zeros(H,W,N,'uint8');
    images(:,:,1) = first_img;
    for i = 2:N
        img = imread(fullfile(folder_path, sprintf('%s%d%s',orientation,start_idx+i-1,image_ext)));
        if ndims(img)==3, img=rgb2gray(img); end
        images(:,:,i) = img;
    end
end

%% ========================================================================
%  Step 2：ROI 选择 & 掩码生成
% ========================================================================

function [roi_bounds, mode, line_index] = select_roi_interactive_phase(bg_img)
    % 三阶段可视化交互
    %   阶段1：drawrectangle 框选 ROI
    %   阶段2：menu 对话框选提取方向
    %   阶段3：在 ROI 图像上 ginput(1) 单击选行/列，绘红线确认

    [h, w] = size(bg_img);
    roi_bounds = [1, h, 1, w];

    % ── 阶段1：框选 ROI ──
    fig1 = figure('Name','阶段 1/3 — 框选 ROI','NumberTitle','off');
    imshow(bg_img,[]);
    title('拖拽框选 ROI，双击确认（直接关闭 = 全图）', ...
          'FontSize',12,'FontWeight','bold');
    try
        rect = drawrectangle('Color','r','FaceAlpha',0.15);
        wait(rect);
        pos = rect.Position;
        c0=max(1,round(pos(1))); r0=max(1,round(pos(2)));
        c1=min(w,round(pos(1)+pos(3))); r1=min(h,round(pos(2)+pos(4)));
        if (r1-r0)>=2 && (c1-c0)>=2
            roi_bounds = [r0,r1,c0,c1];
        end
    catch
    end
    close(fig1);
    fprintf('[INFO] ROI: 行[%d:%d], 列[%d:%d]\n', roi_bounds(1),roi_bounds(2),roi_bounds(3),roi_bounds(4));

    % ── 阶段2：菜单选方向 ──
    choice = menu('请选择相位剖面的提取方向', ...
                  '行 (Row)  — 水平剖面', ...
                  '列 (Col)  — 垂直剖面');
    mode = 'row';
    if choice == 2, mode = 'col'; end
    fprintf('[INFO] 提取方向: %s\n', mode);

    % ── 阶段3：ROI 图像上单击选位置 ──
    roi_img = bg_img(roi_bounds(1):roi_bounds(2), roi_bounds(3):roi_bounds(4));
    [rh, rw] = size(roi_img);

    if strcmp(mode,'row')
        hdr = {'请在图像上 单击一次 以选择要分析的 行 位置', ...
               '（红色水平线标记所选行，按任意键确认关闭）'};
    else
        hdr = {'请在图像上 单击一次 以选择要分析的 列 位置', ...
               '（红色垂直线标记所选列，按任意键确认关闭）'};
    end

    fig2 = figure('Name','阶段 3/3 — 点击选择分析位置','NumberTitle','off');
    imshow(roi_img,[]);
    title(hdr,'FontSize',12,'FontWeight','bold');
    xlabel('Column (pixels)'); ylabel('Row (pixels)');
    drawnow;

    [xc, yc] = ginput(1);
    hold on;
    if strcmp(mode,'row')
        line_index = max(1, min(rh, round(yc)));
        yline(line_index,'r-','LineWidth',2.5);
        title(sprintf('✔ 已选择第 %d 行（ROI内），按任意键关闭...', line_index), ...
              'FontSize',12,'FontWeight','bold','Color',[0.8 0 0]);
    else
        line_index = max(1, min(rw, round(xc)));
        xline(line_index,'r-','LineWidth',2.5);
        title(sprintf('✔ 已选择第 %d 列（ROI内），按任意键关闭...', line_index), ...
              'FontSize',12,'FontWeight','bold','Color',[0.8 0 0]);
    end
    hold off; drawnow;
    waitforbuttonpress;
    close(fig2);
    fprintf('[INFO] 最终: mode=%s, line_index=%d\n', mode, line_index);
end

function mask = roi_to_mask(shape, roi_bounds)
    H=shape(1); W=shape(2);
    mask = false(H,W);
    mask(max(1,roi_bounds(1)):min(H,roi_bounds(2)), ...
         max(1,roi_bounds(3)):min(W,roi_bounds(4))) = true;
end

%% ========================================================================
%  Step 3：绝对相位计算
% ========================================================================

function wrapped_phase = calculate_wrapped_phase(stripe_images)
    [H,W,N] = size(stripe_images);
    imgs = double(stripe_images);
    ps = 2*pi*(0:N-1)/N;
    cs = zeros(H,W); ss = zeros(H,W);
    for i = 1:N
        cs = cs + imgs(:,:,i)*cos(ps(i));
        ss = ss + imgs(:,:,i)*sin(ps(i));
    end
    wrapped_phase = mod(-atan2(ss,cs), 2*pi);
end

function result = calculate_phase_difference(phase1, phase2)
    result = phase1/(2*pi) - phase2/(2*pi);
    result(result<0) = result(result<0)+1;
    result = result*(2*pi);
end

function unwrap_phase = unwrap_phase_with_reference(reference_phase, ...
    target_phase, reference_freq, target_freq)
    % 含高斯滤波去噪校正

    ref = reference_phase/(2*pi);
    tar = target_phase/(2*pi);
    temp = target_freq/reference_freq*ref;
    k = round(temp-tar);
    uv = tar+k;

    gs = 3;
    ub = imgaussfilt(uv, 0.5,'FilterSize',gs);
    rb = imgaussfilt(temp,0.5,'FilterSize',gs);
    un = uv-ub; rn = temp-rb;
    nr = abs(un)./(abs(rn)+0.001);
    flag = (abs(un)-abs(rn)>0.15)&(nr>1.5);

    if any(flag(:))
        e=uv(flag); d=un(flag);
        e(d>0)=e(d>0)-1; e(d<0)=e(d<0)+1;
        uv(flag)=e;
        ub2=imgaussfilt(uv,0.5,'FilterSize',gs);
        un2=uv-ub2; f2=abs(un2)>0.2;
        if any(f2(:))
            e2=uv(f2); d2=un2(f2);
            e2(d2>0)=e2(d2>0)-1; e2(d2<0)=e2(d2<0)+1;
            uv(f2)=e2;
        end
    end
    unwrap_phase = uv*(2*pi);
end

function [absolute_phase, freq_comb] = compute_absolute_phase_3freq(...
    folder, phase_shift_step, orientation, freq_combination, verbose)

    if nargin<5, verbose=true; end

    if isempty(freq_combination)
        tokens = regexp(folder,'(\d+-\d+-\d+)','tokens');
        freq_combination = 'unknown';
        if ~isempty(tokens), freq_combination = tokens{1}{1}; end
    end
    freq_comb = freq_combination;

    parts = strsplit(freq_combination,'-');
    if length(parts)~=3, error('频率组合应含3个频率：%s',freq_combination); end
    freqs = cellfun(@str2double, parts);

    if verbose
        fprintf('\n%s\n  三频改进塔形法 —— 绝对相位计算\n', repmat('=',1,55));
        fprintf('  文件夹: %s\n  频率组合: %s  [%d, %d, %d]\n%s\n', ...
                folder, freq_combination, freqs(1),freqs(2),freqs(3), repmat('=',1,55));
    end

    imgs_h = load_single_frequency_images(folder, phase_shift_step, orientation, 0);
    imgs_m = load_single_frequency_images(folder, phase_shift_step, orientation, 1);
    imgs_l = load_single_frequency_images(folder, phase_shift_step, orientation, 2);

    wh = calculate_wrapped_phase(imgs_h);
    wm = calculate_wrapped_phase(imgs_m);
    wl = calculate_wrapped_phase(imgs_l);
    if verbose, fprintf('✓ 包裹相位计算完成\n'); end

    d1  = calculate_phase_difference(wh,wm);
    d2  = calculate_phase_difference(wm,wl);
    dl  = calculate_phase_difference(d1,d2);

    f1=freqs(1); f2=freqs(2); f3=freqs(3);
    ef1=f1-f2; ef2=f2-f3; efl=ef1-ef2;

    ud1 = unwrap_phase_with_reference(dl,d1,efl,ef1);
    absolute_phase = unwrap_phase_with_reference(ud1,wh,ef1,f1);

    if verbose
        fprintf('✓ 绝对相位计算完成，范围 [%.2f, %.2f] rad\n', ...
                min(absolute_phase(:)), max(absolute_phase(:)));
    end
end

%% ========================================================================
%  Step 4：可视化（与 phase_visualization.m 完全一致）
% ========================================================================

function idx = determine_line_index(shape, mode, position, line_index)
    if strcmp(mode,'row'), dim=shape(1); else, dim=shape(2); end
    if ~isempty(line_index)
        idx = max(1, min(round(line_index), dim)); return;
    end
    switch position
        case 'top',           idx=round(dim/10);
        case 'bottom',        idx=round(dim*9/10);
        case 'center',        idx=round(dim/2);
        case 'quarter',       idx=round(dim/4);
        case 'three_quarter', idx=round(dim*3/4);
        otherwise,            idx=round(dim/2);
    end
end

function visualize_line_profile(phase, mask, mode, idx, save_folder, ...
    freq_combination, ~, position)
    % 行/列剖面曲线图 + 2D 伪彩色图
    % 可视化风格与 phase_visualization.m 完全一致

    if ~isfolder(save_folder), mkdir(save_folder); end

    dp = phase;
    if ~isempty(mask) && isequal(size(mask), size(phase))
        dp(~mask) = NaN;
    end

    [H, W] = size(phase);
    if strcmp(mode, 'row')
        line_data = dp(idx, :);
        pixel_pos = 1:W;
        lx = '列索引 (pixels)';
        dir_txt = sprintf('行 %d', idx);
    else
        line_data = dp(:, idx)';
        pixel_pos = 1:H;
        lx = '行索引 (pixels)';
        dir_txt = sprintf('列 %d', idx);
    end

    valid = line_data(~isnan(line_data));
    line_min  = min(valid);  line_max = max(valid);
    line_mean = mean(valid); line_std = std(valid);
    if isempty(valid)
        line_min=0; line_max=0; line_mean=0; line_std=0;
    end
    mask_sfx = ''; if ~isempty(mask), mask_sfx = '（使用掩码后）'; end

    % ── 打印统计信息（与 phase_visualization.m 一致） ──
    fprintf('\n正在生成相位变化曲线图...\n');
    fprintf('  选择%s索引: %d (位置: %s)\n', dir_txt(1), idx, position);
    fprintf('  相位范围: [%.4f, %.4f] rad\n', line_min, line_max);
    fprintf('  相位变化: %.4f rad\n', line_max - line_min);
    fprintf('  平均值:   %.4f rad\n', line_mean);
    fprintf('  标准差:   %.4f rad\n', line_std);

    % ── 图A：相位走势曲线（与 phase_visualization.m 完全一致） ──
    figure;
    plot(pixel_pos, line_data, 'b-', 'LineWidth', 1.5);
    hold on;
    plot([pixel_pos(1), pixel_pos(end)], [line_mean, line_mean], '--r', ...
         'LineWidth', 2, 'DisplayName', sprintf('平均值: %.4f', line_mean));
    title(sprintf('绝对相位变化曲线 - 第 %d %s（%s位置）%s', ...
                  idx, dir_txt(1), position, mask_sfx), 'FontSize', 16);
    xlabel(lx, 'FontSize', 14);
    ylabel('相位值 (rad)', 'FontSize', 14);
    grid on;
    grid minor;
    legend('Location', 'best', 'FontSize', 12);
    hold off;
    drawnow;

    cp = fullfile(save_folder, sprintf('phase_line_%s%d_curve.png', mode, idx));
    exportgraphics(gcf, cp, 'Resolution', 300);
    fprintf('[SAVE] 相位剖面曲线: %s\n', cp);
    fprintf('✓ 相位变化曲线图生成完成\n');

    % ── 图B：2D 绝对相位伪彩色图（parula，原始弧度范围） ──
    figure;
    imagesc(dp);
    colormap(parula);
    hold on;
    if strcmp(mode, 'row')
        yline(idx, 'r--', 'LineWidth', 2, 'Label', sprintf('选择的行: %d', idx));
    else
        xline(idx, 'r--', 'LineWidth', 2, 'Label', sprintf('选择的列: %d', idx));
    end
    title(sprintf('绝对相位图像%s\n频率组合: %s', mask_sfx, freq_combination), ...
          'FontSize', 14);
    xlabel('列索引 (pixels)', 'FontSize', 12);
    ylabel('行索引 (pixels)', 'FontSize', 12);
    axis image;
    cb = colorbar; cb.Label.String = 'Absolute Phase (rad)';
    hold off;
    drawnow;

    ip = fullfile(save_folder, sprintf('phase_line_%s%d_image.png', mode, idx));
    exportgraphics(gcf, ip, 'Resolution', 300);
    fprintf('[SAVE] 相位伪彩色图: %s\n', ip);
end

function visualize_3d_surface(phase, mask, save_folder, freq_combination, ...
    ~, downsample_factor)
    % 3D 表面图，可视化风格与 phase_visualization.m 完全一致

    if ~isfolder(save_folder), mkdir(save_folder); end

    dp = phase;
    if ~isempty(mask) && isequal(size(mask), size(phase))
        dp(~mask) = NaN;
    end

    % 适当降采样以加速渲染
    [H, W] = size(dp);
    if nargin < 6 || isempty(downsample_factor)
        downsample_factor = max(1, floor(max(H,W)/500));
    end
    if downsample_factor > 1
        p3 = dp(1:downsample_factor:end, 1:downsample_factor:end);
    else
        p3 = dp;
    end

    phase_min = min(p3(:), [], 'omitnan');
    phase_max = max(p3(:), [], 'omitnan');
    fprintf('  3D 相位范围: [%.2fπ , %.2fπ]\n', phase_min/pi, phase_max/pi);

    figure;
    surf(p3, 'EdgeColor', 'none');
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

    p3d = fullfile(save_folder, sprintf('phase_3d_surface_%s.png', freq_combination));
    exportgraphics(gcf, p3d, 'Resolution', 300);
    fprintf('[SAVE] 3D 表面图: %s\n', p3d);
end

%% ========================================================================
%  主流程
% ========================================================================

function result = run_integrated_pipeline(...
    projection_folder, phase_shift_step, orientation, freq_combination, ...
    roi_background_image, roi, ...
    extract_mode, line_index, position, ...
    output_dir, generate_3d, use_interactive)

    fprintf('%s\n  整合版：绝对相位生成与可视化流程\n%s\n', ...
            repmat('=',1,65), repmat('=',1,65));

    mask=[]; roi_bounds=[];

    % 确定背景图
    if ~isempty(roi_background_image) && isfile(roi_background_image)
        bg_img = imread(roi_background_image);
        if ndims(bg_img)==3, bg_img=rgb2gray(bg_img); end
    else
        img_ext = detect_image_extension(projection_folder, orientation, 1);
        if isempty(img_ext), error('在 %s 中未找到条纹图像',projection_folder); end
        bg_img = imread(fullfile(projection_folder, sprintf('%s1%s',orientation,img_ext)));
        if ndims(bg_img)==3, bg_img=rgb2gray(bg_img); end
    end
    [bg_h, bg_w] = size(bg_img);

    %% ── STEP 1：ROI 选择 ──
    interactive_roi = false;
    if use_interactive && isempty(roi)
        fprintf('\n[STEP 1] 交互式 ROI + 行/列选择...\n');
        [roi_bounds, extract_mode, line_index] = select_roi_interactive_phase(bg_img);
        interactive_roi = true;
    elseif ~isempty(roi)
        fprintf('\n[STEP 1] 手动 ROI: [%d,%d,%d,%d]\n', roi(1),roi(2),roi(3),roi(4));
        roi_bounds = [max(1,roi(1)),min(bg_h,roi(2)), max(1,roi(3)),min(bg_w,roi(4))];
    else
        fprintf('\n[STEP 1] 未指定 ROI，使用全图。\n');
    end

    if ~isempty(roi_bounds)
        is_full = roi_bounds(1)==1 && roi_bounds(2)==bg_h && ...
                  roi_bounds(3)==1 && roi_bounds(4)==bg_w;
        if is_full
            roi_bounds = [];
            fprintf('  ROI 为全图，等同于不使用掩码。\n');
        else
            ratio = (roi_bounds(2)-roi_bounds(1)+1)*(roi_bounds(4)-roi_bounds(3)+1) ...
                    /(bg_h*bg_w)*100;
            fprintf('  ROI 占比: %.2f%%\n', ratio);
        end
    end

    %% ── STEP 2：计算绝对相位 ──
    fprintf('\n[STEP 2] 读取图像并计算绝对相位...\n');
    [absolute_phase, freq_comb] = compute_absolute_phase_3freq(...
        projection_folder, phase_shift_step, orientation, freq_combination, true);

    if ~isempty(roi_bounds)
        mask = roi_to_mask(size(absolute_phase), roi_bounds);
        mask_dir = fullfile(output_dir,'mask');
        if ~isfolder(mask_dir), mkdir(mask_dir); end
        imwrite(uint8(mask)*255, fullfile(mask_dir,'mask.bmp'));
        save(fullfile(mask_dir,'mask.mat'),'mask');
        fprintf('  掩码已保存: %s\n', mask_dir);
    end

    phase_dir = fullfile(output_dir,'phase_data');
    if ~isfolder(phase_dir), mkdir(phase_dir); end
    % 以 phase_data 变量名保存，与 phase_visualization.m 兼容
    phase_data = absolute_phase;
    save(fullfile(phase_dir, sprintf('absolute_phase_%s.mat',freq_comb)), 'phase_data');
    fprintf('  绝对相位已保存: %s  (变量名: phase_data)\n', phase_dir);

    %% ── STEP 3：确定分析行/列 ──
    fprintf('\n[STEP 3] 确定分析方向和索引...\n');
    if interactive_roi && ~isempty(roi_bounds)
        if strcmp(extract_mode,'row')
            idx = max(1, min(roi_bounds(1)+line_index-1, size(absolute_phase,1)));
        else
            idx = max(1, min(roi_bounds(3)+line_index-1, size(absolute_phase,2)));
        end
    else
        idx = determine_line_index(size(absolute_phase), extract_mode, position, line_index);
    end
    dim_nm = '行'; if ~strcmp(extract_mode,'row'), dim_nm='列'; end
    fprintf('  分析方向: %s (%s)，全图绝对索引: %d\n', dim_nm, extract_mode, idx);

    %% ── STEP 4：可视化（所有图同时显示，立即保存，窗口保持开启） ──
    vis_dir = fullfile(output_dir,'visualization');
    fprintf('\n[STEP 4] 生成可视化图像（所有窗口将同时显示，可自由交互）...\n');

    visualize_line_profile(absolute_phase, mask, extract_mode, idx, ...
        vis_dir, freq_comb, [], position);

    if generate_3d
        fprintf('\n[STEP 4-3D] 生成 3D 表面图...\n');
        visualize_3d_surface(absolute_phase, mask, vis_dir, freq_comb, []);
    end

    %% ── 完成 ──
    fprintf('\n%s\n  ✔ 整合流程全部完成！\n', repmat('=',1,65));
    fprintf('  输出目录: %s\n', output_dir);
    fprintf('  ✔ 所有图窗均已保持开启，可自由放大、平移或点击查看具体相位值。\n');
    fprintf('%s\n', repmat('=',1,65));

    result.absolute_phase   = absolute_phase;
    result.mask             = mask;
    result.roi_bounds       = roi_bounds;
    result.freq_combination = freq_comb;
    result.line_index       = idx;
    result.extract_mode     = extract_mode;
    result.output_dir       = output_dir;
end
