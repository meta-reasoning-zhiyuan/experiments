#!/bin/bash
#SBATCH --job-name=logic_252_8192               # 作业名称
#SBATCH --output=logic_train_output_252_3_8192.log # 标准输出日志文件
#SBATCH --error=logic_train_output_252_3_8192.log  # 错误日志文件（与标准输出分开）
#SBATCH --ntasks=1                      # 任务数
#SBATCH --cpus-per-task=64               # 每个任务的 CPU 核数
#SBATCH --mem=1024G                      # 总内存分配（优化为 512GB）
#SBATCH --time=3-00:00:00               # 最大运行时间 3 天
#SBATCH --partition=ml.p5.48xlarge     # 指定计算分区
#SBATCH --nodelist=ip-10-1-17-175
#SBATCH --gres=gpu:8                    # 请求 1 个 GPU，确保与 `ml.p5.48xlarge` 兼容

echo "[$(date)] 作业开始执行..."

# 1. 激活 Conda 环境
echo "[$(date)] 激活 Conda 环境..."
export PATH=/fsx/home/zhiyuan/anaconda3/bin:$PATH
source /fsx/home/zhiyuan/anaconda3/etc/profile.d/conda.sh
conda activate verl

echo "[$(date)] 激活 Conda 环境完成，资源信息："
echo "可用 CPU 数量: $(nproc)"
echo "可用 GPU 列表:"
nvidia-smi -L

# 2. 修复 libstdc++ 兼容性问题
echo "[$(date)] 确保 libstdc++ 版本兼容..."
conda install -c conda-forge libstdcxx-ng -y
export LD_LIBRARY_PATH=$CONDA_PREFIX/lib:$LD_LIBRARY_PATH
echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
ls -l $CONDA_PREFIX/lib/libstdc++.so.6

# 3. 确保 CUDA 兼容
echo "[$(date)] 确保 CUDA 12.2 兼容..."
export CUDA_HOME=/usr/local/cuda-12.2
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
nvcc --version

# 4. 检查 GPU 资源
echo "[$(date)] 检查 GPU 可用性..."
nvidia-smi

# echo "[$(date)] 启动 GPU 使用率监控..."
# while true; do
#     nvidia-smi > /fsx/home/zhiyuan/gpu_usage.log
#     sleep 2
# done &
# GPU_MONITOR_PID=$!
# echo "GPU 监控进程 PID: $GPU_MONITOR_PID"

echo "[$(date)] 启动 GPU 使用率监控..."
while true; do
    nvidia-smi >> /fsx/home/zhiyuan/logic-rl-formula-mix-tasks/gpu_usage.log  # 使用 >> 追加日志
    sleep 2
done &
GPU_MONITOR_PID=$!
echo "GPU 监控进程 PID: $GPU_MONITOR_PID"


# 5. 启动 Ray
echo "[$(date)] 检查 Ray 状态..."
if ray status >/dev/null 2>&1; then
    echo "[$(date)] Ray 已经在运行，跳过启动步骤。"
else
    echo "[$(date)] Ray 未运行，正在启动..."
    ray start --head --temp-dir=/fsx/home/zhiyuan/my_ray_tmp
fi
# echo "[$(date)] 检查 Ray 状态..."
# if ss -tulnp | grep -q ":6379"; then
#     echo "[$(date)] Ray 已经在运行，跳过启动步骤。"
# else
#     echo "[$(date)] Ray 未运行，正在启动..."
#     ray start --head --temp-dir=/fsx/home/zhiyuan/my_ray_tmp
# fi


# 切换到指定目录并执行脚本，同时使用 tee 记录输出
cd /fsx/home/zhiyuan/logic-rl-formula-mix-tasks
echo "[$(date)] 执行 curriculm_final.sh 脚本..."
sh curriculm_final_logic.sh | tee /fsx/home/zhiyuan/logic-rl-formula-mix-tasks/curriculm_final_output.log

# 程序执行完毕后，结束 GPU 监控进程
echo "[$(date)] 程序执行完毕，停止 GPU 使用率监控..."
kill $GPU_MONITOR_PID

echo "[$(date)] 作业结束."