"""
使用ffmpeg处理视频文件脚本，目前支持功能：
1. -f, --file: 指定输入目标，可以是单个文件、文件夹，或正则表达式
2. -e, --ext: 指定要搜索的视频扩展名，支持多个扩展名
3. -c, --vcodec: 指定使用的视频编码器，默认libx264
4. --crf: 指定CRF视频质量控制参数，默认23
5. --fps: 指定输出视频帧率，例如30、60；不传则保持原视频帧率
6. --resolution: 指定输出分辨率高度，仅支持1080、720、360；宽度按原比例自动缩放
7. --output-ext: 指定输出文件扩展名，例如mp4或.mkv，默认保持原扩展名
8. --suffix: 指定输出文件名的追加后缀，默认_encoded
9. --crop-top-left / --crop-bottom-right: 指定裁剪区域左上角和右下角坐标
10. --start-time / --end-time: 指定提取时间段，支持 h:m:s、m:s 或 s
11. --nvidia: 使用 NVIDIA NVENC 进行硬件加速编码
"""
import argparse
import re
import subprocess
from pathlib import Path
import sys


def normalize_extension(extension):
    """
    标准化扩展名格式，确保以 '.' 开头。
    """
    if extension is None:
        return None
    return extension if extension.startswith('.') else f'.{extension}'


def build_output_path(file_path, suffix, output_ext=None):
    """
    根据输入文件生成输出路径。
    """
    final_ext = normalize_extension(output_ext) or file_path.suffix
    final_name = f"{file_path.stem}{suffix}{final_ext}"
    return file_path.parent / final_name


def parse_time_to_seconds(time_str):
    """
    将 h:m:s / m:s / s 格式解析为秒数。
    """
    if time_str is None:
        return None

    raw = time_str.strip()
    if not raw:
        raise argparse.ArgumentTypeError("时间不能为空。")

    parts = raw.split(':')
    if len(parts) > 3:
        raise argparse.ArgumentTypeError(
            f"无效时间格式: '{time_str}'，仅支持 h:m:s、m:s 或 s。"
        )

    try:
        values = [int(part) for part in parts]
    except ValueError as exc:
        raise argparse.ArgumentTypeError(
            f"无效时间格式: '{time_str}'，时间必须是整数。"
        ) from exc

    if any(value < 0 for value in values):
        raise argparse.ArgumentTypeError(
            f"无效时间格式: '{time_str}'，时间不能为负数。"
        )

    seconds = 0
    for value in values:
        seconds = seconds * 60 + value
    return seconds


def format_seconds(seconds):
    """
    将秒数格式化为 ffmpeg 可接受的 hh:mm:ss。
    """
    hours = seconds // 3600
    minutes = (seconds % 3600) // 60
    secs = seconds % 60
    return f"{hours:02d}:{minutes:02d}:{secs:02d}"


def validate_crop_args(crop_top_left, crop_bottom_right):
    """
    校验并转换裁剪坐标。
    """
    if crop_top_left is None and crop_bottom_right is None:
        return None

    if crop_top_left is None or crop_bottom_right is None:
        raise ValueError("裁剪时必须同时提供 --crop-top-left 和 --crop-bottom-right。")

    x1, y1 = crop_top_left
    x2, y2 = crop_bottom_right

    if x2 <= x1 or y2 <= y1:
        raise ValueError(
            "裁剪坐标无效：右下角坐标必须严格大于左上角坐标。"
        )

    return {
        "x": x1,
        "y": y1,
        "width": x2 - x1,
        "height": y2 - y1,
    }


def has_matching_extension(file_path, extensions):
    """
    判断文件后缀是否在目标扩展名列表中，忽略大小写。
    """
    return file_path.suffix.lower() in {ext.lower() for ext in extensions}


def resolve_input_targets(file_pattern, extensions):
    """
    解析输入目标：
    1. 如果是文件，直接返回该文件
    2. 如果是目录，递归搜索目录内匹配扩展名的文件
    3. 否则按正则表达式匹配当前工作目录下的相对路径
    """
    candidate_path = Path(file_pattern)

    if candidate_path.is_file():
        if not has_matching_extension(candidate_path, extensions):
            raise ValueError(
                f"输入文件扩展名不在目标范围内: '{candidate_path}'"
            )
        return [candidate_path.resolve()], f"单个文件: {candidate_path}"

    if candidate_path.is_dir():
        found_files = [
            path for path in candidate_path.rglob("*")
            if path.is_file() and has_matching_extension(path, extensions)
        ]
        return found_files, f"目录递归: {candidate_path}"

    try:
        pattern = re.compile(file_pattern)
    except re.error as exc:
        raise ValueError(f"既不是有效路径，也不是合法正则表达式: {exc}") from exc

    search_root = Path.cwd()
    found_files = []
    for path in search_root.rglob("*"):
        if not path.is_file():
            continue
        if not has_matching_extension(path, extensions):
            continue

        relative_path = str(path.relative_to(search_root))
        if pattern.search(relative_path):
            found_files.append(path)

    return found_files, f"正则匹配(相对 {search_root}): {file_pattern}"


