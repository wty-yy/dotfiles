#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Generate config.toml and auth.json for Codex configuration.
Default url is https://www.codexapis.com/v1
Usage:
    python codex_config_generate.py <API_KEY> [--install]
    --install: Install generated files into the current system user's ~/.codex directory, backing up
"""

import argparse
import json
import os
import shutil
from pathlib import Path


CONFIG_TEMPLATE = """preferred_auth_method = "apikey"
model = "gpt-5.4"
model_provider = "relay"

[model_providers.relay]
name = "relay"
base_url = "https://www.codexapis.com/v1"
wire_api = "responses"
requires_openai_auth = true

[projects."/home/yy"]
trust_level = "trusted"
"""


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate config.toml and auth.json in the script directory"
    )
    parser.add_argument("api_key", help="API key to write into auth.json")
    parser.add_argument(
        "--install",
        action="store_true",
        help="Install generated files into the current system user's ~/.codex directory",
    )
    args = parser.parse_args()

    api_key = args.api_key.strip()
    if not api_key:
        print("Error: API key is empty.")
        return 1

    script_dir = Path(__file__).resolve().parent
    config_path = script_dir / "config.toml"
    auth_path = script_dir / "auth.json"

    config_path.write_text(CONFIG_TEMPLATE, encoding="utf-8")

    auth_data = {
        "OPENAI_API_KEY": api_key
    }
    auth_path.write_text(
        json.dumps(auth_data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8"
    )

    print(f"[INFO] Generated: {config_path}")
    print(f"[INFO] Generated: {auth_path}")

    if args.install:
        print("[INFO] Installing generated files to ~/.codex...")
        home_dir = Path(os.environ.get("USERPROFILE", str(Path.home()))).expanduser()
        codex_dir = home_dir / ".codex"
        codex_dir.mkdir(parents=True, exist_ok=True)

        install_pairs = [
            (config_path, codex_dir / "config.toml"),
            (auth_path, codex_dir / "auth.json"),
        ]

        for src, dst in install_pairs:
            if dst.exists():
                bak_path = dst.with_name(dst.name + ".bak")
                shutil.copy2(dst, bak_path)
                print(f"[INFO] Backed up: {bak_path}")

            shutil.copy2(src, dst)
            print(f"[INFO] Installed: {dst}")

        print("[INFO] Removing generated files from script directory...")
        config_path.unlink()
        auth_path.unlink()

        print("[INFO] Installation complete.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
