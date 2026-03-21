clc;
clear;
close all;

%% 1. 选择 .mat 文件
[file, path] = uigetfile('*.mat', 'Select a MAT file');
if isequal(file, 0)
    disp('No file selected.');
    return;
end

fullFileName = fullfile(path, file);

%% 2. 查看文件中的变量信息
vars = whos('-file', fullFileName);

disp('Variables in MAT file:');
for i = 1:length(vars)
    fprintf('%d. Name: %s | Size: ', i, vars(i).name);
    fprintf('%dx', vars(i).size(1:end-1));
    fprintf('%d', vars(i).size(end));
    fprintf(' | Class: %s\n', vars(i).class);
end

%% 3. 载入数据
data = load(fullFileName);

% 获取变量名
varNames = fieldnames(data);

if isempty(varNames)
    disp('No variables found in the MAT file.');
    return;
end

%% 4. 让用户选择要可视化的变量
disp(' ');
idx = input('Enter the variable index to visualize: ');

if isempty(idx) || idx < 1 || idx > length(vars)
    disp('Invalid index.');
    return;
end

varName = vars(idx).name;
value = data.(varName);

fprintf('Selected variable: %s\n', varName);

%% 5. 自动可视化
figure('Name', ['Visualization of ', varName], 'Color', 'w');

if isnumeric(value) || islogical(value)
    dims = ndims(value);
    sz = size(value);

    if isvector(value)
        % 1D vector
        plot(value, 'LineWidth', 1.5);
        grid on;
        title(['1D Vector: ', varName], 'Interpreter', 'none');
        xlabel('Index');
        ylabel('Value');

    elseif ismatrix(value)
        % 2D matrix
        if sz(1) == 1 || sz(2) == 1
            plot(value, 'LineWidth', 1.5);
            grid on;
            title(['Vector: ', varName], 'Interpreter', 'none');
            xlabel('Index');
            ylabel('Value');
        else
            imagesc(value);
            colorbar;
            axis image;
            title(['2D Matrix: ', varName], 'Interpreter', 'none');
            xlabel('Column');
            ylabel('Row');
        end

    elseif dims == 3
        % 3D matrix: show middle slice
        sliceIdx = round(sz(3) / 2);
        imagesc(value(:, :, sliceIdx));
        colorbar;
        axis image;
        title(sprintf('3D Matrix Slice of %s (slice %d)', varName, sliceIdx), ...
              'Interpreter', 'none');
        xlabel('Column');
        ylabel('Row');

    else
        disp('Data has more than 3 dimensions, cannot visualize automatically.');
    end

elseif isstruct(value)
    % 结构体处理
    fields = fieldnames(value);
    disp('This variable is a struct. Fields are:');
    disp(fields);

    % 尝试寻找第一个数值字段进行显示
    shown = false;
    for k = 1:length(fields)
        f = fields{k};
        try
            fieldValue = value(1).(f);
            if isnumeric(fieldValue) || islogical(fieldValue)
                if isvector(fieldValue)
                    plot(fieldValue, 'LineWidth', 1.5);
                    grid on;
                    title(['Struct field: ', varName, '.', f], 'Interpreter', 'none');
                    xlabel('Index');
                    ylabel('Value');
                    shown = true;
                    break;
                elseif ismatrix(fieldValue)
                    imagesc(fieldValue);
                    colorbar;
                    axis image;
                    title(['Struct field: ', varName, '.', f], 'Interpreter', 'none');
                    xlabel('Column');
                    ylabel('Row');
                    shown = true;
                    break;
                end
            end
        catch
        end
    end

    if ~shown
        disp('No numeric field found in struct for automatic visualization.');
    end

elseif iscell(value)
    disp('This variable is a cell array. Automatic visualization is not implemented.');
    disp('You may inspect its contents manually using:');
    fprintf('%s{1}\n', varName);

else
    disp(['Unsupported data type: ', class(value)]);
end
