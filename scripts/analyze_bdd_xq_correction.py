#!/usr/bin/env python3

import os
import sys
from pathlib import Path
import csv
import itertools
import numpy as np

import dd.autoref as _bdd
import dd.bdd as bdd_mod

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import networkx as nx

REPO_ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = REPO_ROOT / "results" / "bdd_xq_correction"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

Q_VAL = 3329  # 13'd3329 = 0b0110100000001
VARS_13 = [f"r{i}" for i in range(12, -1, -1)]  # r12, r11, ..., r0

def get_node_counts(bdd_obj, root):
    """
    Count internal decision nodes and total DAG nodes (including terminal node 1).
    Counting convention:
    - Internal nodes: number of non-terminal variable test vertices.
    - Total nodes: internal decision nodes + 1 terminal sink (in BDDs with complemented edges).
    """
    visited = set()
    succ = bdd_obj._bdd._succ
    st = [abs(int(root))]
    while st:
        u = st.pop()
        if u not in visited:
            visited.add(u)
            if u != 1:
                _, l, h = succ[u]
                if l is not None:
                    st.append(abs(l))
                if h is not None:
                    st.append(abs(h))
    int_nodes = len([u for u in visited if u != 1])
    tot_nodes = len(visited)
    return int_nodes, tot_nodes

def evaluate_variable_orders():
    """Evaluate ROBDD node metrics across representative variable orderings."""
    expr_ge = "r12 | (r11 & r10 & (r9 | (r8 & (r7 | r6 | r5 | r4 | r3 | r2 | r1 | r0))))"
    
    orderings = [
        ("MSB-first (Natural)", [f"r{i}" for i in range(12, -1, -1)]),
        ("LSB-first (Reversed)", [f"r{i}" for i in range(13)]),
        ("Interleaved (Odd-Even)", [f"r{i}" for i in [12, 0, 11, 1, 10, 2, 9, 3, 8, 4, 7, 5, 6]]),
        ("Mid-out (Center-to-Ends)", [f"r{i}" for i in [6, 7, 5, 8, 4, 9, 3, 10, 2, 11, 1, 12, 0]]),
        ("Reverse-Grouped (High/Low Inverted)", [f"r{i}" for i in [0, 1, 2, 3, 4, 5, 6, 7, 8, 12, 11, 10, 9]]),
        ("Adversarial Permutation", [f"r{i}" for i in [0, 12, 1, 11, 2, 10, 3, 9, 4, 8, 5, 7, 6]]),
    ]
    
    records = []
    best_bdd = None
    best_u = None
    best_order_name = None
    best_order_seq = None
    min_int_nodes = 999999
    
    for name, v_order in orderings:
        bdd = _bdd.BDD()
        for v in v_order:
            bdd.add_var(v)
        u = bdd.add_expr(expr_ge)
        int_init, tot_init = get_node_counts(bdd, u)
        mgr_init = len(bdd)
        
        # Apply Rudell's variable sifting
        bdd_mod.reorder(bdd._bdd)
        int_sift, tot_sift = get_node_counts(bdd, u)
        mgr_sift = len(bdd)
        
        records.append({
            "name": name,
            "order": ", ".join(v_order),
            "init_internal_nodes": int_init,
            "init_total_nodes": tot_init,
            "init_mgr_nodes": mgr_init,
            "sift_internal_nodes": int_sift,
            "sift_total_nodes": tot_sift,
            "sift_mgr_nodes": mgr_sift,
        })
        
        if int_init < min_int_nodes:
            min_int_nodes = int_init
            best_bdd = bdd
            best_u = u
            best_order_name = name
            best_order_seq = v_order
            
    return records, best_bdd, best_u, best_order_name, best_order_seq

def generate_truth_table():
    """
    Generate truth table over the full 13-bit input domain [0, 8191].
    Columns:
      x_dec, r12..r0, in_valid_range_mul (r <= 4903), rtl_borrow_zero, math_ge_3329, is_equivalent
    """
    csv_path = OUTPUT_DIR / "truth_table.csv"
    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow([
            "x_dec", "r12", "r11", "r10", "r9", "r8", "r7", "r6", "r5", "r4", "r3", "r2", "r1", "r0",
            "in_valid_range_mul", "in_valid_range_add", "rtl_sub_borrow_zero", "math_ge_3329", "boolean_formula"
        ])
        
        for x in range(8192):
            bits = [(x >> i) & 1 for i in range(12, -1, -1)]
            in_mul = 1 if x <= 4903 else 0
            in_add = 1 if x <= 6656 else 0
            
            # RTL 13-bit subtraction: r_minus_q = r - 3329
            diff = (x - Q_VAL) & 0x1FFF
            borrow_zero = 1 if ((diff >> 12) & 1) == 0 else 0
            
            # Mathematical condition: x >= 3329
            ge_q = 1 if x >= Q_VAL else 0
            
            # Explicit bit-level Boolean formula:
            x12, x11, x10, x9, x8 = bits[0], bits[1], bits[2], bits[3], bits[4]
            any_low = 1 if any(bits[5:]) else 0
            formula_val = 1 if (x12 or (x11 and x10 and (x9 or (x8 and any_low)))) else 0
            
            writer.writerow([x] + bits + [in_mul, in_add, borrow_zero, ge_q, formula_val])
            
    print(f"Generated complete truth table (8,192 entries) at: {csv_path}")

