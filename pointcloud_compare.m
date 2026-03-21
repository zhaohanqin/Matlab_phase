% 文件用途：对两帧 PLY 点云进行几何误差对比，统计最近邻距离误差。
%   · 低于阈值的点保留原始 RGB 颜色
%   · 高于阈值的点用柔和暖色渐变（浅黄→橙→深红）表示误差大小，并显示颜色条
% 使用方式：运行后依次选择"基准点云"和"待比较点云"，查看误差统计、双视图直方图
%           以及混合着色的误差点云（颜色条仅对应超阈值误差范围）。
%% =========================================================================
%  点云比较工具 - MATLAB 版本（原色保留 + 超阈值误差渐变 + 颜色条）
%  =========================================================================
%  改动说明（相对于上一版本）：
%    · Step 4  —— 阈值以下保留待比较点云原始颜色；阈值以上用柔和暖色渐变着色
%    · Step 5  —— 输出 PLY 使用上述混合颜色
%    · Step 6 图1 —— 直方图重新设计：
%                     左图：完整范围 + 对数纵轴（可看到全貌与尾部）
%                     右图：【双色直方图】缩放至阈值附近，阈值以下蓝色/以上橙色，
%                           清晰展示"大部分点低于阈值"的分布特征
%    · Step 6 图2 —— 两组 scatter3 叠加：
%                     原色组（阈值以下）：Nx3 真彩色，不走色图
%                     误差组（阈值以上）：标量 CData + 柔和暖色图
%                   颜色条范围 = [阈值, 超阈值点 P99]，刻度显示真实误差数值
%    · 数据光标：点击任意点显示 XYZ + 误差值，超阈值点额外标注 ★
%
%  环境：MATLAB R2019b 及以上（需 Computer Vision Toolbox / Statistics Toolbox）
%  =========================================================================

clear; clc; close all;

%% ==================== 用户配置区域 ====================
THRESHOLD     = 1.5;                  % 差异点判定阈值（与点云坐标单位一致）
OUTPUT_PLY    = 'output_colored.ply'; % 输出文件名
NUM_CMAP      = 256;                  % 色图分级数
% ======================================================

fprintf('\n========================================\n');
fprintf('  点云比较工具  (MATLAB 版 - 原色保留 + 误差渐变)\n');
fprintf('========================================\n\n');

%% ==================== Step 1：读取点云文件 ====================
fprintf('【Step 1】读取点云文件...\n');

[refFile, refPath] = uigetfile({'*.ply','PLY 文件 (*.ply)'}, '请选择基准点云文件');
if isequal(refFile, 0), disp('用户取消，程序退出。'); return; end
refCloud = pcread(fullfile(refPath, refFile));
fprintf('  已读取基准点云: %s  |  点数: %d  |  含颜色: %s\n', ...
    refFile, refCloud.Count, yn(~isempty(refCloud.Color)));

[cmpFile, cmpPath] = uigetfile({'*.ply','PLY 文件 (*.ply)'}, '请选择待比较点云文件', refPath);
if isequal(cmpFile, 0), disp('用户取消，程序退出。'); return; end
cmpCloud = pcread(fullfile(cmpPath, cmpFile));
fprintf('  已读取待比较点云: %s  |  点数: %d  |  含颜色: %s\n', ...
    cmpFile, cmpCloud.Count, yn(~isempty(cmpCloud.Color)));

%% ==================== Step 2：计算最近邻欧氏距离误差 ====================
fprintf('\n【Step 2】计算最近邻欧氏距离误差...\n');

refPoints = double(refCloud.Location);
cmpPoints = double(cmpCloud.Location);

fprintf('  正在构建 KD-Tree（基准点云）...\n');
tic;
kdTree         = KDTreeSearcher(refPoints);
[~, distances] = knnsearch(kdTree, cmpPoints);
elapsed        = toc;
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
p99_e    = prctile(distances, 99);
n_diff   = sum(distances > THRESHOLD);
ratio    = n_diff / N * 100;

