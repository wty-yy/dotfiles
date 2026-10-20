#!/usr/bin/env python3
"""Batch compress images with the official TinyPNG API and keep *_origin backups.

Overview:
    Prompt for a hidden API key on first use, then save and reuse it.
    Optionally resize locally with Pillow before uploading to the API.
    Support PNG, JPG/JPEG, WebP, AVIF, and JXL (case-insensitive extension matching).
    Rename photo.png to photo_origin.png and save the compressed image as photo.png.

Quick Start:
    python3 tinyimg.py /path/to/images
    python3 tinyimg.py first.png second.jpg "photo with spaces.png"

Full Command:
    python3 tinyimg.py /path/to/images --recursive --jobs 4 --timeout 120
    python3 tinyimg.py /path/to/images --suffix _small
    python3 tinyimg.py /path/to/images --resize 1080
    python3 tinyimg.py /path/to/images --scale 0.5
    python3 tinyimg.py --usage

Options:
    paths: Image files or directories separated by spaces; defaults to the current directory.
    -r, --recursive: Scan all subdirectories without following directory symlinks.
    --reset-key: Prompt for and save a replacement API key.
    --timeout: Timeout per network operation in seconds; default: 120.
    -j, --jobs: Number of parallel worker processes; default: 4.
    --usage: Query monthly usage without uploading or compressing images, then exit.
    --suffix: Append this suffix to compressed image stems; default: no suffix.
    --resize: Set the longest edge to 1080, 720, or 360 pixels, preserving aspect ratio.
    --scale: Multiply both dimensions by a finite positive factor, e.g. 0.5.

Notes:
    --resize and --scale are mutually exclusive and require Pillow (pip install Pillow).
    Resizing may enlarge images. Dimensions are rounded to at least one pixel.
    Resized uploads retain the image format; unsupported codecs and animated images fail locally.
    Store the key as plain text in $XDG_CONFIG_HOME/tinyimg/api_key, defaulting to
    ~/.config/tinyimg/api_key, with permissions 600, outside the code repository.
    Skip *_origin backups, legacy *_tiny files, symlinks, and existing backup/output conflicts.
    With --suffix, also skip stems ending in that suffix. Existing backups mark processed images.
    Only rename originals after a complete download; never overwrite an existing backup.
    Upload images to Tinify and consume account quota. Failed requests are not retried.
    Sizes use decimal MB (1 MB = 1,000,000 bytes).
    Remaining free usage assumes 500 compressions/month, not a paid plan limit.
    On account, rate-limit, or server errors, finish active tasks and stop new batches.
"""

import argparse
import base64
from concurrent.futures import ProcessPoolExecutor, as_completed
import getpass
import http.client
from io import BytesIO
import os
import multiprocessing
from pathlib import Path
import sys
import tempfile
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen


EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".avif", ".jxl"}
API_URL = "https://api.tinify.com/shrink"
FREE_MONTHLY_LIMIT = 500


def format_size(size):
    """Format a byte count in decimal megabytes."""
    return f"{size / 1_000_000:,.3f} MB"