def plot_best_bdd(bdd, u, order_name):
    """Render the optimal ROBDD to a high-resolution PNG diagram using NetworkX and Matplotlib."""
    g = bdd_mod.to_nx(bdd._bdd, roots=[abs(int(u))])
    
    fig, ax = plt.subplots(figsize=(10, 12), dpi=300)
    
    # Hierarchical level-based layout
    levels = {}
    for node, data in g.nodes(data=True):
        lvl = data.get("level", 0)
        if lvl not in levels:
            levels[lvl] = []
        levels[lvl].append(node)
        
    pos = {}
    max_lvl = max(levels.keys())
    for lvl, nodes in levels.items():
        y = max_lvl - lvl
        num_nodes = len(nodes)
        for i, node in enumerate(nodes):
            x = (i + 1) / (num_nodes + 1) * 10
            pos[node] = (x, y)
            
    # Node labeling
    node_labels = {}
    node_colors = []
    var_names = [f"r{i}" for i in range(12, -1, -1)]
    
    for node, data in g.nodes(data=True):
        lvl = data.get("level", 0)
        if node == 1:
            node_labels[node] = "1"
            node_colors.append("#22c55e")  # Green terminal
        else:
            var_name = var_names[lvl] if lvl < len(var_names) else f"v{lvl}"
            node_labels[node] = f"{var_name}"
            node_colors.append("#60a5fa")  # Blue internal decision node

    # Edge drawing: 0-edges (dashed red/gray) and 1-edges (solid blue)
    dashed_edges = []
    solid_edges = []
    
    for u_node, v_node, edata in g.edges(data=True):
        val = edata.get("value", False)
        comp = edata.get("complement", False)
        if val:
            solid_edges.append((u_node, v_node))
        else:
            dashed_edges.append((u_node, v_node))
            
    nx.draw_networkx_nodes(g, pos, node_color=node_colors, node_size=1200, edgecolors="#1e293b", linewidths=1.5, ax=ax)
    nx.draw_networkx_labels(g, pos, labels=node_labels, font_size=11, font_weight="bold", font_color="#0f172a", ax=ax)
    
    nx.draw_networkx_edges(g, pos, edgelist=solid_edges, edge_color="#2563eb", width=2.0, arrows=True, arrowsize=18, ax=ax)
    nx.draw_networkx_edges(g, pos, edgelist=dashed_edges, edge_color="#dc2626", width=2.0, style="dashed", arrows=True, arrowsize=18, ax=ax)
    
    # Legend
    from matplotlib.lines import Line2D
    legend_elements = [
        Line2D([0], [0], color="#2563eb", lw=2, label="1-edge (True / High)"),
        Line2D([0], [0], color="#dc2626", lw=2, linestyle="--", label="0-edge (False / Low)"),
        Line2D([0], [0], marker='o', color='w', markerfacecolor='#60a5fa', markeredgecolor='#1e293b', markersize=10, label='Decision Node (r[i])'),
        Line2D([0], [0], marker='s', color='w', markerfacecolor='#22c55e', markeredgecolor='#1e293b', markersize=10, label='Terminal Node (1)'),
    ]
    ax.legend(handles=legend_elements, loc="upper right", fontsize=10, frameon=True)
    
    ax.set_title(f"ROBDD for Modular Reduction Correction: x >= 3329\nVariable Ordering: {order_name} (13 Internal Nodes, 14 Total DAG Nodes)", fontsize=13, fontweight="bold", pad=15)
    ax.axis("off")
    plt.tight_layout()
    
    out_img = OUTPUT_DIR / "bdd_best_order.png"
    plt.savefig(out_img, dpi=300)
    plt.close()
    print(f"Saved optimal ROBDD diagram to: {out_img}")

def main():
    print("=" * 80)
    print("ROBDD ANALYSIS FOR MODULAR ARITHMETIC CORRECTION (x >= q = 3329)")
    print("Circuit Target: rtl/arithmetic/mod_mul.v (and mod_add.v)")
    print("=" * 80)
    
    # 1. Variable orderings
    records, best_bdd, best_u, best_order_name, best_order_seq = evaluate_variable_orders()
    
    # Save variable order comparison CSV
    order_csv = OUTPUT_DIR / "variable_order_comparison.csv"
    with open(order_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow([
            "Ordering Scheme", "Variable Sequence", 
            "Initial Internal Nodes", "Initial Total Nodes", "Initial Manager Nodes",
            "Sifted Internal Nodes", "Sifted Total Nodes", "Sifted Manager Nodes"
        ])
        for r in records:
            writer.writerow([
                r["name"], r["order"],
                r["init_internal_nodes"], r["init_total_nodes"], r["init_mgr_nodes"],
                r["sift_internal_nodes"], r["sift_total_nodes"], r["sift_mgr_nodes"]
            ])
    print(f"Saved variable order comparison to: {order_csv}")
    
    # 2. Generate Truth Table
    generate_truth_table()
    
    # 3. Plot BDD
    plot_best_bdd(best_bdd, best_u, best_order_name)
    
    print("=" * 80)

if __name__ == "__main__":
    main()
