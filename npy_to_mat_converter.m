%% ================== .npy 文件转 .mat 文件转换器 ==================
% 功能：读取 NumPy .npy 文件并将其保存为 MATLAB .mat 文件
% 要求：系统需要安装 Python 和 numpy 库
%
% 使用方法：
%   1. 修改下面的输入文件路径（npy_file_path）
%   2. 可选：修改输出文件路径（output_file_path），如果不指定则自动生成
%   3. 可选：修改变量名（variable_name），默认为 'data'
%   4. 运行脚本

clc;
clear;
close all;

%% ================== 1. 配置参数 ==================

% 输入：.npy 文件路径（修改为你的文件路径）
npy_file_path = 'your_file.npy';  % ← 修改为你的 .npy 文件路径

% 输出：.mat 文件路径（可选，如果为空则自动生成）
output_file_path = '';  % 例如: 'output_data.mat'

% 输出变量名（保存到 .mat 文件中的变量名）
variable_name = 'phase_data';  % 可选: 'phase_data', 'phase', 'data' 等

%% ================== 2. 检查 Python 环境 ==================

fprintf('%s\n', repmat('=', 1, 70));
fprintf('检查 Python 环境...\n');
fprintf('%s\n', repmat('=', 1, 70));

% 检查 Python 是否可用
try
    pyversion;
    python_version = pyversion;
    fprintf('✓ Python 版本: %s\n', python_version);
catch
    error('错误: 未检测到 Python 环境。请确保已安装 Python 并在 MATLAB 中配置。\n使用方法: pyversion("path_to_python_executable")');
end

% 检查 numpy 是否可用
try
    py.importlib.import_module('numpy');
    fprintf('✓ NumPy 库可用\n');
catch
    error('错误: NumPy 库不可用。请安装 NumPy: pip install numpy');
end

fprintf('%s\n', repmat('=', 1, 70));
fprintf('\n');

%% ================== 3. 读取 .npy 文件 ==================

% 检查输入文件是否存在
if ~exist(npy_file_path, 'file')
    error('错误: 找不到输入文件 "%s"', npy_file_path);
end

fprintf('%s\n', repmat('=', 1, 70));
fprintf('读取 .npy 文件...\n');
fprintf('%s\n', repmat('=', 1, 70));
fprintf('输入文件: %s\n', npy_file_path);

try
    % 使用 Python 读取 .npy 文件
    py_data = py.numpy.load(npy_file_path);
    
    % 获取原始数组的形状
    % 使用 numpy 数组的 shape 属性
    py_shape = py_data.shape;
    shape_cell = cell(py_shape);
    shape = cellfun(@int64, shape_cell);
    
    % 将 Python numpy 数组转换为 MATLAB 数组
    % 方法1：使用 tolist() 方法（适用于大多数情况）
    try
        data_list = py_data.tolist();
        data = double(data_list);
    catch
        % 方法2：如果 tolist() 失败，使用 ndarray 的 flat 迭代器
        data_flat = py_data.flatten().tolist();
        data = double(data_flat);
        data = reshape(data, shape);
    end
    
    % 处理维度顺序：NumPy 是行主序 (C-order)，MATLAB 是列主序 (F-order)
    % 对于 2D 及以上数组，需要转置以匹配 MATLAB 的列主序
    if length(shape) >= 2
        % 转置前两个维度
        if length(shape) == 2
            data = data';
        elseif length(shape) == 3
            data = permute(data, [2, 1, 3]);
        else
            % 对于更高维度，转置前两个维度
            permute_order = [2, 1, 3:length(shape)];
            data = permute(data, permute_order);
        end
    end
    
    fprintf('✓ 文件读取成功\n');
    fprintf('  原始形状 (NumPy): [%s]\n', num2str(shape));
    fprintf('  MATLAB 形状: [%s]\n', num2str(size(data)));
    fprintf('  数据类型: %s\n', class(data));
    fprintf('  数据范围: [%.6f, %.6f]\n', min(data(:)), max(data(:)));
    
catch ME
    error('读取文件时出错: %s\n请确保文件是有效的 .npy 格式。', ME.message);
end

fprintf('%s\n', repmat('=', 1, 70));
fprintf('\n');

%% ================== 4. 生成输出文件路径 ==================

if isempty(output_file_path)
    % 自动生成输出文件名（将 .npy 扩展名替换为 .mat）
    [file_dir, file_name, ~] = fileparts(npy_file_path);
    output_file_path = fullfile(file_dir, [file_name, '.mat']);
end

fprintf('%s\n', repmat('=', 1, 70));
fprintf('保存 .mat 文件...\n');
fprintf('%s\n', repmat('=', 1, 70));
fprintf('输出文件: %s\n', output_file_path);
fprintf('变量名: %s\n', variable_name);

%% ================== 5. 保存为 .mat 文件 ==================

try
    % 创建结构体或直接保存变量
    % 方式1：直接保存变量（推荐）
    eval(sprintf('%s = data;', variable_name));
    save(output_file_path, variable_name, '-v7.3');  % 使用 v7.3 格式支持大文件
    
    % 或者方式2：保存为结构体（如果变量名包含特殊字符）
    % data_struct = struct();
    % data_struct.(variable_name) = data;
    % save(output_file_path, '-struct', 'data_struct', '-v7.3');
    
    fprintf('✓ 文件保存成功\n');
    
catch ME
    error('保存文件时出错: %s', ME.message);
end

fprintf('%s\n', repmat('=', 1, 70));
fprintf('✓ 转换完成！\n');
fprintf('%s\n', repmat('=', 1, 70));

%% ================== 6. 验证保存的文件（可选）==================

fprintf('\n验证保存的文件...\n');
try
    loaded_data = load(output_file_path);
    if isfield(loaded_data, variable_name)
        verify_data = loaded_data.(variable_name);
        if isequal(data, verify_data)
            fprintf('✓ 验证通过：保存的数据与原始数据一致\n');
        else
            warning('警告：保存的数据与原始数据不完全一致（可能是数值精度问题）\n');
        end
        fprintf('  验证数据形状: [%s]\n', num2str(size(verify_data)));
    else
        warning('警告：无法找到变量 "%s" 在保存的文件中\n', variable_name);
    end
catch ME
    warning('验证时出错: %s\n', ME.message);
end

fprintf('\n完成！\n');
