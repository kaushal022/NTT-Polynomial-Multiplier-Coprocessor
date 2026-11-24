# Mathematical & RTL Derivation of the $x \ge q$ Modular Correction Logic

## 1. Context and Specification Requirements

In the course project specification (**Project details.pdf**, Section *"What to Develop"*), the project requires:
> *"Bit-reversal/twiddle-index logic and the $x \ge q$ correction as the logic-optimisation and BDD block."*

In post-quantum cryptography under **NIST FIPS 203 (ML-KEM / CRYSTALS-Kyber)**, all polynomial coefficient arithmetic is defined over the quotient ring:
$$\mathcal{R}_q = \mathbb{Z}_q[X] / (X^{256} + 1), \qquad q = 3329$$
Canonical representatives in $\mathbb{Z}_q$ must strictly reside in the range:
$$c \in [0, q-1] = [0, 3328]$$

In hardware modular arithmetic, particularly in the pipelined Barrett modular multiplier ([`rtl/arithmetic/mod_mul.v`](../../rtl/arithmetic/mod_mul.v)) and modular adder ([`rtl/arithmetic/mod_add.v`](../../rtl/arithmetic/mod_add.v)), intermediate values can exceed $q - 1$. A final correction step is required to conditionally subtract $q = 3329$ if the intermediate remainder/sum satisfies the correction threshold.

---

## 2. RTL Implementation & Signal Tracing

### 2.1 Pipelined Modular Multiplier (`rtl/arithmetic/mod_mul.v`)

In `mod_mul.v`, the 4-cycle Barrett reduction datapath computes:
1. **Cycle 1 (R1):** $24$-bit product $p = a \cdot b$ where $a, b \in [0, 3328]$ ($p \le 11{,}075{,}584$).
2. **Cycle 2 (R2):** Barrett quotient approximation $p_m = p \cdot \mu$ where $\mu = 5039$ (`BARRETT_M`).
3. **Cycle 3 (Combinational core):**
   - High quotient: $t = p_m[36:24] = \lfloor (p \cdot 5039) / 2^{24} \rfloor \approx \lfloor p / 3329 \rfloor$.
   - Low product reconstruction using Chiu & Parhi Carry4 shift-add tree ($q = 2^{11} + 2^{10} + 2^8 + 1$):
     ```verilog
     wire [12:0] t_times_q_low = {t[1:0], 11'd0} + {t[2:0], 10'd0} + {t[4:0], 8'd0} + t;
     wire [12:0] r = product_low_r2 - t_times_q_low;
     ```
4. **Correction Datapath (Lines 41–42):**
   ```verilog
   wire [12:0] r_minus_q = r - Q;
   wire [11:0] next_result = r_minus_q[12] ? r[11:0] : r_minus_q[11:0];
   ```

Here:
- The input to the correction logic is the $13$-bit intermediate remainder `r[12:0]`.
- Constant modulus `Q = 13'd3329`.
- Subtraction is executed in 13-bit precision: `wire [12:0] r_minus_q = r - Q`.
- The multiplexer select line is `r_minus_q[12]`, the most-significant sign/borrow bit.

### 2.2 Comparison Condition: $x \ge q$ vs. $x > q$

A critical design question is whether the correction logic implements $x > q$ or $x \ge q$:

- When $r < 3329$:
  $r - 3329 \in [-3329, -1]$. In 13-bit two's complement modulo $2^{13} = 8192$, this yields $[4863, 8191]$. Since all values in this range are $\ge 4096 = 2^{12}$, bit 12 is **`r_minus_q[12] = 1`**. The multiplexer selects `r[11:0]`, meaning no subtraction occurs.
- When $r \ge 3329$:
  $r - 3329 \ge 0$. For all valid remainders ($r \le 4903$), $r - 3329 \in [0, 1574]$. Since $1574 < 4096$, bit 12 is **`r_minus_q[12] = 0`**. The multiplexer selects `r_minus_q[11:0] = (r - 3329)[11:0]`.

Thus, the condition under which correction (subtraction of $q$) is triggered is:
$$\text{corr\_sel} = \neg (\text{r\_minus\_q}[12]) \iff r \ge 3329 \quad (\mathbf{x \ge q})$$

