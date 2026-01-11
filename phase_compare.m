%% ================== 1. 读取绝对相位 ==================
N = 74;   % 周期放大系数

% 基准相位
data_base = load('unwrap_128_average_normalized.mat');
phase_base = data_base.phase_data * N;

% 对比相位
data_compare = load('unwrap_h_highest_phase2_original.mat');
phase_compare = data_compare.phase_data;

assert(isequal(size(phase_base), size(phase_compare)), ...
       'Phase size mismatch');

%% ================== 2. 计算误差 ==================
delta_phi = phase_compare - phase_base;

% 误差判定阈值（你可以改）
error_mask = abs(delta_phi) >= 2*pi;

total_points = numel(error_mask);
error_points = sum(error_mask(:));
success_rate = 100 * (1 - error_points / total_points);

fprintf('Success Rate = %.2f %%\n', success_rate);

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

title(sprintf(['3D Absolute Phase Comparison\n' ...
               'Error points highlighted with RED spikes | Success Rate = %.2f %%'], ...
               success_rate));

hold off;
