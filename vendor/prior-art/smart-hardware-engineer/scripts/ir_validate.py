#!/usr/bin/env python3
"""Design IR 离线校验（Gate-1）。

在把设计落到 JLCEDA 之前做"离线 ERC 级"检查：结构、连通性、电源树、去耦、
命名、网类完整性、占位料号等。优先用 jsonschema 做结构校验（若已安装），
否则降级为内置结构检查。

用法:
  python3 ir_validate.py path/to/design.ir.json [--json] [--schema path]

退出码: 有 error → 1，否则 0。warning 不影响退出码但会列出。
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
DEFAULT_SCHEMA = HERE.parent / "ir" / "schema" / "design_ir.schema.json"

REFDES_RE = re.compile(r"^[A-Za-z]+[0-9]+$")
NODE_RE = re.compile(r"^([A-Za-z]+[0-9]+)\.([A-Za-z0-9_]+)$")
NET_CLASSES = {"power", "gnd", "analog", "clk", "rf", "diff", "highcurrent", "lf-signal", "safety", "nc"}


class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []
        self.info: list[str] = []

    def err(self, msg: str) -> None:
        self.errors.append(msg)

    def warn(self, msg: str) -> None:
        self.warnings.append(msg)

    def note(self, msg: str) -> None:
        self.info.append(msg)


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def schema_validate(ir: dict, schema_path: Path, rpt: Report) -> None:
    try:
        import jsonschema  # type: ignore
    except Exception:
        rpt.note("未安装 jsonschema，跳过 JSON Schema 结构校验（仅做内置检查）。")
        return
    try:
        schema = load_json(schema_path)
    except Exception as exc:
        rpt.warn(f"无法读取 schema {schema_path}: {exc}")
        return
    # 兼容不同 jsonschema 版本：优先 2020-12，回退到可用的最新 validator。
    validator = None
    for attr in ("Draft202012Validator", "Draft201909Validator", "Draft7Validator"):
        cls = getattr(jsonschema, attr, None)
        if cls is not None:
            try:
                validator = cls(schema)
                break
            except Exception:
                continue
    if validator is None:
        try:
            jsonschema.validate(instance=ir, schema=schema)
            return
        except Exception as exc:
            rpt.err(f"[schema] {exc}")
            return
    for e in sorted(validator.iter_errors(ir), key=lambda x: list(x.path)):
        loc = "/".join(str(p) for p in e.path) or "(root)"
        rpt.err(f"[schema] {loc}: {e.message}")


def check_components(ir: dict, rpt: Report) -> dict[str, dict]:
    comps = ir.get("components", []) or []
    by_ref: dict[str, dict] = {}
    for c in comps:
        ref = c.get("refdes", "")
        if not REFDES_RE.match(ref):
            rpt.err(f"[component] 非法位号: {ref!r}（应形如 U1/R3/C10）")
            continue
        if ref in by_ref:
            rpt.err(f"[component] 位号重复: {ref}")
        by_ref[ref] = c
        mpn = (c.get("mpn") or "").strip()
        if not c.get("placeholder") and (not mpn or mpn.upper() == "TBD"):
            rpt.warn(f"[bom] {ref} 缺真实 MPN（制造就绪前需选型确认）")
        if c.get("placeholder"):
            rpt.note(f"[bom] {ref} 为占位件，选型阶段需确认真实引脚数/封装")
    if not by_ref:
        rpt.err("[component] components 为空")
    return by_ref


def check_nets(ir: dict, comps: dict[str, dict], rpt: Report) -> dict[str, dict]:
    nets = ir.get("nets", []) or []
    by_name: dict[str, dict] = {}
    rail_nodes: dict[str, list[str]] = {}
    for n in nets:
        name = n.get("name", "")
        if not name:
            rpt.err("[net] 存在无名网络")
            continue
        if name in by_name:
            rpt.err(f"[net] 网名重复: {name}")
        by_name[name] = n
        cls = n.get("class")
        if cls not in NET_CLASSES:
            rpt.err(f"[net] {name} 的 class 非法: {cls!r}（允许: {sorted(NET_CLASSES)}）")
        nodes = n.get("nodes", []) or []
        # 连接点引用的元件必须存在
        for node in nodes:
            m = NODE_RE.match(node)
            if not m:
                rpt.err(f"[net] {name} 的连接点格式非法: {node!r}（应形如 U1.7）")
                continue
            ref = m.group(1)
            if ref not in comps:
                rpt.err(f"[net] {name} 引用了不存在的元件: {ref}")
        # 悬空检查
        if len(nodes) < 2 and not n.get("single_ended_ok") and cls != "nc":
            rpt.err(f"[net] {name} 只有 {len(nodes)} 个连接点（疑似悬空；如有意请置 single_ended_ok 或 class=nc）")
        # 差分检查
        if cls == "diff" and not n.get("diff_partner"):
            rpt.warn(f"[net] 差分网 {name} 未指定 diff_partner")
        if cls == "power":
            rail_nodes[name] = nodes
    if not any((n.get("class") == "gnd") for n in nets):
        rpt.err("[net] 未发现 gnd 网（每个设计都应有地）")
    return by_name


def check_power_tree(ir: dict, nets: dict[str, dict], rpt: Report) -> None:
    arch = ir.get("architecture") or {}
    tree = arch.get("power_tree") or []
    if not tree:
        rpt.warn("[arch] 未给出 power_tree（建议在架构阶段列清每条 rail 的电压/电流预算/余量）")
        return
    for rail in tree:
        name = rail.get("rail")
        if name and name not in nets:
            rpt.err(f"[arch] 电源树 rail {name} 在 nets 中没有对应网络")
        if rail.get("current_budget_a") is None:
            rpt.warn(f"[arch] rail {name} 缺 current_budget_a（无法核电流余量）")


def check_decoupling(ir: dict, comps: dict[str, dict], nets: dict[str, dict], rpt: Report) -> None:
    """每个需要去耦的元件电源脚所在的 power 网上，应至少有一个电容。"""
    # 建立 net -> set(refdes of caps)
    cap_refs = {ref for ref, c in comps.items() if (c.get("type") in ("cap", "capacitor"))}
    net_caps: dict[str, set[str]] = {}
    for name, n in nets.items():
        s = set()
        for node in n.get("nodes", []) or []:
            m = NODE_RE.match(node)
            if m and m.group(1) in cap_refs:
                s.add(m.group(1))
        net_caps[name] = s
    # node -> nets index
    node_to_nets: dict[str, str] = {}
    for name, n in nets.items():
        for node in n.get("nodes", []) or []:
            node_to_nets[node] = name
    for ref, c in comps.items():
        if not c.get("decouple_required", True):
            continue
        for pin in c.get("power_pins", []) or []:
            node = f"{ref}.{pin}"
            net = node_to_nets.get(node)
            if not net:
                rpt.warn(f"[decouple] {ref} 的电源脚 {pin} 未连到任何网络（检查 nets 是否包含 {node}）")
                continue
            if nets.get(net, {}).get("class") not in ("power",):
                continue
            if not net_caps.get(net):
                rpt.warn(f"[decouple] {ref}.{pin} 所在电源网 {net} 上未发现去耦电容（按数据手册就近加 100nF 等）")


def check_naming(ir: dict, nets: dict[str, dict], rpt: Report) -> None:
    for name, n in nets.items():
        if n.get("class") == "gnd" and name.upper() not in ("GND", "AGND", "DGND", "PGND", "GNDA", "GNDD"):
            rpt.note(f"[naming] 地网名 {name} 不在常见集（GND/AGND/DGND/...），确认是否有意")


def main() -> int:
    ap = argparse.ArgumentParser(description="Design IR 离线校验（Gate-1）")
    ap.add_argument("ir", type=Path, help="IR JSON 文件")
    ap.add_argument("--schema", type=Path, default=DEFAULT_SCHEMA)
    ap.add_argument("--json", action="store_true", help="以 JSON 输出报告")
    args = ap.parse_args()

    rpt = Report()
    try:
        ir = load_json(args.ir)
    except Exception as exc:
        print(f"无法读取 IR: {exc}", file=sys.stderr)
        return 2
    if not isinstance(ir, dict):
        print("IR 顶层必须是对象", file=sys.stderr)
        return 2

    schema_validate(ir, args.schema, rpt)
    comps = check_components(ir, rpt)
    nets = check_nets(ir, comps, rpt)
    check_power_tree(ir, nets, rpt)
    check_decoupling(ir, comps, nets, rpt)
    check_naming(ir, nets, rpt)

    if args.json:
        print(json.dumps({
            "ok": not rpt.errors,
            "errors": rpt.errors,
            "warnings": rpt.warnings,
            "info": rpt.info,
        }, ensure_ascii=False, indent=2))
    else:
        print(f"IR 校验: {args.ir}")
        print(f"  component: {len(comps)}  net: {len(nets)}")
        if rpt.errors:
            print(f"\n❌ ERROR ({len(rpt.errors)}):")
            for m in rpt.errors:
                print(f"  - {m}")
        if rpt.warnings:
            print(f"\n⚠️  WARNING ({len(rpt.warnings)}):")
            for m in rpt.warnings:
                print(f"  - {m}")
        if rpt.info:
            print(f"\nℹ️  INFO ({len(rpt.info)}):")
            for m in rpt.info:
                print(f"  - {m}")
        print()
        print("结果:", "通过（0 error）" if not rpt.errors else f"未通过（{len(rpt.errors)} error）")
    return 1 if rpt.errors else 0


if __name__ == "__main__":
    sys.exit(main())
