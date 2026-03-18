% 文件用途：提供图形界面方式打开、浏览和简单处理 PLY 点云（包含信息统计和网格下采样）。
% 使用方式：在 MATLAB 命令行中调用 `ply_pointcloud_viewer`，在弹出的 UI 中点击 “Open PLY File” 选择点云文件，再通过下采样、重置视角和保存截图等按钮进行交互操作。
function ply_pointcloud_viewer
    % PLY 点云交互查看器
    % 功能：
    % 1. 打开 PLY 点云文件
    % 2. 显示点云
    % 3. 显示基础信息
    % 4. 网格下采样
    % 5. 重置视角
    % 6. 保存当前视图截图

    clc;

    % -----------------------------
    % 全局数据
    % -----------------------------
    data.ptCloud = [];
    data.ptCloudOriginal = [];
    data.fileName = '';
    data.filePath = '';

    % -----------------------------
    % 创建主界面
    % -----------------------------
    fig = uifigure('Name', 'PLY Point Cloud Viewer', ...
                   'Position', [100 100 1200 700]);

    % 显示区域
    ax = uiaxes(fig, ...
                'Position', [260 80 900 580]);
    title(ax, 'Point Cloud Display');
    xlabel(ax, 'X');
    ylabel(ax, 'Y');
    zlabel(ax, 'Z');
    grid(ax, 'on');
    axis(ax, 'equal');
    view(ax, 3);

    % 信息显示框
    infoArea = uitextarea(fig, ...
                          'Position', [20 80 220 380], ...
                          'Editable', 'off', ...
                          'Value', {'No point cloud loaded.'});

    % 标签
    uilabel(fig, ...
            'Position', [20 470 220 20], ...
            'Text', 'Point Cloud Information');

    % 打开文件按钮
    btnOpen = uibutton(fig, 'push', ...
                       'Text', 'Open PLY File', ...
                       'Position', [20 620 220 35], ...
                       'ButtonPushedFcn', @(btn, event) openFileCallback());

    % 下采样按钮
    btnDownsample = uibutton(fig, 'push', ...
                             'Text', 'Downsample', ...
                             'Position', [20 570 220 35], ...
                             'ButtonPushedFcn', @(btn, event) downsampleCallback());

    % 重置视角按钮
    btnResetView = uibutton(fig, 'push', ...
                            'Text', 'Reset View', ...
                            'Position', [20 520 220 35], ...
                            'ButtonPushedFcn', @(btn, event) resetViewCallback());

    % 保存截图按钮
    btnSave = uibutton(fig, 'push', ...
                       'Text', 'Save Screenshot', ...
                       'Position', [20 30 220 35], ...
                       'ButtonPushedFcn', @(btn, event) saveScreenshotCallback());

    % 下采样输入标签
    uilabel(fig, ...
            'Position', [20 675 220 20], ...
            'Text', 'Grid Size for Downsampling');

    % 下采样输入框
    editGrid = uieditfield(fig, 'numeric', ...
                           'Position', [20 495 220 22], ...
                           'Value', 0.01, ...
                           'Limits', [0 Inf]);

    % 提示文字
    helpLabel = uilabel(fig, ...
                        'Position', [260 20 900 40], ...
                        'Text', ['Mouse interaction: left-drag rotate, scroll zoom, right-drag pan. ' ...
                                 'Use toolbar tools for more interaction.']);

    % -----------------------------
    % 回调函数：打开文件
    % -----------------------------
    function openFileCallback()
        [file, path] = uigetfile('*.ply', 'Select a PLY point cloud file');
        if isequal(file, 0)
            return;
        end

        fullPath = fullfile(path, file);

        try
            ptCloud = pcread(fullPath);
        catch ME
            uialert(fig, ['Failed to read PLY file: ' ME.message], 'Read Error');
            return;
        end

        data.ptCloud = ptCloud;
        data.ptCloudOriginal = ptCloud;
        data.fileName = file;
        data.filePath = fullPath;

        showPointCloud();
        updateInfo();
    end

    % -----------------------------
    % 回调函数：显示点云
    % -----------------------------
    function showPointCloud()
        cla(ax);

        if isempty(data.ptCloud)
            return;
        end

        if ~isempty(data.ptCloud.Color)
            pcshow(data.ptCloud, 'Parent', ax);
        else
            pcshow(data.ptCloud.Location, 'Parent', ax);
        end

        title(ax, ['Point Cloud: ' data.fileName], 'Interpreter', 'none');
        xlabel(ax, 'X');
        ylabel(ax, 'Y');
        zlabel(ax, 'Z');
        grid(ax, 'on');
        axis(ax, 'equal');
        view(ax, 3);
    end

    % -----------------------------
    % 回调函数：更新信息
    % -----------------------------
    function updateInfo()
        if isempty(data.ptCloud)
            infoArea.Value = {'No point cloud loaded.'};
            return;
        end

        pts = data.ptCloud.Location;
        numPoints = data.ptCloud.Count;

        x = pts(:,1);
        y = pts(:,2);
        z = pts(:,3);

        minXYZ = [min(x), min(y), min(z)];
        maxXYZ = [max(x), max(y), max(z)];
        rangeXYZ = maxXYZ - minXYZ;
        centerXYZ = mean(pts, 1);

        if ~isempty(data.ptCloud.Color)
            colorInfo = 'Yes';
        else
            colorInfo = 'No';
        end

        infoArea.Value = {
            ['File: ' data.fileName]
            ['Points: ' num2str(numPoints)]
            ['Has Color: ' colorInfo]
            ' '
            ['X Min: ' num2str(minXYZ(1), '%.6f')]
            ['X Max: ' num2str(maxXYZ(1), '%.6f')]
            ['X Range: ' num2str(rangeXYZ(1), '%.6f')]
            ' '
            ['Y Min: ' num2str(minXYZ(2), '%.6f')]
            ['Y Max: ' num2str(maxXYZ(2), '%.6f')]
            ['Y Range: ' num2str(rangeXYZ(2), '%.6f')]
            ' '
            ['Z Min: ' num2str(minXYZ(3), '%.6f')]
            ['Z Max: ' num2str(maxXYZ(3), '%.6f')]
            ['Z Range: ' num2str(rangeXYZ(3), '%.6f')]
            ' '
            ['Center X: ' num2str(centerXYZ(1), '%.6f')]
            ['Center Y: ' num2str(centerXYZ(2), '%.6f')]
            ['Center Z: ' num2str(centerXYZ(3), '%.6f')]
        };
    end

    % -----------------------------
    % 回调函数：下采样
    % -----------------------------
    function downsampleCallback()
        if isempty(data.ptCloudOriginal)
            uialert(fig, 'Please load a point cloud first.', 'Warning');
            return;
        end

        gridSize = editGrid.Value;
        if isempty(gridSize) || gridSize <= 0
            uialert(fig, 'Grid size must be greater than 0.', 'Invalid Input');
            return;
        end

        try
            data.ptCloud = pcdownsample(data.ptCloudOriginal, 'gridAverage', gridSize);
            showPointCloud();
            updateInfo();
        catch ME
            uialert(fig, ['Downsampling failed: ' ME.message], 'Error');
        end
    end

    % -----------------------------
    % 回调函数：重置视角
    % -----------------------------
    function resetViewCallback()
        if isempty(data.ptCloud)
            return;
        end

        view(ax, 3);
        axis(ax, 'equal');
        grid(ax, 'on');
    end

    % -----------------------------
    % 回调函数：保存截图
    % -----------------------------
    function saveScreenshotCallback()
        if isempty(data.ptCloud)
            uialert(fig, 'Please load a point cloud first.', 'Warning');
            return;
        end

        [file, path] = uiputfile({'*.png'; '*.jpg'; '*.tif'}, 'Save Screenshot');
        if isequal(file, 0)
            return;
        end

        fullPath = fullfile(path, file);

        try
            exportgraphics(ax, fullPath, 'Resolution', 300);
            uialert(fig, ['Screenshot saved to:' newline fullPath], 'Success');
        catch ME
            uialert(fig, ['Failed to save screenshot: ' ME.message], 'Save Error');
        end
    end
end
