%% ================== 1. 读取多个包裹相位 .mat 文件 ==================
clc;
clear;
close all;

% 1.1 配置多个相位文件（修改为你的文件名和标签）
% 方式1：使用cell数组存储文件路径和标签
% phase_files = {
%     'wrapped_phase1.mat', '基准包裹相位';  % 第一个文件（基准相位，红色）
%     'wrapped_phase2.mat', '对比包裹相位1';
%     % 可以添加更多文件
%     % 'wrapped_phase3.mat', '对比包裹相位2';
% };

% 或者方式2：如果只有一个文件，可以这样使用：
phase_files = {
    'h_middle1_phase_wrapped.mat', '包裹相位1';
};

% 1.2 加载所有相位数据
num_phases = size(phase_files, 1);
phases = cell(num_phases, 1);
labels = cell(num_phases, 1);

fprintf('%s\n', repmat('=', 1, 70));
fprintf('加载 %d 个包裹相位文件...\n', num_phases);
fprintf('%s\n', repmat('=', 1, 70));
for i = 1:num_phases
    file_path = phase_files{i, 1};
    label = phase_files{i, 2};
    
    fprintf('\n[%d/%d] 加载文件: %s\n', i, num_phases, file_path);
    
    % 加载数据
    data = load(file_path);
    
    % 取出相位变量（根据实际变量名修改）
    if isfield(data, 'phase_data')
        phase = data.phase_data;
    elseif isfield(data, 'phase')
        phase = data.phase;
    elseif isfield(data, 'wrapped_phase')
        phase = data.wrapped_phase;
    else
        % 如果变量名不确定，尝试使用第一个字段
        field_names = fieldnames(data);
        if ~isempty(field_names)
            phase = data.(field_names{1});
            fprintf('  警告: 使用第一个字段 "%s" 作为相位数据\n', field_names{1});
        else
            error('无法找到相位数据变量');
        end
    end
    
    % 基本检查
    assert(ismatrix(phase), 'Loaded phase data must be a 2D matrix.');
    
    phases{i} = phase;
    labels{i} = label;
    
    % 输出信息
    phase_min = min(phase(:));
    phase_max = max(phase(:));
    fprintf('  标签: %s\n', label);
    fprintf('  形状: [%d, %d]\n', size(phase, 1), size(phase, 2));
    fprintf('  相位范围: [%.4f, %.4f] rad (%.2fπ - %.2fπ)\n', ...
            phase_min, phase_max, phase_min/pi, phase_max/pi);
    
    % 检测是否为典型的包裹相位范围（-π到π或0到2π）
    if phase_min >= -pi && phase_max <= pi
        fprintf('  检测到包裹相位范围: [-π, π]\n');
    elseif phase_min >= 0 && phase_max <= 2*pi
        fprintf('  检测到包裹相位范围: [0, 2π]\n');
    else
        fprintf('  注意: 相位范围可能超出典型包裹相位范围\n');
    end
end
fprintf('%s\n', repmat('=', 1, 70));
fprintf('✓ 所有包裹相位文件加载完成\n\n');

%% ================== 2. 3D 包裹相位可视化（多个相位分别显示）==================
fprintf('%s\n', repmat('=', 1, 70));
fprintf('生成3D表面图...\n');
fprintf('%s\n', repmat('=', 1, 70));

for i = 1:num_phases
    phase = phases{i};
    label = labels{i};
    
    phase_min = min(phase(:));
    phase_max = max(phase(:));
    
    fprintf('\n[%d/%d] 生成3D表面图: %s\n', i, num_phases, label);
    
    figure;
    
    % 画三维相位曲面
    surf(phase, 'EdgeColor', 'none');
    shading interp;
    
    % 颜色与色条（包裹相位推荐使用hsv或jet，因为相位是循环的）
    % hsv颜色映射对包裹相位特别有用，因为它也是循环的
    colormap(parula);   % 可换：jet / parula / turbo
    colorbar;
    
    % 如果相位范围是 -π 到 π，可以设置颜色条范围
    if phase_min >= -pi && phase_max <= pi
        caxis([-pi, pi]);
    elseif phase_min >= 0 && phase_max <= 2*pi
        caxis([0, 2*pi]);
    end
    
    % 视角与坐标
    view(3);
    axis tight;
    
    xlabel('X (pixel)', 'FontSize', 12);
    ylabel('Y (pixel)', 'FontSize', 12);
    zlabel('Wrapped Phase (rad)', 'FontSize', 12);
    
    % 标题
    title(sprintf('%s - 3D表面图 [%.2fπ , %.2fπ]', ...
          label, phase_min/pi, phase_max/pi), 'FontSize', 14);
end

fprintf('\n✓ 所有3D表面图生成完成\n');

%% ================== 3. 选择纵坐标并比较相位变化曲线（2D图）==================
% 3.1 选择行索引（纵坐标）
% 方式1：直接指定行索引（取消注释并设置值）
% row_index = 1024;  % ← 指定具体的行索引

% 方式2：根据位置自动选择（默认使用中心位置）
position = 'center';  % 可选: 'top', 'bottom', 'center', 'quarter', 'three_quarter'

% 使用第一个相位来确定尺寸和行索引
first_phase = phases{1};
[height, width] = size(first_phase);

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

fprintf('\n%s\n', repmat('=', 1, 70));
fprintf('生成包裹相位变化曲线比较图...\n');
fprintf('%s\n', repmat('=', 1, 70));
fprintf('\n选择行索引（纵坐标）: %d (位置: %s)\n', row_index, position);

