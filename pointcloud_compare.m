%% =========================================================================
%  点云比较工具 - MATLAB 版本
%  =========================================================================
%  功能（与 Python 版完全一致）：
%    1. 读取两个 .ply 点云文件（基准点云 + 待比较点云）
%    2. 计算待比较点云相对于基准点云的逐点最近邻欧氏距离误差
%    3. 统计误差指标（均值、最大值、最小值、RMSE、标准差、中位数、P95）
%    4. 按阈值判定差异点，差异点标注为红色
%    5. 生成带颜色标注的新 .ply 文件
%    6. 在 MATLAB 中交互式显示结果点云（使用原生工具栏交互）
%
%  环境：MATLAB R2019b 及以上（需 Computer Vision Toolbox）
%  =========================================================================

clear; clc; close all;

%% ==================== 用户配置区域 ====================
THRESHOLD     = 1.5;                  % 差异点判定阈值（与点云坐标单位一致）
DEFAULT_COLOR = [180, 180, 180];      % 非差异点默认颜色 (R, G, B)，无颜色时使用
DIFF_COLOR    = [255, 0, 0];          % 差异点颜色：红色 (R, G, B)
OUTPUT_PLY    = 'output_colored.ply'; % 输出文件名
% ======================================================

fprintf('\n========================================\n');
fprintf('  点云比较工具  (MATLAB 版)\n');
fprintf('========================================\n\n');

%% ==================== Step 1：读取点云文件 ====================
fprintf('【Step 1】读取点云文件...\n');

% --- 选择基准点云 ---
[refFile, refPath] = uigetfile({'*.ply','PLY 文件 (*.ply)'}, '请选择基准点云文件');
if isequal(refFile, 0)
    disp('用户取消选择，程序退出。');
    return;
end
refFullPath = fullfile(refPath, refFile);
refCloud = pcread(refFullPath);
fprintf('  已读取基准点云: %s  |  点数: %d  |  含颜色: %s\n', ...
    refFile, refCloud.Count, yn(~isempty(refCloud.Color)));

% --- 选择待比较点云 ---
[cmpFile, cmpPath] = uigetfile({'*.ply','PLY 文件 (*.ply)'}, '请选择待比较点云文件', refPath);
if isequal(cmpFile, 0)
    disp('用户取消选择，程序退出。');
    return;
end
cmpFullPath = fullfile(cmpPath, cmpFile);
cmpCloud = pcread(cmpFullPath);
fprintf('  已读取待比较点云: %s  |  点数: %d  |  含颜色: %s\n', ...
    cmpFile, cmpCloud.Count, yn(~isempty(cmpCloud.Color)));

%% ==================== Step 2：计算最近邻欧氏距离误差 ====================
fprintf('\n【Step 2】计算最近邻欧氏距离误差...\n');

refPoints = double(refCloud.Location);  % (M, 3)
cmpPoints = double(cmpCloud.Location);  % (N, 3)

fprintf('  正在构建 KD-Tree（基准点云）...\n');
tic;
% 使用 knnsearch 进行最近邻查询（内部自动构建 KD-Tree）
[~, distances] = knnsearch(refPoints, cmpPoints, 'K', 1);
elapsed = toc;
fprintf('  最近邻查询完成，耗时: %.2f 秒\n', elapsed);

%% ==================== Step 3：统计误差指标 ====================
fprintf('\n【Step 3】统计误差指标...\n');

N        = length(distances);
mean_e   = mean(distances);
max_e    = max(distances);
min_e    = min(distances);
rmse_e   = sqrt(mean(distances .^ 2));
std_e    = std(distances);
median_e = median(distances);
p95_e    = prctile(distances, 95);
n_diff   = sum(distances > THRESHOLD);
ratio    = n_diff / N * 100;

