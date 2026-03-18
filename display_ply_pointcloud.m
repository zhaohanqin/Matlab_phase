%% =========================================================================
%  PLY 点云交互式可视化工具
%  功能：读取 PLY 点云文件，显示并支持键盘快捷键交互
%  环境：MATLAB R2019b 及以上（需 Computer Vision Toolbox）
%  =========================================================================

clear; clc; close all;

%% ==================== 1. 选择并读取 PLY 文件 ====================

[fileName, filePath] = uigetfile({'*.ply', 'PLY 点云文件 (*.ply)'}, '请选择一个 PLY 点云文件');

if isequal(fileName, 0)
    disp('用户取消了文件选择，程序退出。');
    return;
end

fullFilePath = fullfile(filePath, fileName);
fprintf('正在读取文件: %s\n', fullFilePath);

ptCloud = pcread(fullFilePath);

fprintf('点云读取成功！\n');
fprintf('  点数: %d\n', ptCloud.Count);
fprintf('  X 范围: [%.4f, %.4f]\n', min(ptCloud.Location(:,1)), max(ptCloud.Location(:,1)));
fprintf('  Y 范围: [%.4f, %.4f]\n', min(ptCloud.Location(:,2)), max(ptCloud.Location(:,2)));
fprintf('  Z 范围: [%.4f, %.4f]\n', min(ptCloud.Location(:,3)), max(ptCloud.Location(:,3)));

%% ==================== 2. 创建可视化窗口并显示 ====================

hFig = figure('Name', ['点云查看器 - ', fileName], ...
              'NumberTitle', 'off', ...
              'Color', [0.15 0.15 0.15], ...
              'Position', [100, 100, 1200, 800], ...
              'KeyPressFcn', @keyPressCallback);

hAx = axes('Parent', hFig, 'Color', [0.1 0.1 0.1]);

% 判断点云是否自带颜色信息
if ~isempty(ptCloud.Color)
    pcshow(ptCloud, 'Parent', hAx, 'MarkerSize', 20);
    fprintf('  颜色模式: RGB（来自文件）\n');
else
    pcshow(ptCloud.Location, ptCloud.Location(:,3), 'Parent', hAx, 'MarkerSize', 20);
    colormap(hAx, jet);
    hCB = colorbar(hAx);
    hCB.Label.String = 'Z';
    hCB.Color = [0.9 0.9 0.9];
    fprintf('  颜色模式: 按 Z 值映射 (jet)\n');
end

%% ==================== 3. 美化显示 ====================

title(hAx, sprintf('点云: %s  (共 %d 个点)', fileName, ptCloud.Count), ...
      'Color', [0.9 0.9 0.9], 'FontSize', 14, 'Interpreter', 'none');
xlabel(hAx, 'X', 'Color', [0.8 0.8 0.8]);
ylabel(hAx, 'Y', 'Color', [0.8 0.8 0.8]);
zlabel(hAx, 'Z', 'Color', [0.8 0.8 0.8]);

hAx.XColor = [0.6 0.6 0.6];
hAx.YColor = [0.6 0.6 0.6];
hAx.ZColor = [0.6 0.6 0.6];
hAx.GridColor = [0.3 0.3 0.3];
grid(hAx, 'on');
axis(hAx, 'equal');

%% ==================== 4. 启用交互功能 ====================

% 默认开启三维旋转
rotate3d(hAx, 'on');

% 数据光标（默认关闭，按 D 键开启）
dcm = datacursormode(hFig);
dcm.Enable = 'off';
set(dcm, 'UpdateFcn', @(~, evt) sprintf('X: %.4f\nY: %.4f\nZ: %.4f', ...
    evt.Position(1), evt.Position(2), evt.Position(3)));

% 存储交互状态
userData.hAx        = hAx;
userData.hFig       = hFig;
userData.markerSize  = 20;
hFig.UserData = userData;

%% ==================== 5. 在控制台打印操作说明 ====================

fprintf('\n====== 交互操作说明 ======\n');
fprintf('  鼠标左键拖拽 : 旋转视角\n');
fprintf('  鼠标滚轮     : 缩放\n');
fprintf('  鼠标右键拖拽 : 平移\n');
fprintf('  按 R 键      : 重置视角\n');
fprintf('  按 D 键      : 切换数据光标模式\n');
fprintf('  按 X/Y/Z 键  : 切换到对应轴视图\n');
fprintf('  按 + / - 键  : 调整点大小\n');
fprintf('  按 S 键      : 保存当前点云视图为图片\n');
fprintf('  按 Q 键      : 退出\n');
fprintf('==========================\n\n');

%% ==================== 键盘回调函数 ====================

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