def load_key(reset=False):
    """Load the saved key or prompt for one and save it with owner-only permissions."""
    config_root = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    key_path = config_root / "tinyimg" / "api_key"
    if not reset and key_path.exists():
        key_path.chmod(0o600)
        key = key_path.read_text(encoding="utf-8").strip()
        if key:
            return key
    if not sys.stdin.isatty():
        raise ValueError("Run the script in an interactive terminal first to enter your API key.")
    key = getpass.getpass("Enter your TinyPNG API key (input hidden): ").strip()
    if not key or any(character.isspace() for character in key):
        raise ValueError("The API key must not be empty or contain whitespace.")
    key_path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=key_path.parent,
                                         delete=False) as stream:
            temporary = Path(stream.name)
            os.fchmod(stream.fileno(), 0o600)
            stream.write(key + "\n")
        os.replace(temporary, key_path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    print(f"API key saved to: {key_path}")
    return key


def find_images(target, recursive):
    """Collect supported images without following directory symlinks during recursion."""
    if target.is_file():
        if target.suffix.lower() not in EXTENSIONS:
            raise ValueError(f"Unsupported image format: {target.suffix}")
        return [target]
    if not target.is_dir():
        raise ValueError(f"Path does not exist or is not a regular file or directory: {target}")
    images = []
    for directory, subdirectories, filenames in os.walk(target, onerror=raise_walk_error):
        subdirectories.sort()
        for name in sorted(filenames):
            path = Path(directory) / name
            if path.suffix.lower() in EXTENSIONS and path.is_file():
                images.append(path)
        if not recursive:
            break
    return images


def raise_walk_error(error):
    """Report directory access errors instead of silently omitting images."""
    raise error


def backup_path(source):
    """Return the original image backup path with its extension preserved."""
    return source.with_name(f"{source.stem}_origin{source.suffix}")


class TinyImgClient:
    """Handle Tinify uploads, downloads, and usage tracking."""

    def __init__(self, key, timeout, resize=None, scale=None):
        """Configure client authentication and the network timeout."""
        token = base64.b64encode(f"api:{key}".encode()).decode("ascii")
        self.authorization = f"Basic {token}"
        self.timeout = timeout
        self.compression_count = None
        self.resize = resize
        self.scale = scale

    def prepare_upload(self, source):
        """Resize image bytes locally when requested, leaving the source untouched."""
        data = source.read_bytes()
        if self.resize is None and self.scale is None:
            return data
        from PIL import Image, ImageOps

        with Image.open(BytesIO(data)) as original:
            if getattr(original, "is_animated", False):
                raise ValueError("Resizing animated images is not supported.")
            image_format = original.format
            image = ImageOps.exif_transpose(original)
            factor = self.scale if self.scale is not None else self.resize / max(image.size)
            dimensions = tuple(max(1, round(edge * factor)) for edge in image.size)
            resized = image.resize(dimensions, Image.Resampling.LANCZOS)
            output = BytesIO()
            options = {}
            if image_format in ("JPEG", "WEBP", "AVIF"):
                options["quality"] = 100
            if image_format == "JPEG":
                options["subsampling"] = 0
            try:
                resized.save(output, format=image_format, **options)
            except KeyError as error:
                raise ValueError(f"Pillow cannot encode this image format: {image_format}") from error
            return output.getvalue()

    def record_usage(self, headers):
        """Keep the highest reported count when concurrent responses arrive out of order."""
        count = headers.get("Compression-Count")
        if count is not None:
            self.compression_count = max(self.compression_count or 0, int(count))

    def request(self, url, data=None):
        """Send an authenticated request and record the reported monthly usage."""
        request = Request(url, data=data, headers={"Authorization": self.authorization})
        if data is not None:
            request.add_header("Content-Type", "application/octet-stream")
        try:
            response = urlopen(request, timeout=self.timeout)
        except HTTPError as error:
            self.record_usage(error.headers)
            raise
        self.record_usage(response.headers)
        return response

    def query_usage(self):
        """Read usage with the empty POST used by the official SDK for key validation."""
        self.compression_count = None
        try:
            with self.request(API_URL, data=b""):
                pass
        except HTTPError as error:
            error.close()
            if error.code not in (400, 429):
                raise
            if error.code == 429:
                print("API reports a quota or rate limit (HTTP 429).")
        if self.compression_count is None:
            raise ValueError("Tinify did not return a Compression-Count header; usage is unavailable.")
        return self.compression_count

    def print_usage(self):
        """Display account usage and the remaining allowance under the free tier."""
        if self.compression_count is not None:
            remaining = max(0, FREE_MONTHLY_LIMIT - self.compression_count)
            print(f"Account compressions used this month: {self.compression_count}")
            print(f"Free monthly allowance remaining: {remaining}/{FREE_MONTHLY_LIMIT}")
            print("Free-tier estimate only; paid billing limits are not returned by this API.")

    def compress(self, source, destination):
        """Download compression before backing up the original and publishing the output."""
        backup = backup_path(source)
        if source.is_symlink() or os.path.lexists(backup):
            raise ValueError(f"Source is a symlink or its backup already exists: {source}")
        if destination != source and os.path.lexists(destination):
            raise FileExistsError(f"Output already exists: {destination}")
        original_stat = source.stat()
        data = self.prepare_upload(source)
        with self.request(API_URL, data=data) as response:
            output_url = response.headers.get("Location", "")
        location = urlsplit(output_url)
        if (location.scheme != "https" or location.netloc != "api.tinify.com"
                or not location.path.startswith("/output/")):
            raise ValueError("Tinify returned an invalid download URL.")
        temporary = None
        try:
            with self.request(output_url) as response:
                with tempfile.NamedTemporaryFile(dir=destination.parent, prefix=".tinyimg-",
                                                 delete=False) as stream:
                    temporary = Path(stream.name)
                    output_size = 0
                    while chunk := response.read(1024 * 1024):
                        stream.write(chunk)
                        output_size += len(chunk)
                    expected_size = response.headers.get("Content-Length")
                    if output_size == 0 or (expected_size is not None
                                            and output_size != int(expected_size)):
                        raise ValueError("The download is empty or incomplete; no output file was created.")
            current_stat = source.stat()
            if (original_stat.st_ino, original_stat.st_size, original_stat.st_mtime_ns) != (
                    current_stat.st_ino, current_stat.st_size, current_stat.st_mtime_ns):
                raise ValueError(f"Source changed during compression; left untouched: {source}")
            # A hard link reserves the backup name without overwriting another file.
            os.link(source, backup)
            try:
                if destination == source:
                    os.replace(temporary, destination)
                else:
                    os.link(temporary, destination)
            except BaseException:
                backup.unlink()
                raise
            if destination != source:
                source.unlink()
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)
        return original_stat.st_size, output_size



