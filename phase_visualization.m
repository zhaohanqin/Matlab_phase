%% ================== 1. 读取绝对相位 .mat 文件 ==================
clc;
clear;
close all;

% 1.1 加载数据（修改为你的文件名）
data = load('unwrap_128_average_normalized.mat');   % ← 改成你的 .mat 文件名

% 1.2 取出相位变量（根据实际变量名修改）
phase = data.phase_data;             % ← 常见命名：phase / phase_data / abs_phase
% phase = phase / 111;

% 基本检查
assert(ismatrix(phase), 'Loaded phase data must be a 2D matrix.');

%% ================== 2. 数值范围检查（强烈推荐） ==================
phase_min = min(phase(:));
phase_max = max(phase(:));

fprintf('Absolute phase range:\n');
fprintf('  Min = %.6f rad (%.3fπ)\n', phase_min, phase_min/pi);
fprintf('  Max = %.6f rad (%.3fπ)\n', phase_max, phase_max/pi);
fprintf('  Peak-to-peak = %.6f rad (%.3fπ)\n', ...
        phase_max - phase_min, (phase_max - phase_min)/pi);

%% ================== 3. 3D 绝对相位可视化 ==================
figure;

% 3.1 画三维相位曲面
surf(phase, 'EdgeColor', 'none');
shading interp;

% 3.2 颜色与色条
colormap(parula);   % 可换：jet / turbo / viridis
colorbar;

% 3.3 视角与坐标
view(3);
axis tight;

xlabel('X (pixel)');
ylabel('Y (pixel)');
zlabel('Absolute Phase (rad)');

% 3.4 标题（推荐）
title(sprintf('Absolute Phase Map  [%.2fπ , %.2fπ]', ...
      phase_min/pi, phase_max/pi));

%% ================== 4. 选择纵坐标并显示相位变化曲线（2D图）==================
% 4.1 选择行索引（纵坐标）
% 方式1：直接指定行索引（取消注释并设置值）
% row_index = 1024;  % ← 指定具体的行索引

% 方式2：根据位置自动选择（默认使用中心位置）
position = 'center';  % 可选: 'top', 'bottom', 'center', 'quarter', 'three_quarter'
[height, width] = size(phase);
if ~exist('row_index', 'var') || isempty(row_index)
    switch position
        case 'top'
            row_index = round(height / 10);  % 接近顶部
        case 'bottom'
            row_index = round(height * 9 / 10);  % 接近底部
        case 'center'
            row_index = round(height / 2);  % 中心
        case 'quarter'
            row_index = round(height / 4);  % 1/4位置
        case 'three_quarter'
            row_index = round(height * 3 / 4);  % 3/4位置
        otherwise
            row_index = round(height / 2);  % 默认中心
    end
end

% 确保行索引在有效范围内
row_index = max(1, min(row_index, height));  % MATLAB索引从1开始

% 4.2 提取该行的相位数据
line_data = phase(row_index, :);

% 4.3 计算统计信息
line_min = min(line_data(:));
line_max = max(line_data(:));
line_mean = mean(line_data(:));
line_std = std(line_data(:));

% 输出信息
fprintf('\n正在生成相位变化曲线图...\n');
fprintf('  选择行索引（纵坐标）: %d (位置: %s)\n', row_index, position);
fprintf('  相位范围: [%.4f, %.4f] rad\n', line_min, line_max);
fprintf('  相位变化: %.4f rad\n', line_max - line_min);
fprintf('  平均值: %.4f rad\n', line_mean);
fprintf('  标准差: %.4f rad\n', line_std);

% 4.4 创建2D曲线图
figure;

% 绘制相位变化曲线
column_indices = 1:width;
plot(column_indices, line_data, 'b-', 'LineWidth', 1.5);

% 添加平均值线
hold on;
plot([1, width], [line_mean, line_mean], '--r', 'LineWidth', 2, ...
     'DisplayName', sprintf('平均值: %.4f', line_mean));

% 设置图形属性
title(sprintf('绝对相位变化曲线 - 第 %d 行（%s位置）', row_index, position), ...
      'FontSize', 16);
xlabel('列索引 (pixels)', 'FontSize', 14);
ylabel('相位值 (rad)', 'FontSize', 14);
grid on;
grid minor;
legend('Location', 'best', 'FontSize', 12);
hold off;

% 4.5 保存图像（可选，取消注释以保存）
% save_path = sprintf('phase_line_profile_row_%d.png', row_index);
% print(gcf, save_path, '-dpng', '-r400');
% fprintf('✓ 相位变化曲线图已保存: %s\n', save_path);

fprintf('✓ 相位变化曲线图生成完成\n');