#!/usr/bin/env python3
"""
Supervisor — 多 worktree 并发调度循环（domain-agnostic 通用原语）

参考 autodev/supervisor-runtime.sh 的设计但用 Python 重写。

supervisor 是确定性调度器（**不是 LLM**）。它的工作全是确定的：
  1. claim_next(workitem) → 从 workitem source 领一个
  2. worktree_lifecycle.acquire(workitem_id) → 开 worktree
  3. dispatch workitem-agent（fork 子进程 / spawn 子 session）
  4. wait for archive（event watch，非轮询）
  5. check stop condition → continue/stop
  6. worktree_lifecycle.release(workitem_id)
  7. rebase_sync.sync(branch, base) → 把完成的分支 rebase 到 main

stop conditions（runtime-config.yaml.stop_conditions）：
  - queue_empty          workitem source 无候选
  - max_items_reached    达到 max_items 上限
  - max_runtime_exceeded 超过 max_runtime
  - error_threshold      连续失败次数超阈值
  - manual_stop          检测到 .meta-harness/STOP 文件
  - all_acs_verified     所有 acceptance_criteria 已验证完成
  - fatal_event          事件流出现 fatal 级事件
  - drain                不再领新 workitem，等当前完成（graceful shutdown）

LLM 智能（如果需要）只在 workitem-agent 层——supervisor 不调 LLM。

为什么 supervisor 是确定性 bash/python 而非 LLM：
  - 调度逻辑是确定的（claim/acquire/dispatch/wait/release），不需要智能
  - 确定性 = 可测试 = 可复现
  - LLM 调度会引入随机性，违背"工程级可靠性"

退出码：0 = 正常 stop；1 = 异常

Usage:
  # 库模式（被 orchestrator.py 调用）
  from runtime.supervisor import Supervisor
  sup = Supervisor(project_root=Path("."))
  sup.run()

  # CLI 模式
  python runtime/supervisor.py run --project-root .
  python runtime/supervisor.py status --project-root .
  python runtime/supervisor.py stop --project-root .   # 写 STOP 文件，让 supervisor 下一轮停
"""

import argparse
import json
import os
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Optional

import yaml

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

sys.path.insert(0, str(Path(__file__).resolve().parent))
try:
    from workitem_source import WorkitemSource, load_source
    from worktree_lifecycle import WorktreeLifecycle
    from event_stream import EventStream
    from rebase_sync import sync as rebase_sync
except ImportError:
    import importlib.util

    _here = Path(__file__).resolve().parent

    def _load(name: str):
        spec = importlib.util.spec_from_file_location(name, _here / f"{name}.py")
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        return mod

    _ws_mod = _load("workitem_source")
    _wt_mod = _load("worktree_lifecycle")
    _es_mod = _load("event_stream")
    _rs_mod = _load("rebase_sync")
    WorkitemSource = _ws_mod.WorkitemSource
    load_source = _ws_mod.load_source
    WorktreeLifecycle = _wt_mod.WorktreeLifecycle
    EventStream = _es_mod.EventStream
    rebase_sync = _rs_mod.sync


def load_yaml(path: Path):
    try:
        return yaml.safe_load(path.read_text(encoding="utf-8"))
    except Exception as e:
        return {"_parse_error": str(e)}