fprintf('\n==================================================\n');
fprintf('  点云误差统计结果\n');
fprintf('==================================================\n');
fprintf('  待比较点云总点数     : %d\n',   N);
fprintf('  平均误差  (Mean)     : %.6f\n', mean_e);
fprintf('  最大误差  (Max)      : %.6f\n', max_e);
fprintf('  最小误差  (Min)      : %.6f\n', min_e);
fprintf('  均方根误差 (RMSE)    : %.6f\n', rmse_e);
fprintf('  标准差   (Std)       : %.6f\n', std_e);
fprintf('  中位数   (Median)    : %.6f\n', median_e);
fprintf('  95 百分位 (P95)      : %.6f\n', p95_e);
fprintf('  99 百分位 (P99)      : %.6f\n', p99_e);
fprintf('  差异点数 (>%.4f)    : %d / %d  (%.2f%%)\n', THRESHOLD, n_diff, N, ratio);
fprintf('==================================================\n\n');

%% ==================== Step 4：生成混合颜色（原色 + 误差渐变） ====================
fprintf('【Step 4】生成混合颜色...\n');

diffMask  = distances > THRESHOLD;

% —— 原始颜色 ——
if ~isempty(cmpCloud.Color)
    origColorsU8 = uint8(cmpCloud.Color);
else
    origColorsU8 = repmat(uint8([180 180 180]), N, 1);
end

% —— 柔和暖色图：米白/浅黄 → 橙 → 深砖红 ——
t            = linspace(0, 1, NUM_CMAP)';
cR           = ones(NUM_CMAP, 1);
cG           = max(0, 0.92 - t .* 0.92);
cB           = max(0, 0.75 .* (1 - t) .^ 2);
softWarmCmap = [cR, cG, cB];

% 颜色映射范围：仅对超阈值点，上限取其 P99
if any(diffMask)
    maxDisplayDist = max(prctile(distances(diffMask), 99), THRESHOLD + eps);
else
    maxDisplayDist = THRESHOLD + eps;
end

% —— PLY 输出用颜色：超阈值点用渐变色替换 ——
mixedColorsU8 = origColorsU8;
if any(diffMask)
    normAbove = min((distances(diffMask) - THRESHOLD) ./ ...
                   (maxDisplayDist - THRESHOLD), 1);
    normAbove = max(normAbove, 0);
    idxAbove  = max(1, round(normAbove * (NUM_CMAP - 1)) + 1);
    mixedColorsU8(diffMask, :) = uint8(softWarmCmap(idxAbove, :) * 255);
end

fprintf('  阈值以下（保留原色）  : %d 点\n',  N - n_diff);
fprintf('  阈值以上（误差渐变）  : %d 点  |  颜色映射范围: [%.4f, %.4f]\n', ...
        n_diff, THRESHOLD, maxDisplayDist);

%% ==================== Step 5：写出混合着色点云文件 ====================
fprintf('\n【Step 5】写出混合着色点云文件...\n');

coloredCloud   = pointCloud(cmpCloud.Location, 'Color', mixedColorsU8);
outputFullPath = fullfile(cmpPath, OUTPUT_PLY);
pcwrite(coloredCloud, outputFullPath, 'Encoding', 'binary');
fprintf('  已保存彩色点云 : %s  |  点数 : %d\n', outputFullPath, coloredCloud.Count);

%% ==================== Step 6：可视化 ====================
fprintf('\n【Step 6】生成可视化图表...\n');

X = double(cmpCloud.Location(:, 1));
Y = double(cmpCloud.Location(:, 2));
Z = double(cmpCloud.Location(:, 3));

% ----------------------------------------------------------------
%  图 1：双子图误差分布直方图
%    左图：完整范围 + 对数纵轴（看全貌）
%    右图：双色直方图，缩放到阈值附近，突出"低于阈值占主体"
% ----------------------------------------------------------------
hFig1 = figure('Name', '误差分布直方图（双视图）', 'NumberTitle', 'off', ...
               'Color', [0.96 0.96 0.96], 'Position', [30, 80, 1200, 520]);

% —— 左图：完整范围 + 对数纵轴 ——
ax1L = subplot(1, 2, 1);
histogram(ax1L, distances, 300, ...
    'FaceColor', [0.25 0.55 0.90], 'EdgeColor', 'none');