class CompressionError(Exception):
    """Carry a worker failure and its usage count back to the parent process."""


def compress_image(client, source, destination):
    """Compress one image in a worker and return sizes plus the observed usage count."""
    try:
        before, after = client.compress(source, destination)
    except HTTPError as error:
        error.close()
        raise CompressionError(error.code, f"Tinify HTTP {error.code}", client.compression_count) from None
    except (OSError, URLError, ValueError, http.client.HTTPException) as error:
        raise CompressionError(None, str(error), client.compression_count) from None
    return before, after, client.compression_count


def main():
    """Parse CLI arguments, query usage or compress images, and report results."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("paths", nargs="*", type=Path, help="Image files or directories; defaults to the current directory")
    parser.add_argument("-r", "--recursive", action="store_true", help="Process subdirectories recursively")
    parser.add_argument("--reset-key", action="store_true", help="Prompt for and save a replacement API key")
    parser.add_argument("--timeout", type=float, default=120, help="Network timeout in seconds; default: 120")
    parser.add_argument("-j", "--jobs", type=int, default=4, help="Parallel worker processes; default: 4")
    parser.add_argument("--usage", action="store_true", help="Query monthly usage without compressing images")
    parser.add_argument("--suffix", default="", help="Suffix for compressed image stems; default: none")
    sizing = parser.add_mutually_exclusive_group()
    sizing.add_argument("--resize", type=int, choices=(1080, 720, 360),
                        help="Resize the longest edge to this many pixels before upload")
    sizing.add_argument("--scale", type=float,
                        help="Scale width and height by this positive factor before upload")
    args = parser.parse_intermixed_args()
    if any(character in args.suffix for character in ("/", "\\", "\0")):
        parser.error("--suffix must not contain path separators or null characters")
    if args.suffix.lower().endswith("_origin"):
        parser.error("--suffix must not end in the reserved backup suffix _origin")
    if args.jobs < 1:
        parser.error("--jobs must be a positive integer")
    if not 0 < args.timeout < float("inf"):
        parser.error("--timeout must be a finite positive number")
    if args.scale is not None and not 0 < args.scale < float("inf"):
        parser.error("--scale must be a finite positive number")
    if not args.usage and (args.resize is not None or args.scale is not None):
        try:
            from PIL import Image
        except ImportError:
            parser.error("--resize and --scale require Pillow; install it with: pip install Pillow")
    try:
        images = []
        if not args.usage:
            seen = set()
            for target in args.paths or [Path(".")]:
                for source in find_images(target.expanduser(), args.recursive):
                    identity = source.resolve()
                    if source.is_symlink() or identity not in seen:
                        images.append(source)
                        if not source.is_symlink():
                            seen.add(identity)
        client = TinyImgClient(load_key(args.reset_key), args.timeout, args.resize, args.scale)
        if args.usage:
            client.query_usage()
            client.print_usage()
            return 0
    except HTTPError as error:
        error.close()
        print(f"Error: Tinify HTTP {error.code}. Check your API key or account status.", file=sys.stderr)
        return 1
    except (OSError, ValueError, EOFError, http.client.HTTPException) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    succeeded = skipped = failed = 0
    input_total = output_total = 0
    print(f"Found {len(images)} supported image file(s).")
    pending = []
    for source in images:
        destination = source.with_name(f"{source.stem}{args.suffix}{source.suffix}")
        generated = source.stem.lower().endswith(("_origin", "_tiny"))
        if args.suffix:
            generated = generated or source.stem.lower().endswith(args.suffix.lower())
        if (generated or source.is_symlink() or os.path.lexists(backup_path(source))
                or (destination != source and os.path.lexists(destination))):
            skipped += 1
            print(f"Skipping: {source}")
        else:
            pending.append((source, destination))
    stop = False
    with ProcessPoolExecutor(max_workers=args.jobs, mp_context=multiprocessing.get_context("spawn")) as executor:
        for offset in range(0, len(pending), args.jobs):
            futures = {}
            for source, destination in pending[offset:offset + args.jobs]:
                print(f"Compressing: {source}", flush=True)
                futures[executor.submit(compress_image, client, source, destination)] = destination
            for future in as_completed(futures):
                destination = futures[future]
                try:
                    before, after, count = future.result()
                    if count is not None:
                        client.record_usage({"Compression-Count": str(count)})
                except CompressionError as error:
                    failed += 1
                    status, message, count = error.args
                    if count is not None:
                        client.record_usage({"Compression-Count": str(count)})
                    print(f"Failed ({destination}): {message}", file=sys.stderr)
                    if status in (401, 403, 429) or (status is not None and status >= 500):
                        stop = True
                except (OSError, URLError, ValueError, http.client.HTTPException) as error:
                    failed += 1
                    print(f"Failed ({destination}): {error}", file=sys.stderr)
                else:
                    succeeded += 1
                    input_total += before
                    output_total += after
                    ratio = (1 - after / before) * 100 if before else 0
                    print(f"  -> {destination}: {format_size(before)} -> {format_size(after)}, reduction: {ratio:.1f}%")
            if stop:
                print("Stopped. Check your API key (--reset-key), quota, rate limit, or service status.", file=sys.stderr)
                break
    remaining = len(images) - succeeded - skipped - failed
    print(f"Done: {succeeded} succeeded, {skipped} skipped, {failed} failed, {remaining} unprocessed.")
    if input_total:
        print(f"Total size: {format_size(input_total)} -> {format_size(output_total)}, reduction: {(1 - output_total / input_total) * 100:.1f}%")
    client.print_usage()
    return 1 if failed else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\nCancelled.", file=sys.stderr)
        sys.exit(130)