def resolve_video_codec(vcodec, use_nvidia):
    """
    根据是否启用 NVIDIA 加速，确定最终使用的视频编码器。
    """
    if not use_nvidia:
        return vcodec

    nvenc_codec_map = {
        "libx264": "h264_nvenc",
        "h264": "h264_nvenc",
        "libx265": "hevc_nvenc",
        "hevc": "hevc_nvenc",
    }

    if vcodec in nvenc_codec_map:
        return nvenc_codec_map[vcodec]

    if vcodec.endswith("_nvenc"):
        return vcodec

    raise ValueError(
        "启用 --nvidia 时，--vcodec 仅支持 libx264/h264/libx265/hevc，"
        "或直接传入 *_nvenc 编码器。"
    )


def encode_video(
    input_path,
    output_path,
    vcodec='libx264',
    crf=23,
    fps=None,
    resolution=None,
    crop=None,
    start_time=None,
    end_time=None,
    use_nvidia=False,
):
    """
    调用 ffmpeg 对视频进行重新编码
    """
    # 构建 ffmpeg 命令
    # -y: 直接覆盖已存在的输出文件
    # -c:v: 视频编码器
    # -crf: 恒定速率因子 (0-51，越小质量越高，23 是 x264 的默认值)
    # -vf: 根据需要设置帧率和分辨率滤镜
    # -c:a copy: 复制音频流，不重新编码音频以节省时间并保持音质
    resolved_vcodec = resolve_video_codec(vcodec, use_nvidia)

    video_filters = []
    if fps is not None:
        video_filters.append(f"fps={fps}")
    if resolution is not None:
        # 按高度缩放，并让宽度自动适配为偶数，避免部分编码器报错
        video_filters.append(f"scale=-2:{resolution}")
    if crop is not None:
        video_filters.append(
            f"crop={crop['width']}:{crop['height']}:{crop['x']}:{crop['y']}"
        )
    if resolved_vcodec == "h264_nvenc":
        # h264_nvenc 普遍只支持 8-bit yuv420p，这里显式降位深避免 10-bit 输入报错。
        video_filters.append("format=yuv420p")

    cmd = [
        'ffmpeg',
        '-y',
    ]

    if start_time is not None:
        cmd.extend(['-ss', format_seconds(start_time)])

    cmd.extend([
        '-i', str(input_path),
    ])

    if start_time is not None and end_time is not None:
        clip_duration = end_time - start_time
        cmd.extend(['-t', format_seconds(clip_duration)])
    elif end_time is not None:
        cmd.extend(['-to', format_seconds(end_time)])

    cmd.extend([
        '-c:v', resolved_vcodec,
    ])

    if use_nvidia:
        # NVENC 不支持 CRF，这里将 crf 参数映射到 cq，保持原有使用习惯。
        cmd.extend([
            '-preset', 'p5',
            '-rc', 'vbr',
            '-cq', str(crf),
        ])
    else:
        cmd.extend([
            '-crf', str(crf),
        ])

    if video_filters:
        cmd.extend(['-vf', ','.join(video_filters)])

    cmd.extend([
        '-c:a', 'copy',
        str(output_path)
    ])
    
    print(f"\n[处理中] {input_path.name} -> {output_path.name}")
    try:
        # 通过 Popen 实时读取 ffmpeg 的 stderr，让转码进度即时显示在终端中
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )

        last_progress = ""
        error_lines = []

        for line in process.stderr:
            line = line.strip()
            if not line:
                continue

            if "time=" in line:
                last_progress = line
                print(f"\r[进度] {last_progress}", end="", flush=True)
            else:
                error_lines.append(line)

        return_code = process.wait()
        if last_progress:
            print()

        if return_code != 0:
            raise subprocess.CalledProcessError(return_code, cmd, stderr="\n".join(error_lines))

        print(f"[成功] 编码完成: {output_path.name}")
    except subprocess.CalledProcessError as e:
        print(f"[错误] 编码失败: {input_path.name}")
        print(f"FFmpeg 报错信息:\n{e.stderr}")

