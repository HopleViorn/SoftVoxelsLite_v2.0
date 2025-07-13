from moviepy import VideoFileClip
import os

def convert_mp4_to_gif(mp4_path, gif_path, fps=10, loop=0):
    """
    将 MP4 视频转换为 GIF 动画。

    Args:
        mp4_path (str): 输入 MP4 文件的路径。
        gif_path (str): 输出 GIF 文件的路径。
        fps (int): GIF 的帧率（每秒帧数）。
        loop (int): GIF 循环次数。0 表示无限循环。
    """
    try:
        clip = VideoFileClip(mp4_path)
        clip.write_gif(gif_path, fps=fps, loop=loop)
        clip.close()
        print(f"成功将 '{mp4_path}' 转换为 '{gif_path}'")
    except Exception as e:
        print(f"转换失败: {e}")

if __name__ == "__main__":
    # 示例用法
    # 请将 'input.mp4' 替换为您的 MP4 文件路径
    # 将 'output.gif' 替换为您希望保存的 GIF 文件路径
    
    # 检查是否提供了命令行参数
    import sys
    if len(sys.argv) == 3:
        input_mp4 = sys.argv[1]
        output_gif = sys.argv[2]
        convert_mp4_to_gif(input_mp4, output_gif)
    elif len(sys.argv) == 1:
        print("用法: python mp4_to_gif.py <输入MP4文件路径> <输出GIF文件路径>")
        print("示例: python mp4_to_gif.py input.mp4 output.gif")
    else:
        print("参数错误。用法: python mp4_to_gif.py <输入MP4文件路径> <输出GIF文件路径>")
