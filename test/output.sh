#!/bin/bash

# 设置文件夹的路径
folder_path="/home/njl/Learn/seaport/seaport/test/utils"
# 设置输出文件的路径
output_file="./merged_content.txt"

# 检查输出文件所在的文件夹是否存在，如果不存在，则创建
if [ ! -d "$(dirname "$output_file")" ]; then
    mkdir -p "$(dirname "$output_file")"
fi

# 检查输出文件是否已存在，如果存在，则删除
if [ -f "$output_file" ]; then
    rm "$output_file"
fi

# 使用find命令遍历所有文件
find "$folder_path" -type f | while read file; do
    # 生成相对于folder_path的路径
    relative_path="${file#$folder_path/}"
    # 在输出文件中添加来自哪个文件的说明（使用相对路径）
    echo "----- Begin of $relative_path -----" >> "$output_file"
    # 将文件内容追加到输出文件
    cat "$file" >> "$output_file"
    # 在文件内容后添加分隔符，表示该文件内容的结束
    echo "----- End of $relative_path -----" >> "$output_file"
    echo "" >> "$output_file" # 添加空行作为额外的分隔，增加可读性
done

echo "所有文件（包括子文件夹中的文件）的内容已合并到 $output_file，每部分内容前后均标明了来源文件的相对路径。"