fprintf('\n==================================================\n');
fprintf('  点云误差统计结果\n');
fprintf('==================================================\n');
fprintf('  待比较点云总点数     : %d\n', N);
fprintf('  平均误差  (Mean)     : %.6f\n', mean_e);
fprintf('  最大误差  (Max)      : %.6f\n', max_e);
fprintf('  最小误差  (Min)      : %.6f\n', min_e);
fprintf('  均方根误差 (RMSE)    : %.6f\n', rmse_e);
fprintf('  标准差   (Std)       : %.6f\n', std_e);
fprintf('  中位数   (Median)    : %.6f\n', median_e);
fprintf('  95 百分位 (P95)      : %.6f\n', p95_e);
fprintf('  差异点数 (>%.4f)    : %d / %d  (%.2f%%)\n', THRESHOLD, n_diff, N, ratio);
fprintf('==================================================\n\n');

%% ==================== Step 4：标注差异点（红色） ====================
fprintf('【Step 4】标注差异点（红色）...\n');

% 初始化颜色矩阵
if ~isempty(cmpCloud.Color)
    % 保留原始颜色
    newColors = double(cmpCloud.Color);  % (N, 3) uint8 → double
else
    % 无颜色信息，使用默认灰色
    newColors = repmat(DEFAULT_COLOR, N, 1);
end

% 将差异点标记为红色
diffMask = distances > THRESHOLD;
newColors(diffMask, :) = repmat(DIFF_COLOR, sum(diffMask), 1);
newColors = uint8(newColors);

fprintf('  差异点数量: %d  |  阈值: %.4f\n', n_diff, THRESHOLD);

%% ==================== Step 5：写出带颜色标注的点云文件 ====================
fprintf('\n【Step 5】写出带颜色标注的点云文件...\n');

% 构建带颜色的新点云对象
coloredCloud = pointCloud(cmpCloud.Location, 'Color', newColors);

% 保存到与待比较文件同目录
outputFullPath = fullfile(cmpPath, OUTPUT_PLY);
pcwrite(coloredCloud, outputFullPath, 'Encoding', 'binary');
fprintf('  已保存彩色点云: %s  |  点数: %d\n', outputFullPath, coloredCloud.Count);

%% ==================== Step 6：交互式显示结果点云 ====================
fprintf('\n【Step 6】显示带颜色标注的结果点云...\n');

% --- 图1：误差分布直方图 ---
hFig1 = figure('Name', '误差分布直方图', 'NumberTitle', 'off', ...
               'Position', [50, 100, 600, 450]);
histogram(distances, 200, 'FaceColor', [0.3 0.6 0.9], 'EdgeColor', 'none');
hold on;
xline(THRESHOLD, 'r--', 'LineWidth', 2);
hold off;
xlabel('最近邻距离误差');
ylabel('点数');
title(sprintf('误差分布直方图  (阈值 = %.2f, 红色虚线)', THRESHOLD));
grid on;

% --- 图2：带颜色标注的结果点云（主窗口，支持键盘交互） ---
hFig2 = figure('Name', '点云比较结果 - 差异点标红', 'NumberTitle', 'off', ...
               'Color', [0.15 0.15 0.15], ...
               'Position', [680, 100, 1000, 750], ...
               'KeyPressFcn', @keyPressCallback);

hAx = axes('Parent', hFig2, 'Color', [0.1 0.1 0.1]);
pcshow(coloredCloud, 'Parent', hAx, 'MarkerSize', 20);

title(hAx, sprintf('点云比较结果: %s vs %s  (差异点: %d, 阈值: %.2f)', ...
      cmpFile, refFile, n_diff, THRESHOLD), ...
      'Color', [0.9 0.9 0.9], 'FontSize', 13, 'Interpreter', 'none');
xlabel(hAx, 'X', 'Color', [0.8 0.8 0.8]);
ylabel(hAx, 'Y', 'Color', [0.8 0.8 0.8]);
zlabel(hAx, 'Z', 'Color', [0.8 0.8 0.8]);
hAx.XColor = [0.6 0.6 0.6];
hAx.YColor = [0.6 0.6 0.6];
hAx.ZColor = [0.6 0.6 0.6];
hAx.GridColor = [0.3 0.3 0.3];
grid(hAx, 'on');
axis(hAx, 'equal');

% 启用三维旋转（默认模式）
rotate3d(hAx, 'on');