% 3.2 提取所有相位的行数据并计算统计信息
line_data_list = cell(num_phases, 1);
wrapping_counts = zeros(num_phases, 1);  % 记录相位跳跃次数

% 确定最小宽度（确保所有相位长度一致）
min_width = width;
for i = 1:num_phases
    [h, w] = size(phases{i});
    min_width = min(min_width, w);
end

column_indices = 1:min_width;

for i = 1:num_phases
    phase = phases{i};
    label = labels{i};
    
    % 提取行数据
    [h, w] = size(phase);
    row_idx = min(row_index, h);  % 确保行索引有效
    line_data = phase(row_idx, 1:min_width);
    line_data_list{i} = line_data;
    
    % 检测相位跳跃（包裹相位特有的特征）
    % 计算相邻点之间的相位差
    phase_diff = diff(line_data);
    
    % 对于包裹相位，相位跳跃通常发生在边界处：
    % -π 到 π 范围：从 π 跳到 -π（差值接近 2π）或从 -π 跳到 π（差值接近 -2π）
    % 0 到 2π 范围：从 2π 跳到 0（差值接近 -2π）或从 0 跳到 2π（差值接近 2π）
    % 因此，使用 π 作为阈值来检测这些大的相位跳跃
    jump_threshold = pi;
    
    % 统计大的相位跳跃（绝对值大于阈值）
    % 注意：对于包裹相位，真正的跳跃是接近 ±2π 的差值，但使用 π 作为阈值可以检测到这些跳跃
    large_jumps = abs(phase_diff) > jump_threshold;
    wrapping_counts(i) = sum(large_jumps);
    
    % 输出统计信息
    line_min = min(line_data(:));
    line_max = max(line_data(:));
    line_mean = mean(line_data(~isnan(line_data)));
    line_std = std(line_data(~isnan(line_data)));
    
    fprintf('\n[%d] %s:\n', i, label);
    fprintf('  相位范围: [%.4f, %.4f] rad\n', line_min, line_max);
    fprintf('  平均值: %.4f rad\n', line_mean);
    fprintf('  标准差: %.4f rad\n', line_std);
    fprintf('  相位跳跃次数: %d\n', wrapping_counts(i));
end

% 3.3 创建比较图（所有相位在一个图上）
figure;

% 定义鲜艳的颜色列表（基准相位为红色，其他使用鲜艳颜色）
bright_colors = {'red', 'blue', 'green', 'orange', 'purple', 'cyan', ...
                 'magenta', [0.9290 0.6940 0.1250], [0.4940 0.1840 0.5560], ...
                 [0.3010 0.7450 0.9330], [0.6350 0.0780 0.1840], ...
                 [0.4660 0.6740 0.1880], [0 0.4470 0.7410]};

% 为每个相位分配颜色
colors = cell(num_phases, 1);
colors{1} = 'red';  % 基准相位使用红色
for i = 2:num_phases
    color_idx = mod(i - 2, length(bright_colors) - 1) + 2;  % 跳过红色
    colors{i} = bright_colors{color_idx};
end

% 绘制所有相位曲线
hold on;
for i = 1:num_phases
    line_data = line_data_list{i};
    label = labels{i};
    color = colors{i};
    
    % 基准相位（第一个）使用较粗的线宽
    if i == 1
        linewidth = 2.0;
    else
        linewidth = 1.5;
    end
    
    plot(column_indices, line_data, '-', 'LineWidth', linewidth, ...
         'Color', color, 'DisplayName', ...
         sprintf('%s (跳跃: %d次)', label, wrapping_counts(i)));
end

% 添加相位边界线（如果相位范围是 -π 到 π 或 0 到 2π）
first_phase_min = min(line_data_list{1}(:));
first_phase_max = max(line_data_list{1}(:));
if first_phase_min >= -pi - 0.1 && first_phase_max <= pi + 0.1
    % 绘制 -π 和 π 参考线
    plot([1, min_width], [-pi, -pi], '--k', 'LineWidth', 1, ...
         'DisplayName', '-π', 'HandleVisibility', 'off');
    plot([1, min_width], [pi, pi], '--k', 'LineWidth', 1, ...
         'DisplayName', 'π', 'HandleVisibility', 'off');
    ylim([-pi*1.1, pi*1.1]);
elseif first_phase_min >= -0.1 && first_phase_max <= 2*pi + 0.1
    % 绘制 0 和 2π 参考线
    plot([1, min_width], [0, 0], '--k', 'LineWidth', 1, ...
         'DisplayName', '0', 'HandleVisibility', 'off');
    plot([1, min_width], [2*pi, 2*pi], '--k', 'LineWidth', 1, ...
         'DisplayName', '2π', 'HandleVisibility', 'off');
    ylim([-0.1, 2*pi + 0.1]);
end

% 设置图形属性
title(sprintf('多包裹相位变化曲线比较 - 第 %d 行（%s位置）', row_index, position), ...
      'FontSize', 16);
xlabel('列索引 (pixels)', 'FontSize', 14);
ylabel('包裹相位值 (rad)', 'FontSize', 14);
grid on;
grid minor;
legend('Location', 'best', 'FontSize', 11);
hold off;

fprintf('\n%s\n', repmat('=', 1, 70));
fprintf('✓ 包裹相位变化曲线比较图生成完成\n');
fprintf('%s\n', repmat('=', 1, 70));

% 3.4 保存图像（可选，取消注释以保存）
% save_path = sprintf('wrapped_phase_comparison_row_%d.png', row_index);
% print(gcf, save_path, '-dpng', '-r400');
% fprintf('\n✓ 比较图已保存: %s\n', save_path);
