%% ================== 1. 读取绝对相位 ==================
N = 64;   % 周期放大系数

% 基准相位
data_base = load('unwrap_128_average_normalized.mat');
phase_base = data_base.phase_data * N;

% 对比相位
data_compare = load('unwrap_h_highest_phase_59-61-64_original.mat');
phase_compare = data_compare.phase_data;

assert(isequal(size(phase_base), size(phase_compare)), ...
       'Phase size mismatch');

%% ================== 2. 计算误差 ==================
delta_phi = phase_compare - phase_base;

% 检查数据中的 NaN 和 Inf 值
nan_count = sum(isnan(delta_phi(:)));
inf_count = sum(isinf(delta_phi(:)));
valid_mask = ~isnan(delta_phi) & ~isinf(delta_phi);
valid_count = sum(valid_mask(:));

% 输出数据质量信息
fprintf('%s\n', repmat('=', 1, 70));
fprintf('数据质量检查:\n');
fprintf('  总数据点数: %d\n', numel(delta_phi));
fprintf('  有效数据点: %d\n', valid_count);
fprintf('  NaN 数据点: %d\n', nan_count);
fprintf('  Inf 数据点: %d\n', inf_count);
fprintf('%s\n', repmat('=', 1, 70));

% 计算误差的 RMS（均方根），排除 NaN 和 Inf 值
if valid_count > 0
    delta_phi_valid = delta_phi(valid_mask);
    rms_error = sqrt(mean(delta_phi_valid.^2));
    rms_error_deg = rms_error * 180 / pi;  % 转换为度
else
    warning('没有有效数据点，无法计算 RMS');
    rms_error = NaN;
    rms_error_deg = NaN;
end

% 误差判定阈值（你可以改）
error_mask = abs(delta_phi) >= 2*pi & valid_mask;  % 用于可视化（3D图中的红色spikes）和 Success Rate 计算

% 用于统计的误差点：使用 π 作为阈值（仅用于 Error Points 统计计算）
error_mask_stats = abs(delta_phi) >= pi & valid_mask;  % 大于 π 的点算作误差点

total_points = sum(valid_mask(:));  % 只统计有效数据点

% Success Rate 使用 error_mask（>= 2π）计算
error_points_for_success = sum(error_mask(:));
success_rate = 100 * (1 - error_points_for_success / total_points);

% Error Points 使用 error_mask_stats（>= π）计算
error_points = sum(error_mask_stats(:));

% 输出统计信息
fprintf('%s\n', repmat('=', 1, 70));
fprintf('误差统计信息:\n');
fprintf('%s\n', repmat('=', 1, 70));
fprintf('Success Rate = %.2f %%\n', success_rate);
fprintf('RMS Error = %.6f rad (%.4f°)\n', rms_error, rms_error_deg);
fprintf('Error Points = %d / %d (%.2f %%)\n', error_points, total_points, ...
        100 * error_points / total_points);
fprintf('%s\n', repmat('=', 1, 70));

%% ================== 3. 3D 误差可视化 ==================
figure;
hold on;

%% 3.1 主体：完整对比绝对相位曲面
surf(phase_compare, ...
     'EdgeColor','none');
shading interp;

colormap(parula);
colorbar;

%% 3.2 误差区域：用红色垂直线条（spikes）标记误差点
% 找到所有误差点的位置
[error_y, error_x] = find(error_mask);
error_z = phase_compare(error_mask);  % 获取误差点的相位值

% 使用 stem3 绘制红色垂直线条，从表面（z=0）到该点的相位值
if ~isempty(error_x)
    stem3(error_x, error_y, error_z, ...
          'Color', 'red', ...
          'LineWidth', 0.5, ...
          'Marker', 'none');  % 不显示标记点，只显示线条
end

%% 3.3 视角与标注
view(3);
axis tight;

xlabel('X');
ylabel('Y');
zlabel('Absolute Phase (rad)');

title(sprintf('3D Absolute Phase Comparison\nSuccess Rate = %.2f %%', ...
               success_rate));

hold off;