% 配置数据光标（默认关闭，按 D 键开启）
dcm = datacursormode(hFig2);
dcm.Enable = 'off';
set(dcm, 'UpdateFcn', @(~, evt) sprintf('X: %.4f\nY: %.4f\nZ: %.4f', ...
    evt.Position(1), evt.Position(2), evt.Position(3)));

% 存储交互状态
userData.hAx        = hAx;
userData.hFig       = hFig2;
userData.markerSize  = 20;
hFig2.UserData = userData;

fprintf('\n========================================\n');
fprintf('  全部完成！\n');
fprintf('  输出文件: %s\n', outputFullPath);
fprintf('========================================\n');
fprintf('\n====== 点云图窗交互说明 ======\n');
fprintf('  鼠标左键拖拽 : 旋转视角\n');
fprintf('  鼠标滚轮     : 缩放\n');
fprintf('  鼠标右键拖拽 : 平移\n');
fprintf('  按 R 键      : 重置视角\n');
fprintf('  按 D 键      : 切换数据光标模式\n');
fprintf('  按 X/Y/Z 键  : 切换到对应轴视图\n');
fprintf('  按 + / - 键  : 调整点大小\n');
fprintf('  按 S 键      : 保存当前点云视图为图片\n');
fprintf('  按 Q 键      : 退出\n');
fprintf('================================\n\n');

%% ==================== 辅助函数 ====================

function s = yn(flag)
% 将逻辑值转换为 '是'/'否' 字符串
    if flag
        s = '是';
    else
        s = '否';
    end
end

function keyPressCallback(src, event)
    ud = src.UserData;
    ax = ud.hAx;

    switch lower(event.Key)
        case 'r'
            view(ax, 3);
            axis(ax, 'tight');
            axis(ax, 'equal');
            fprintf('视角已重置。\n');

        case 'd'
            dcmObj = datacursormode(src);
            if strcmp(dcmObj.Enable, 'on')
                dcmObj.Enable = 'off';
                rotate3d(ax, 'on');
                fprintf('数据光标已关闭，旋转模式已开启。\n');
            else
                rotate3d(ax, 'off');
                dcmObj.Enable = 'on';
                fprintf('数据光标已开启（点击点查看坐标）。\n');
            end

        case 'x'
            view(ax, 0, 0);
            fprintf('切换到 YZ 平面视图（X 轴方向）。\n');

        case 'y'
            view(ax, 90, 0);
            fprintf('切换到 XZ 平面视图（Y 轴方向）。\n');

        case 'z'
            view(ax, 0, 90);
            fprintf('切换到 XY 平面视图（Z 轴方向）。\n');

        case 'equal'
            ud.markerSize = min(ud.markerSize + 5, 200);
            children = findobj(ax, 'Type', 'Scatter');
            if ~isempty(children)
                children.SizeData = ud.markerSize;
            end
            src.UserData = ud;
            fprintf('点大小增大为: %d\n', ud.markerSize);

        case 'hyphen'
            ud.markerSize = max(ud.markerSize - 5, 1);
            children = findobj(ax, 'Type', 'Scatter');
            if ~isempty(children)
                children.SizeData = ud.markerSize;
            end
            src.UserData = ud;
            fprintf('点大小减小为: %d\n', ud.markerSize);

        case 's'
            [saveFile, savePath] = uiputfile( ...
                {'*.png','PNG (*.png)'; '*.jpg','JPEG (*.jpg)'; '*.tif','TIFF (*.tif)'}, ...
                '保存点云图片', ...
                sprintf('pointcloud_%s.png', datestr(now, 'yyyymmdd_HHMMss')));
            if ~isequal(saveFile, 0)
                saveFullPath = fullfile(savePath, saveFile);
                exportgraphics(ud.hAx, saveFullPath, 'Resolution', 300, 'BackgroundColor', [0.1 0.1 0.1]);
                fprintf('点云图片已保存: %s\n', saveFullPath);
            else
                fprintf('取消保存。\n');
            end

        case 'q'
            close(src);
            fprintf('已关闭点云查看器。\n');
    end
end
