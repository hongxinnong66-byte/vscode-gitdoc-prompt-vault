#!/usr/bin/env python3
"""Cross-platform diagnostic and scaffolding helper for vscode-gitdoc-prompt-vault.

Uses only Python standard library. Writes structured JSON output to --output
so AI agents can inspect results without noisy stdout.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

SKILL_ROOT = Path(__file__).resolve().parent.parent
TEMPLATES_DIR = SKILL_ROOT / "templates"

REQUIRED_EXTENSIONS = [
    "vsls-contrib.gitdoc",
    "yzhang.markdown-all-in-one",
]

DEFAULT_MODULES = [
    ("01-学术写作与润色.md", "01 - 学术写作与润色 Prompt"),
    ("02-翻译与文献精读.md", "02 - 翻译与文献精读 Prompt"),
    ("03-科研绘图与代码.md", "03 - 科研绘图与代码 Prompt"),
    ("04-通用高频Prompt.md", "04 - 通用高频 Prompt"),
]


def _run(cmd: list[str], env: dict[str, str] | None = None) -> tuple[int, str, str]:
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=15,
            env=env,
        )
        return proc.returncode, proc.stdout.strip(), proc.stderr.strip()
    except Exception as exc:
        return 1, "", str(exc)


def _find_gh() -> str | None:
    found = shutil.which("gh")
    if found:
        return found
    win_default = Path(r"C:\Program Files\GitHub CLI\gh.exe")
    return str(win_default) if win_default.exists() else None


def _find_code() -> str | None:
    found = shutil.which("code")
    if found:
        return found
    local_app = os.environ.get("LOCALAPPDATA")
    if local_app:
        candidate = Path(local_app) / "Programs" / "Microsoft VS Code" / "bin" / "code.cmd"
        if candidate.exists():
            return str(candidate)
    return None


def _write_json(output_path: str, payload: dict[str, Any]) -> None:
    out = Path(output_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8") as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)


def cmd_diagnose(args: argparse.Namespace) -> int:
    git_path = shutil.which("git")
    gh_path = _find_gh()
    code_path = _find_code()

    git_env = {k: v for k, v in os.environ.items() if k.startswith("GIT_CONFIG_")}
    empty_git_values = [
        k for k, v in git_env.items() if k.startswith("GIT_CONFIG_VALUE_") and v == ""
    ]

    extensions_installed: list[str] = []
    if code_path:
        rc, out, _ = _run([code_path, "--list-extensions"])
        if rc == 0:
            extensions_installed = [line.strip() for line in out.splitlines() if line.strip()]

    missing_extensions = [e for e in REQUIRED_EXTENSIONS if e not in extensions_installed]

    gh_logged_in = False
    gh_status_text = ""
    if gh_path:
        rc, out, err = _run([gh_path, "auth", "status"])
        gh_logged_in = rc == 0
        gh_status_text = out or err

    git_user_name = ""
    git_user_email = ""
    if git_path:
        _, git_user_name, _ = _run([git_path, "config", "--global", "user.name"])
        _, git_user_email, _ = _run([git_path, "config", "--global", "user.email"])

    warnings: list[str] = []
    if empty_git_values:
        warnings.append(
            "Empty GIT_CONFIG_VALUE_* env vars detected "
            f"({', '.join(empty_git_values)}). Strip GIT_CONFIG_* before launching VS Code "
            "or vscode.git will fail with 'missing config value GIT_CONFIG_VALUE_0'."
        )
    if missing_extensions:
        warnings.append(f"Missing VS Code extensions: {', '.join(missing_extensions)}")
    if not gh_logged_in:
        warnings.append("GitHub CLI is not authenticated. Run 'gh auth login --web --clipboard'.")
    if not git_user_name or not git_user_email:
        warnings.append("Global git user.name or user.email is not configured.")

    report = {
        "tools": {
            "git": git_path,
            "gh": gh_path,
            "code": code_path,
        },
        "vscode_extensions": {
            "installed": [e for e in REQUIRED_EXTENSIONS if e in extensions_installed],
            "missing": missing_extensions,
        },
        "github_auth": {
            "logged_in": gh_logged_in,
            "details": gh_status_text,
        },
        "git_global_identity": {
            "user_name": git_user_name,
            "user_email": git_user_email,
        },
        "env_check": {
            "git_config_vars_count": len(git_env),
            "empty_git_config_values": empty_git_values,
        },
        "warnings": warnings,
        "ready": len(warnings) == 0,
    }
    _write_json(args.output, report)
    print(f"Success! Diagnostic report written to: {args.output}")
    return 0


def cmd_init_templates(args: argparse.Namespace) -> int:
    target = Path(args.target).resolve()
    target.mkdir(parents=True, exist_ok=True)
    (target / ".vscode").mkdir(parents=True, exist_ok=True)
    (target / "prompts").mkdir(parents=True, exist_ok=True)
    (target / "skills" / "_SKILL模板").mkdir(parents=True, exist_ok=True)

    created: list[str] = []
    skipped: list[str] = []

    def copy_or_write(dest: Path, content: str) -> None:
        if dest.exists() and not args.force:
            skipped.append(str(dest))
            return
        dest.write_text(content, encoding="utf-8")
        created.append(str(dest))

    settings_raw = (TEMPLATES_DIR / "settings.json").read_text(encoding="utf-8")
    settings_raw = settings_raw.replace('"Asia/Shanghai"', f'"{args.timezone}"')
    copy_or_write(target / ".vscode" / "settings.json", settings_raw)

    copy_or_write(
        target / ".vscode" / "extensions.json",
        (TEMPLATES_DIR / "extensions.json").read_text(encoding="utf-8"),
    )
    copy_or_write(
        target / ".gitignore",
        (TEMPLATES_DIR / "gitignore").read_text(encoding="utf-8"),
    )
    copy_or_write(
        target / "README.md",
        (TEMPLATES_DIR / "README.template.md").read_text(encoding="utf-8"),
    )
    copy_or_write(
        target / "skills" / "_SKILL模板" / "SKILL.md",
        (TEMPLATES_DIR / "SKILL.template.md").read_text(encoding="utf-8"),
    )

    mod_tpl = (TEMPLATES_DIR / "prompt-module.template.md").read_text(encoding="utf-8")
    for filename, title in DEFAULT_MODULES:
        copy_or_write(
            target / "prompts" / filename,
            mod_tpl.replace("{{MODULE_TITLE}}", title),
        )

    result = {
        "target": str(target),
        "created_count": len(created),
        "skipped_count": len(skipped),
        "created": created,
        "skipped": skipped,
    }
    _write_json(args.output, result)
    print(f"Success! Template initialization report written to: {args.output}")
    return 0


def cmd_check_prompts(args: argparse.Namespace) -> int:
    prompts_dir = Path(args.target).resolve() / "prompts"
    if not prompts_dir.exists():
        print(f"Error: prompts directory not found at {prompts_dir}", file=sys.stderr)
        return 1

    files_summary: list[dict[str, Any]] = []
    total_prompts = 0
    heading_re = re.compile(r"^##\s+(\d+)\.\s+(.+)$")

    for md_file in sorted(prompts_dir.glob("*.md")):
        lines = md_file.read_text(encoding="utf-8").splitlines()
        entries: list[dict[str, Any]] = []
        for idx, line in enumerate(lines):
            m = heading_re.match(line.strip())
            if m:
                next_line = lines[idx + 1].strip() if idx + 1 < len(lines) else ""
                has_prompt_marker = next_line.startswith("# Prompt")
                entries.append(
                    {
                        "index": int(m.group(1)),
                        "title": m.group(2).strip(),
                        "line": idx + 1,
                        "has_prompt_marker": has_prompt_marker,
                    }
                )
        total_prompts += len(entries)
        files_summary.append(
            {
                "file": md_file.name,
                "prompt_count": len(entries),
                "missing_marker_count": sum(1 for e in entries if not e["has_prompt_marker"]),
                "entries": entries,
            }
        )

    report = {
        "prompts_dir": str(prompts_dir),
        "total_prompts": total_prompts,
        "files": files_summary,
    }
    _write_json(args.output, report)
    print(f"Success! Prompt audit written to: {args.output}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Diagnostic and scaffolding helper for vscode-gitdoc-prompt-vault."
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_diag = sub.add_parser("diagnose", help="Check git, gh, VS Code, extensions, and env health.")
    p_diag.add_argument("--output", required=True, help="Path to write JSON diagnostic report.")
    p_diag.set_defaults(func=cmd_diagnose)

    p_init = sub.add_parser("init-templates", help="Create starter templates and VS Code settings.")
    p_init.add_argument("--target", required=True, help="Target vault directory path.")
    p_init.add_argument("--timezone", default="Asia/Shanghai", help="IANA timezone for GitDoc commits.")
    p_init.add_argument("--force", action="store_true", help="Overwrite existing template files.")
    p_init.add_argument("--output", required=True, help="Path to write JSON result report.")
    p_init.set_defaults(func=cmd_init_templates)

    p_chk = sub.add_parser("check-prompts", help="Audit prompts/*.md formatting and count entries.")
    p_chk.add_argument("--target", required=True, help="Target vault directory path.")
    p_chk.add_argument("--output", required=True, help="Path to write JSON audit report.")
    p_chk.set_defaults(func=cmd_check_prompts)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