set(ax1L, 'YScale', 'log');
hold(ax1L, 'on');
xline(ax1L, THRESHOLD, 'r--', 'LineWidth', 2, ...
    'Label', sprintf('阈值 = %.2f', THRESHOLD), ...
    'LabelVerticalAlignment', 'bottom', 'LabelHorizontalAlignment', 'right');
xline(ax1L, p95_e, 'g--', 'LineWidth', 1.5, ...
    'Label', sprintf('P95 = %.3f', p95_e), ...
    'LabelVerticalAlignment', 'bottom', 'LabelHorizontalAlignment', 'right');
hold(ax1L, 'off');
xlabel(ax1L, '最近邻距离误差', 'FontSize', 11);
ylabel(ax1L, '点数（对数纵轴）', 'FontSize', 11);
title(ax1L, sprintf('全范围分布（对数纵轴）\n最大误差 = %.4f', max_e), 'FontSize', 11);
grid(ax1L, 'on'); box(ax1L, 'on');

% —— 右图：双色直方图，聚焦阈值附近，清晰展示主体分布 ——
%   X 轴范围：0 到 clipVal，使阈值竖线在图中靠右约 1/3 处，让"蓝色主体"一目了然
%   clipVal 取 max(4*THRESHOLD, P85) 与 P99 的较小值，兼顾不同数据集
ax1R = subplot(1, 2, 2);

p85_e    = prctile(distances, 85);
clipVal  = min(max(4 * THRESHOLD, p85_e * 1.2), p99_e);

% 使用统一 binEdges，令阈值恰好落在某个 bin 边界附近
nBins    = 180;
binEdges = linspace(0, clipVal, nBins + 1);

% 分离两组数据（只取截断范围内的点）
dBelow = distances(distances <= THRESHOLD);
dAbove = distances(distances > THRESHOLD & distances <= clipVal);

% 阈值以下：蓝色
hB = histogram(ax1R, dBelow, binEdges, ...
    'FaceColor', [0.25 0.55 0.90], 'EdgeColor', 'none', ...
    'DisplayName', sprintf('阈值以下  %.1f%%  (%d 点)', 100 - ratio, N - n_diff));
hold(ax1R, 'on');

% 阈值以上（截断范围内）：橙红色
hA = histogram(ax1R, dAbove, binEdges, ...
    'FaceColor', [0.92 0.38 0.18], 'EdgeColor', 'none', ...
    'DisplayName', sprintf('阈值以上  %.1f%%  (%d 点)', ratio, n_diff));

% 参考线
xline(ax1R, THRESHOLD, 'r-',  'LineWidth', 2.5, ...
    'Label', sprintf('阈值 = %.2f', THRESHOLD), ...
    'LabelVerticalAlignment', 'bottom', 'LabelHorizontalAlignment', 'right');
xline(ax1R, median_e, '--', 'Color', [0.2 0.7 0.3], 'LineWidth', 1.5, ...
    'Label', sprintf('中位数 = %.4f', median_e), ...
    'LabelVerticalAlignment', 'top', 'LabelHorizontalAlignment', 'right');
xline(ax1R, mean_e, 'm--', 'LineWidth', 1.5, ...
    'Label', sprintf('均值 = %.4f', mean_e), ...
    'LabelVerticalAlignment', 'bottom', 'LabelHorizontalAlignment', 'right');

hold(ax1R, 'off');

% 图例（左上角，不遮挡主体）
lgd = legend(ax1R, [hB, hA], 'Location', 'northeast', 'FontSize', 9);
lgd.Color = [0.97 0.97 0.97];
lgd.EdgeColor = [0.7 0.7 0.7];

% 在图内右上角加比例文字标注
xLimR = xlim(ax1R);
yLimR = ylim(ax1R);
text(ax1R, xLimR(2) * 0.98, yLimR(2) * 0.55, ...
    sprintf('■ 正常点: %.1f%%\n■ 差异点: %.1f%%', 100 - ratio, ratio), ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
    'FontSize', 10, 'FontWeight', 'bold', ...
    'Color', [0.3 0.3 0.3], ...
    'BackgroundColor', [1 1 1 0.75], 'EdgeColor', [0.8 0.8 0.8], ...
    'Margin', 4);