class Supervisor:
    """多 worktree 并发调度器。"""

    def __init__(self, project_root: Path):
        self.project_root = project_root.resolve()
        self.config = self._load_config()
        self.events = EventStream(self.project_root)
        self.wt_lifecycle = WorktreeLifecycle(self.project_root)
        self.source: Optional[WorkitemSource] = None
        self.start_time: Optional[datetime] = None
        self.items_processed = 0
        self.consecutive_errors = 0

    def _load_config(self) -> dict:
        cfg_file = self.project_root / "planning" / "runtime-config.yaml"
        cfg = load_yaml(cfg_file)
        if isinstance(cfg, dict) and "_parse_error" not in cfg:
            return cfg
        return {
            "max_items": 10,
            "max_runtime_seconds": 3600,
            "error_threshold": 3,
            "stop_conditions": ["queue_empty", "max_items_reached", "error_threshold"],
            "dispatch_mode": "subprocess",
            "claim_policy": "any",
            "worktree_pool_size": 0,
            "branch_prefix": "feature",
            "base_branch": "origin/main",
            "push_after_rebase": False,
        }

    def _load_source(self) -> WorkitemSource:
        src_file = self.project_root / "planning" / "workitem-source.yaml"
        src_cfg = load_yaml(src_file)
        if not isinstance(src_cfg, dict) or "adapter" not in src_cfg:
            raise RuntimeError(
                "planning/workitem-source.yaml missing or invalid — cannot dispatch"
            )
        return load_source(src_cfg)

    # ---- stop condition 评估 ----

    def _check_stop(self) -> Optional[str]:
        """评估是否应 stop。返回 stop reason 或 None。"""
        conditions = set(self.config.get("stop_conditions", []))
        stop_file = self.project_root / ".meta-harness" / "STOP"
        if stop_file.exists():
            return "manual_stop"
        if "queue_empty" in conditions and self.source:
            pending = self.source.list_pending(limit=1)
            if not pending:
                # 当前也无 active workitem 时才算 empty
                # （pending 为空但可能正在处理一个）
                # 简化：当 claim_next 返回 None 时才算 queue_empty（在主循环里测）
                pass
        if "max_items_reached" in conditions and self.items_processed >= self.config.get("max_items", 10):
            return "max_items_reached"
        if "max_runtime_exceeded" in conditions and self.start_time:
            elapsed = (datetime.now() - self.start_time).total_seconds()
            if elapsed >= self.config.get("max_runtime_seconds", 3600):
                return "max_runtime_exceeded"
        if "error_threshold" in conditions and self.consecutive_errors >= self.config.get("error_threshold", 3):
            return "error_threshold"
        if "fatal_event" in conditions:
            fatal = self.events.filter_by(level="fatal")
            if fatal:
                return "fatal_event"
        return None

    # ---- dispatch workitem-agent ----

    def _dispatch_workitem_agent(self, workitem_id: str, worktree_path: Path) -> int:
        """派发 workitem-agent 到 worktree。

        本原语只提供 subprocess 模式（spawn `python orchestrator.py --workitem-id ...`）。
        IDE 中性的 adapter（Codex/Cursor）由 LLM 在 runtime-config.dispatch_mode 配置。

        Returns:
          进程退出码。
        """
        mode = self.config.get("dispatch_mode", "subprocess")
        if mode == "subprocess":
            cmd = ["python", "orchestrator.py", "--workitem-id", workitem_id]
            result = subprocess.run(
                cmd, cwd=worktree_path,
                capture_output=False, text=True, encoding="utf-8", errors="replace",
            )
            return result.returncode
        # 其他模式（mavis/ide-adapter）由 LLM 在 GENERATE 合成具体 dispatch impl
        raise RuntimeError(
            f"dispatch_mode={mode} not supported by universal primitive. "
            f"LLM should generate adapter in runtime/dispatchers/{mode}_dispatcher.py"
        )

    # ---- 主循环 ----

    def run(self) -> dict:
        """主调度循环。返回 stop summary。"""
        self.start_time = datetime.now()
        self.source = self._load_source()
        self.events.append({"type": "supervisor_start", "config": self.config})

        if self.config.get("worktree_pool_size", 0) > 0:
            self.wt_lifecycle.ensure_pools(self.config["worktree_pool_size"])

        stop_reason = None
        while True:
            # 0. stop condition 检查
            stop_reason = self._check_stop()
            if stop_reason:
                break

            # 1. claim next workitem
            try:
                workitem_id = self.source.claim_next(self.config.get("claim_policy", "any"))
            except Exception as e:
                self.events.append({"type": "claim_error", "error": str(e)})
                self.consecutive_errors += 1
                if self.consecutive_errors >= self.config.get("error_threshold", 3):
                    stop_reason = "claim_error_threshold"
                    break
                time.sleep(1)
                continue

            if workitem_id is None:
                if "queue_empty" in self.config.get("stop_conditions", []):
                    stop_reason = "queue_empty"
                    break
                time.sleep(1)
                continue

            # 2. acquire worktree
            try:
                wt_path = self.wt_lifecycle.acquire(
                    workitem_id, branch_prefix=self.config.get("branch_prefix", "feature"))
            except Exception as e:
                self.events.append({
                    "type": "worktree_acquire_failed", "workitem_id": workitem_id, "error": str(e),
                })
                self.source.update_status(workitem_id, "blocked")
                self.consecutive_errors += 1
                continue

            self.events.append({
                "type": "worktree_acquired", "workitem_id": workitem_id,
                "worktree_path": str(wt_path),
            })

            # 3. fetch brief + update status
            brief = self.source.fetch_brief(workitem_id)
            self.source.update_status(workitem_id, "in_progress")

            self.events.append({
                "type": "supervisor_dispatch", "workitem_id": workitem_id,
                "title": brief.get("title", ""), "effort": brief.get("effort", ""),
            })

            # 4. dispatch workitem-agent
            try:
                rc = self._dispatch_workitem_agent(workitem_id, wt_path)
                verdict = "pass" if rc == 0 else "fail"
            except Exception as e:
                self.events.append({
                    "type": "dispatch_failed", "workitem_id": workitem_id, "error": str(e),
                })
                verdict = "blocked"
                self.consecutive_errors += 1

            if verdict == "pass":
                self.consecutive_errors = 0

            # 5. heartbeat + refresh
            self.wt_lifecycle.refresh(workitem_id)

            # 6. archive
            summary = brief.get("title", "")[:200]
            try:
                self.source.archive(workitem_id, verdict, summary)
            except Exception as e:
                self.events.append({
                    "type": "archive_failed", "workitem_id": workitem_id, "error": str(e),
                })

            self.events.append({
                "type": "workitem_archived", "workitem_id": workitem_id, "verdict": verdict,
            })

            # 7. rebase sync（rebase-only 策略）
            try:
                branch = f"{self.config.get('branch_prefix', 'feature')}/{workitem_id}"
                sync_result = rebase_sync(
                    branch=branch,
                    base=self.config.get("base_branch", "origin/main"),
                    worktree_path=wt_path,
                    push=self.config.get("push_after_rebase", False),
                )
                self.events.append({
                    "type": "rebase_sync", "workitem_id": workitem_id,
                    "ok": sync_result["ok"], "conflicts": sync_result.get("conflicts", []),
                })
                if not sync_result["ok"] and sync_result.get("conflicts"):
                    # rebase 冲突 → 不自动 merge，标 blocked 转人工
                    self.source.update_status(workitem_id, "blocked")
            except Exception as e:
                self.events.append({
                    "type": "rebase_sync_failed", "workitem_id": workitem_id, "error": str(e),
                })

            # 8. release worktree
            self.wt_lifecycle.release(workitem_id, prune=False, keep_branch=True)
            self.events.append({
                "type": "worktree_released", "workitem_id": workitem_id,
            })

            self.items_processed += 1

        # stop
        summary = {
            "stop_reason": stop_reason,
            "items_processed": self.items_processed,
            "duration_seconds": (datetime.now() - self.start_time).total_seconds()
            if self.start_time else 0,
            "consecutive_errors": self.consecutive_errors,
        }
        self.events.append({"type": "supervisor_stop", **summary})
        return summary

    # ---- status / stop ----

    def status(self) -> dict:
        return {
            "items_processed": self.items_processed,
            "consecutive_errors": self.consecutive_errors,
            "start_time": self.start_time.isoformat() if self.start_time else None,
            "elapsed_seconds": (datetime.now() - self.start_time).total_seconds()
            if self.start_time else 0,
            "events_tail": self.events.tail(5),
        }

    def request_stop(self) -> None:
        """写 STOP 文件，让主循环下一轮检测到停止。graceful shutdown。"""
        stop_file = self.project_root / ".meta-harness" / "STOP"
        stop_file.write_text(f"requested at {datetime.now().isoformat()}\n", encoding="utf-8")


def main():
    ap = argparse.ArgumentParser(description="Supervisor: multi-worktree scheduler")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p_r = sub.add_parser("run", help="Run scheduler loop")
    p_r.add_argument("--project-root", required=True)

    p_s = sub.add_parser("status", help="Show current status")
    p_s.add_argument("--project-root", required=True)

    p_stop = sub.add_parser("stop", help="Request graceful stop")
    p_stop.add_argument("--project-root", required=True)

    args = ap.parse_args()
    sup = Supervisor(Path(args.project_root))

    if args.cmd == "run":
        summary = sup.run()
        print(yaml.dump(summary, default_flow_style=False, allow_unicode=True))
        sys.exit(0 if summary["stop_reason"] != "fatal_event" else 1)
    elif args.cmd == "status":
        print(yaml.dump(sup.status(), default_flow_style=False, allow_unicode=True))
    elif args.cmd == "stop":
        sup.request_stop()
        print("STOP file written — supervisor will exit on next loop iteration")


if __name__ == "__main__":
    main()