**Why $x \ge q$ is mathematically necessary over $x > q$:**
If the hardware implemented strict $x > q$, then for the exact boundary input $r = 3329$, the condition would evaluate to false, leaving $r = 3329$. Because $3329 \equiv 0 \pmod{3329}$, retaining $3329$ violates canonical ring representation $[0, 3328]$ and causes arithmetic divergence in subsequent butterfly layers. The specification's mathematical intent is strictly $x \ge q$.

---

## 3. Input Range & Don't-Care Domain Analysis

### 3.1 Valid Range for `mod_mul.v`
Exhaustive evaluation across all $3329 \times 3329 = 11{,}082{,}241$ input polynomial coefficient pairs $(a, b) \in [0, 3328]^2$ demonstrates:
$$\min(r) = 0, \qquad \max(r) = 4903$$

- **Total Possible 13-bit Values:** $2^{13} = 8192$ (from $0$ to $8191$).
- **Care Set (Valid Datapath Inputs):** $r \in [0, 4903]$ ($4,904$ inputs, $59.86\%$ of total space).
  - Sub-range $r \in [0, 3328]$ ($3,329$ inputs): $\text{corr\_sel} = 0$ (No correction).
  - Sub-range $r \in [3329, 4903]$ ($1,575$ inputs): $\text{corr\_sel} = 1$ (Subtract $q$).
- **Don't-Care Set (Unreachable States):** $r \in [4904, 8191]$ ($3,288$ inputs, $40.14\%$ of total space).

### 3.2 Valid Range for `mod_add.v`
In `mod_add.v`, the input is `sum = {1'b0, a} + {1'b0, b}`:
$$\min(\text{sum}) = 0, \qquad \max(\text{sum}) = 3328 + 3328 = 6656$$
- **Care Set:** $\text{sum} \in [0, 6656]$ ($6,657$ inputs, $81.26\%$ of total space).
- **Don't-Care Set:** $\text{sum} \in [6657, 8191]$ ($1,535$ inputs, $18.74\%$ of total space).

---

## 4. Exact Boolean Formulation

Let the 13-bit intermediate word be represented as:
$$r = \sum_{i=0}^{12} r_i \cdot 2^i = (r_{12}, r_{11}, r_{10}, r_9, r_8, r_7, r_6, r_5, r_4, r_3, r_2, r_1, r_0)_2$$

Constant modulus:
$$q = 3329_{10} = 2048 + 1024 + 256 + 1 = 0\_1101\_0000\_0001_2$$

Evaluating $r \ge 3329$ from MSB down to LSB:
1. **Bit 12:** If $r_{12} = 1$, $r \ge 4096 > 3329$. Correction is unconditionally TRUE.
2. **Bits 11–10:** If $r_{12} = 0$, both $r_{11}$ and $r_{10}$ must be 1 (since $2048 + 1024 = 3072$).
   If $r_{11} r_{10} = 0$, $r \le 3071 < 3329$.
3. **Bit 9:** If $r_{12}=0$ and $r_{11} r_{10} = 1$:
   - If $r_9 = 1$, $r \ge 3072 + 512 = 3584 > 3329$. Correction is TRUE.
4. **Bit 8:** If $r_9 = 0$:
   - If $r_8 = 0$, $r \le 3072 + 255 = 3327 < 3329$. Correction is FALSE.
   - If $r_8 = 1$, the base prefix is $3072 + 256 = 3328$.
5. **Bits 7–0:** With prefix at $3328$, $r \ge 3329 \iff r[7:0] \ge 1 \iff \bigvee_{i=0}^7 r_i = 1$.

Combining these terms yields the minimal Sum-of-Products (SOP) Boolean expression:
$$f_{\text{corr}}(r) = r_{12} \lor r_{11}r_{10}r_9 \lor r_{11}r_{10}r_8 \left( \bigvee_{i=0}^7 r_i \right)$$

Factored nested form matching decision levels:
$$f_{\text{corr}}(r) = r_{12} \lor \Big( r_{11} r_{10} \big( r_9 \lor (r_8 (r_7 \lor r_6 \lor r_5 \lor r_4 \lor r_3 \lor r_2 \lor r_1 \lor r_0)) \big) \Big)$$