xlabel(ax1R, '最近邻距离误差', 'FontSize', 11);
ylabel(ax1R, '点数', 'FontSize', 11);
title(ax1R, sprintf('局部放大（0 ~ %.2f，双色区分阈值）\n蓝色=正常点主体  橙色=差异点', clipVal), ...
    'FontSize', 11);
xlim(ax1R, [0, clipVal]);
grid(ax1R, 'on'); box(ax1R, 'on');

sgtitle(hFig1, sprintf('误差分布统计  |  均值=%.4f  RMSE=%.4f  差异点=%.2f%%  (阈值=%.2f)', ...
    mean_e, rmse_e, ratio, THRESHOLD), 'FontSize', 13, 'FontWeight', 'bold');

% ----------------------------------------------------------------
%  图 2：混合着色点云 + 颜色条（仅超阈值部分映射到色图）
% ----------------------------------------------------------------
hFig2 = figure('Name', '点云误差可视化', 'NumberTitle', 'off', ...
               'Color', [0.12 0.12 0.12], ...
               'Position', [700, 80, 1200, 800], ...
               'KeyPressFcn', @keyPressCallback);

hAx = axes('Parent', hFig2, 'Color', [0.08 0.08 0.08]);
hold(hAx, 'on');

% —— 第一层：阈值以下，Nx3 真彩色（不走色图，不影响颜色条） ——
maskBelow = ~diffMask;
if any(maskBelow)
    origNorm = double(origColorsU8(maskBelow, :)) / 255;
    scatter3(hAx, X(maskBelow), Y(maskBelow), Z(maskBelow), ...
             3, origNorm, 'filled');
end

% —— 第二层：阈值以上，标量 CData → 走色图 ——
hScAbove = [];
if any(diffMask)
    hScAbove = scatter3(hAx, X(diffMask), Y(diffMask), Z(diffMask), ...
                        8, distances(diffMask), 'filled');
end

% —— 色图与颜色条范围 ——
colormap(hAx, softWarmCmap);
clim(hAx, [THRESHOLD, maxDisplayDist]);

% —— 颜色条 ——
hCB = colorbar(hAx, 'eastoutside');
hCB.Color            = [0.85 0.85 0.85];
hCB.FontSize         = 10;
hCB.Label.String     = sprintf('误差值（最近邻距离）\n← 浅色：刚超阈值(%.2f)     深红：大误差 →', THRESHOLD);
hCB.Label.Color      = [0.85 0.85 0.85];
hCB.Label.FontSize   = 10;
hCB.Label.FontWeight = 'bold';
numTicks             = 8;
tickVals             = linspace(THRESHOLD, maxDisplayDist, numTicks);
hCB.Ticks            = tickVals;
hCB.TickLabels       = arrayfun(@(v) sprintf('%.3f', v), tickVals, 'UniformOutput', false);

hold(hAx, 'off');

% —— 坐标轴外观 ——
title(hAx, ...
    sprintf('点云误差图：%s  vs  %s\n差异点：%d / %d（阈值 > %.2f，占 %.2f%%）  |  原色=正常区域  暖色=误差区域', ...
    cmpFile, refFile, n_diff, N, THRESHOLD, ratio), ...
    'Color', [0.92 0.92 0.92], 'FontSize', 11, 'Interpreter', 'none');
xlabel(hAx, 'X', 'Color', [0.75 0.75 0.75], 'FontSize', 11);
ylabel(hAx, 'Y', 'Color', [0.75 0.75 0.75], 'FontSize', 11);
zlabel(hAx, 'Z', 'Color', [0.75 0.75 0.75], 'FontSize', 11);
hAx.XColor    = [0.55 0.55 0.55];
hAx.YColor    = [0.55 0.55 0.55];
hAx.ZColor    = [0.55 0.55 0.55];
hAx.GridColor = [0.28 0.28 0.28];
grid(hAx, 'on');
axis(hAx, 'equal');
view(hAx, 3);

% —— 数据光标 ——
rotate3d(hAx, 'on');
dcm = datacursormode(hFig2);
dcm.Enable = 'off';
set(dcm, 'UpdateFcn', @(~, evt) dataCursorTip(evt, distances, THRESHOLD));

% —— 交互状态 ——
userData.hAx        = hAx;
userData.hFig       = hFig2;
userData.hScAbove   = hScAbove;
userData.markerSize = 8;
userData.distances  = distances;
hFig2.UserData = userData;