def main():
    # 设置 argparse 命令行参数
    parser = argparse.ArgumentParser(description="按文件、目录或正则表达式查找视频，并使用 FFmpeg 重新编码。")
    parser.add_argument("-f", "--file", required=True, help="[必填] 输入目标，可以是单个文件、文件夹，或正则表达式")
    parser.add_argument("-e", "--ext", nargs='+', default=['.mp4'], help="要搜索的视频扩展名，用空格隔开 (默认: .mp4)。例如: -e .mp4 .mkv .avi")
    parser.add_argument("-c", "--vcodec", default="libx264", help="使用的视频编码器 (默认: libx264，可改如 libx265)")
    parser.add_argument("--crf", type=int, default=23, help="CRF 视频质量控制参数，范围通常在 18-28 之间 (默认: 23)")
    parser.add_argument("--fps", type=int, help="输出视频帧率，例如 30、60；不传则保持原视频帧率 (默认原帧率)")
    parser.add_argument("--resolution", type=int, choices=[1080, 720, 360], help="输出分辨率高度，仅支持 1080、720、360；宽度按原比例自动缩放 (默认原分辨率)")
    parser.add_argument("--output-ext", help="输出文件扩展名，例如 mp4 或 .mkv (默认保持原扩展名)")
    parser.add_argument("--suffix", default="_encoded", help="输出文件名的追加后缀 (默认: _encoded)")
    parser.add_argument("--crop-top-left", nargs=2, type=int, metavar=("X1", "Y1"), help="裁剪区域左上角坐标，例如: --crop-top-left 100 50")
    parser.add_argument("--crop-bottom-right", nargs=2, type=int, metavar=("X2", "Y2"), help="裁剪区域右下角坐标，例如: --crop-bottom-right 1820 1030")
    parser.add_argument("--start-time", type=parse_time_to_seconds, help="提取开始时间，支持 h:m:s、m:s 或 s，例如 00:01:30、1:30、90")
    parser.add_argument("--end-time", type=parse_time_to_seconds, help="提取结束时间，支持 h:m:s、m:s 或 s，例如 00:02:10、2:10、130")
    parser.add_argument("--nvidia", action="store_true", help="使用 NVIDIA NVENC 进行硬件加速编码；libx264 会自动切换为 h264_nvenc，libx265 会自动切换为 hevc_nvenc")

    args = parser.parse_args()

    try:
        crop = validate_crop_args(args.crop_top_left, args.crop_bottom_right)
    except ValueError as exc:
        print(f"[错误] {exc}")
        sys.exit(1)

    if args.start_time is not None and args.end_time is not None and args.end_time <= args.start_time:
        print("[错误] 时间范围无效：--end-time 必须大于 --start-time。")
        sys.exit(1)

    try:
        resolved_vcodec = resolve_video_codec(args.vcodec, args.nvidia)
    except ValueError as exc:
        print(f"[错误] {exc}")
        sys.exit(1)

    # 格式化扩展名，确保它们以 '.' 开头
    extensions = [ext if ext.startswith('.') else f'.{ext}' for ext in args.ext]

    try:
        found_files, search_desc = resolve_input_targets(args.file, extensions)
    except ValueError as exc:
        print(f"[错误] {exc}")
        sys.exit(1)

    print(f"输入目标: {args.file}")
    print(f"解析方式: {search_desc}")
    print(f"目标格式: {', '.join(extensions)}")
    print(f"视频编码器: {resolved_vcodec}")
    if args.fps is not None:
        print(f"目标帧率: {args.fps} fps")
    if args.resolution is not None:
        print(f"目标分辨率: {args.resolution}p")
    if args.output_ext:
        print(f"输出扩展名: {normalize_extension(args.output_ext)}")
    if args.nvidia:
        print("硬件加速: NVIDIA NVENC")
    if crop is not None:
        print(
            "裁剪区域: "
            f"左上=({crop['x']}, {crop['y']}), "
            f"右下=({crop['x'] + crop['width']}, {crop['y'] + crop['height']})"
        )
    if args.start_time is not None or args.end_time is not None:
        start_label = format_seconds(args.start_time) if args.start_time is not None else "开头"
        end_label = format_seconds(args.end_time) if args.end_time is not None else "结尾"
        print(f"提取时间段: {start_label} -> {end_label}")

    if not found_files:
        print("没有找到符合条件的视频文件。")
        sys.exit(0)

    found_files = sorted(set(found_files))

    print(f"共找到 {len(found_files)} 个视频文件。开始编码任务...\n")
    print("-" * 40)

    planned_outputs = set()

    for file_path in found_files:
        output_path = build_output_path(file_path, args.suffix, args.output_ext)

        # 输出路径与输入路径相同则跳过，避免覆盖源文件
        if output_path == file_path:
            print(f"[跳过] 输出文件名与源文件相同: {file_path.name}")
            continue

        # 默认命名模式下，跳过已经包含后缀的文件，防止重复编码
        if args.suffix in file_path.stem:
            print(f"[跳过] 该文件似乎已被编码过: {file_path.name}")
            continue

        # 同目录下如果不同源文件会写到同一目标，直接跳过后续冲突项
        if output_path in planned_outputs:
            print(f"[跳过] 输出文件名冲突: {file_path.name} -> {output_path.name}")
            continue
        planned_outputs.add(output_path)
        
        encode_video(
            file_path,
            output_path,
            vcodec=args.vcodec,
            crf=args.crf,
            fps=args.fps,
            resolution=args.resolution,
            crop=crop,
            start_time=args.start_time,
            end_time=args.end_time,
            use_nvidia=args.nvidia,
        )

    print("\n" + "-" * 40)
    print("所有任务处理完毕！")

if __name__ == "__main__":
    main()