fprintf('\n========================================\n');
fprintf('  全部完成！\n');
fprintf('  输出文件 : %s\n', outputFullPath);
fprintf('========================================\n');
fprintf('\n====== 点云图窗交互说明 ======\n');
fprintf('  鼠标左键拖拽 : 旋转视角\n');
fprintf('  鼠标滚轮     : 缩放\n');
fprintf('  鼠标右键拖拽 : 平移\n');
fprintf('  按 R 键      : 重置视角\n');
fprintf('  按 D 键      : 切换数据光标（显示坐标与误差值）\n');
fprintf('  按 X/Y/Z 键  : 切换到对应轴视图\n');
fprintf('  按 + / - 键  : 调整超阈值点大小\n');
fprintf('  按 S 键      : 保存当前点云视图为图片\n');
fprintf('  按 Q 键      : 关闭点云窗口\n');
fprintf('================================\n\n');

%% ==================== 辅助函数 ====================

function s = yn(flag)
    if flag, s = '是'; else, s = '否'; end
end

function tip = dataCursorTip(evt, distances, threshold)
    pos = evt.Position;
    idx = evt.DataIndex;
    if idx > 0 && idx <= length(distances)
        d = distances(idx);
        if d > threshold
            tag = sprintf('误差 : %.6f  ★超阈值', d);
        else
            tag = sprintf('误差 : %.6f  (低于阈值)', d);
        end
        tip = sprintf('X : %.4f\nY : %.4f\nZ : %.4f\n%s', ...
            pos(1), pos(2), pos(3), tag);
    else
        tip = sprintf('X : %.4f\nY : %.4f\nZ : %.4f', pos(1), pos(2), pos(3));
    end
end

function keyPressCallback(src, event)
    ud = src.UserData;
    ax = ud.hAx;

    switch lower(event.Key)
        case 'r'
            view(ax, 3); axis(ax, 'tight'); axis(ax, 'equal');
            fprintf('视角已重置。\n');

        case 'd'
            dcmObj = datacursormode(src);
            if strcmp(dcmObj.Enable, 'on')
                dcmObj.Enable = 'off'; rotate3d(ax, 'on');
                fprintf('数据光标已关闭，旋转模式已开启。\n');
            else
                rotate3d(ax, 'off'); dcmObj.Enable = 'on';
                fprintf('数据光标已开启（点击点查看坐标与误差值）。\n');
            end

        case 'x', view(ax, 0, 0);   fprintf('切换到 YZ 平面视图。\n');
        case 'y', view(ax, 90, 0);  fprintf('切换到 XZ 平面视图。\n');
        case 'z', view(ax, 0, 90);  fprintf('切换到 XY 平面视图。\n');

        case 'equal'
            if ~isempty(ud.hScAbove) && isvalid(ud.hScAbove)
                ud.markerSize = min(ud.markerSize + 2, 200);
                ud.hScAbove.SizeData = ud.markerSize;
                src.UserData = ud;
                fprintf('超阈值点大小增大为: %d\n', ud.markerSize);
            end

        case 'hyphen'
            if ~isempty(ud.hScAbove) && isvalid(ud.hScAbove)
                ud.markerSize = max(ud.markerSize - 2, 1);
                ud.hScAbove.SizeData = ud.markerSize;
                src.UserData = ud;
                fprintf('超阈值点大小减小为: %d\n', ud.markerSize);
            end

        case 's'
            [saveFile, savePath] = uiputfile( ...
                {'*.png','PNG (*.png)';'*.jpg','JPEG (*.jpg)';'*.tif','TIFF (*.tif)'}, ...
                '保存点云图片', ...
                sprintf('pointcloud_error_%s.png', datestr(now,'yyyymmdd_HHMMss')));
            if ~isequal(saveFile, 0)
                exportgraphics(src, fullfile(savePath, saveFile), ...
                    'Resolution', 300, 'BackgroundColor', [0.12 0.12 0.12]);
                fprintf('点云图片已保存: %s\n', fullfile(savePath, saveFile));
            else
                fprintf('取消保存。\n');
            end

        case 'q'
            close(src); fprintf('已关闭点云查看器。\n');
    end
end
