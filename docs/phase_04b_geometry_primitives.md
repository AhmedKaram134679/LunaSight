# LunaSight — Phase 04B: Geometry Primitives
## Technical Implementation Specification

- **Status:** SPECIFICATION ONLY (Documentation-Only Task)
- **Approved Baseline:** Phase 04A Scientific Contract & Architecture (`docs/phase_04a_scientific_contract.md`, commit `d176bca72d408b5c9ba3da0fb4ab03fe24698628`)
- **Target Feature Package:** `lib/features/scientific_geometry/`
- **Target Test Suite:** `test/features/scientific_geometry/`

---

## 1. Purpose and Scope

### 1.1 Purpose
Phase 04B establishes the fundamental, implementation-ready mathematical primitives for the LunaSight scientific geometry engine. The mission planning, lunar ephemeris integration, and visibility analysis layers in LunaSight require high-precision 3D vector calculations and strictly typed physical quantities. Phase 04B defines these bedrock domain value objects—namely `Angle`, `Distance`, `Vector3`, `ReferenceFrameId`, `CoordinateOriginId`, `VectorUnit`, `FramedVector3`, and `ScientificComputationException`.

### 1.2 Scope Boundaries
This specification defines domain-level value objects and exceptions adhering strictly to Clean Architecture principles:
- **Included:**
  - Strongly typed physical quantities: `Angle` (radians canonical), `Distance` (meters canonical, non-negative magnitude).
  - High-precision, unit-neutral `Vector3` primitive with runtime validation, robust scaled normalization, and standard vector algebra.
  - Strongly typed frame and origin identifiers (`ReferenceFrameId`, `CoordinateOriginId`, `VectorUnit`).
  - Metadata-preserving `FramedVector3` combining `Vector3` with its spatial frame orientation, origin, and component unit.
  - Dedicated domain-level exception `ScientificComputationException` with stable error codes, descriptive diagnostic message, and validated immutable primitive context.
  - Comprehensive unit and numerical test matrix with operation-specific scale-aware tolerances.
- **Explicitly Excluded (Deferred to later subphases and phases):**
  - Frame transformations and rotation matrices ($R_{A \to B}$) — deferred to Phase 04C.
  - Selenographic coordinate conversions and spherical/ellipsoidal conversions.
  - Local Horizon Basis ($\{\hat{E}, \hat{N}, \hat{U}\}$) construction.
  - Polar singularity boundary policy implementations.
  - Horizons API client networking and ephemeris ingestion.
  - SPICE toolkit bindings or kernel loaders.
  - DEM sampling, elevation lookups, and line-of-sight calculations.

---

## 2. Architectural Boundaries and Principles

### 2.1 Clean Architecture Isolation
The geometry primitives reside strictly in `lib/features/scientific_geometry/domain/`:
1. **Zero Flutter UI Coupling:** No dependencies on `package:flutter/material.dart`, `package:flutter/widgets.dart`, or UI layout elements. Only `package:meta/meta.dart` (`@immutable`) is permitted for value-object immutability annotations.
2. **Zero Network / I/O Coupling:** No HTTP clients, no filesystem access, no PDS or DEM parsing dependencies.
3. **Zero Presentation / Router Coupling:** No route observers, viewmodels, or state notifiers.
4. **Zero External Math Packages:** Pure Dart standard library (`dart:math`) using IEEE-754 64-bit double-precision floating-point arithmetic.

```
lib/features/scientific_geometry/
├── domain/
│   ├── failures/
│   │   └── scientific_computation_exception.dart
│   ├── quantities/
│   │   ├── angle.dart
│   │   └── distance.dart
│   └── value_objects/
│       ├── coordinate_origin_id.dart
│       ├── framed_vector3.dart
│       ├── reference_frame_id.dart
│       ├── vector3.dart
│       └── vector_unit.dart
└── scientific_geometry.dart (feature barrel export)
```

### 2.2 Immutability and Value Semantics
Every primitive and value object in this subphase is an immutable value object:
- All fields are `final`.
- Value equality (`operator ==`) and consistent `hashCode` implementations must be provided.
- Value objects are thread-safe and side-effect free.

### 2.3 Strict Rejection of Non-Finite States [APPROVED PROJECT CONTRACT]
In accordance with Section 12.1 of `docs/phase_04a_scientific_contract.md`:
- Every constructor, factory method, and mathematical operation must reject `double.nan`, `double.infinity`, and `double.negativeInfinity`.
- Any operation that would produce or encounter a non-finite floating-point state must throw an explicit, structured `ScientificComputationException` before returning an invalid instance.

---

## 3. Public API Specification & Value Semantics

### 3.1 Physical Quantities

#### 3.1.1 `Angle`
Encapsulates a planar angle in double precision.
- **Canonical Storage:** Radians (`final double radians`).
- **Constructors:**
  - `Angle.fromRadians(double radians)`: Validates that `radians` is finite; otherwise throws `ScientificComputationException(code: 'NON_FINITE_VALUE')`.
  - `Angle.fromDegrees(double degrees)`: Validates that `degrees` is finite; computes `radians = degrees * (math.pi / 180.0)`; validates finite result; otherwise throws `ScientificComputationException(code: 'NON_FINITE_VALUE')`.
- **Accessors:**
  - `double get inRadians => radians;`
  - `double get inDegrees`: Evaluates `radians * (180.0 / math.pi)`. If multiplication results in non-finite, throws `ScientificComputationException(code: 'ARITHMETIC_OVERFLOW')`.
- **Validation Semantics:**
  - Must reject non-finite inputs (`radians.isNaN` or `radians.isInfinite`), throwing `ScientificComputationException(code: 'NON_FINITE_VALUE')`.
  - **Zero Wrapping / Clamping Invariant:** Angles must **not** be silently normalized or wrapped into $[0, 2\pi)$ or $[-\pi, +\pi]$ upon construction. Physical orientation, rotation accumulated across epochs, and raw input representations require preserving the exact signed input value. (Normalization functions, if needed in later subphases, must be explicit named methods).
- **Arithmetic:**
  - `Angle operator +(Angle other)`: Evaluates `radians + other.radians`. Throws `ScientificComputationException(code: 'ARITHMETIC_OVERFLOW')` if sum is non-finite.
  - `Angle operator -(Angle other)`: Evaluates `radians - other.radians`. Throws `ScientificComputationException(code: 'ARITHMETIC_OVERFLOW')` if difference is non-finite.
  - `Angle operator -()`: Unary negation. Evaluates `-radians`.
  - `Angle operator *(double scalar)`: Rejects non-finite scalar (`NON_FINITE_VALUE`). Throws `ScientificComputationException(code: 'ARITHMETIC_OVERFLOW')` if product is non-finite.
  - `Angle operator /(double scalar)`: Rejects non-finite scalar (`NON_FINITE_VALUE`). Rejects $s == 0.0$ or $s == -0.0$ throwing `ScientificComputationException(code: 'DIVISION_BY_ZERO')`. Throws `ScientificComputationException(code: 'ARITHMETIC_OVERFLOW')` if quotient is non-finite.
- **Comparisons & Value Equality:**
  - Implements `Comparable<Angle>` based on `radians`.
  - Standard `operator ==` (exact IEEE equality on `radians`), `hashCode`, and `toString()`.

#### 3.1.2 `Distance`
Encapsulates a physical distance or magnitude in double precision.
- **Canonical Storage:** Meters (`final double meters`).
- **Constructors:**
  - `Distance.fromMeters(double meters)`: Validates that `meters` is finite (`NON_FINITE_VALUE`); rejects negative scalar (`meters < 0.0`) with `NEGATIVE_DISTANCE`.
  - `Distance.fromKilometers(double kilometers)`: Validates that `kilometers` is finite (`NON_FINITE_VALUE`); rejects `kilometers < 0.0` (`NEGATIVE_DISTANCE`); computes `meters = kilometers * 1000.0`; validates finite result; throws `ScientificComputationException(code: 'ARITHMETIC_OVERFLOW')` if product overflows.
- **Accessors:**
  - `double get inMeters => meters;`
  - `double get inKilometers => meters / 1000.0;`
- **Validation Semantics:**
  - Must reject non-finite inputs (`meters.isNaN` or `meters.isInfinite`), throwing `ScientificComputationException(code: 'NON_FINITE_VALUE')`.
  - **Non-Negative Magnitude Invariant:** A physical `Distance` represents a geometric separation or vector magnitude and must satisfy `meters >= 0.0`. If a negative value is passed (`meters < 0.0`), the constructor must throw `ScientificComputationException(code: 'NEGATIVE_DISTANCE')`.
  - **Component Type Invariant:** `Distance` shall **not** be used as the field type for signed Cartesian vector components ($x, y, z$), which represent directional projections and can be negative. Signed spatial vector components remain untyped or unit-governed `double` values inside `Vector3` and `FramedVector3`.
- **Arithmetic:**
  - `Distance operator +(Distance other)`: Evaluates `meters + other.meters`. Throws `ScientificComputationException(code: 'ARITHMETIC_OVERFLOW')` if sum overflows finite binary64 range.
  - `Distance operator -(Distance other)`: Evaluates `meters - other.meters`. If `other.meters > meters`, throws `ScientificComputationException(code: 'NEGATIVE_DISTANCE')`.
  - `Distance operator *(double scalar)`: Rejects non-finite scalar (`NON_FINITE_VALUE`). Rejects negative scalar ($s < 0.0$) throwing `ScientificComputationException(code: 'NEGATIVE_DISTANCE')`. Throws `ScientificComputationException(code: 'ARITHMETIC_OVERFLOW')` if product overflows.
  - `Distance operator /(double scalar)`: Unambiguous error hierarchy:
    1. If `scalar.isNaN || scalar.isInfinite`: Throws `ScientificComputationException(code: 'NON_FINITE_VALUE')`.
    2. If `scalar == 0.0 || scalar == -0.0`: Throws `ScientificComputationException(code: 'DIVISION_BY_ZERO')`.
    3. If `scalar < 0.0`: Throws `ScientificComputationException(code: 'NEGATIVE_DISTANCE')`.
    4. Evaluates `meters / scalar`. If the quotient overflows to infinity, throws `ScientificComputationException(code: 'ARITHMETIC_OVERFLOW')`.
- **Comparisons & Value Equality:**
  - Implements `Comparable<Distance>` based on `meters`.
  - Standard `operator ==`, `hashCode`, and `toString()`.

#### 3.1.3 Deferral of `Velocity` and `Time`
- **Decision:** Physical quantity types for `Velocity` and `Time` are **deferred** to subsequent ephemeris ingestion subphases (Phase 04C/Phase 04D).
- **Justification:** Phase 04B strictly specifies static 3D spatial geometry primitives. No velocity vector propagation, kinematic state integration, or relativistic coordinate time conversions are executed in this subphase. Introducing stubbed velocity or time types without active ephemeris consumers violates the principle of minimal, fully testable increments.

---

### 3.2 Generic `Vector3` Primitive

A finite, immutable, unit-neutral 3D mathematical vector:
$$\vec{v} = \begin{pmatrix} x \\ y \\ z \end{pmatrix}$$

#### 3.2.1 Fields & Constructor Architecture (Resolving the Const-Constructor Contradiction)
In Dart, a constructor cannot be declared `const` if its constructor body executes runtime validation logic, non-trivial assertions, or throws custom exceptions. Sacrificing runtime validation to retain a public `const` constructor would violate the mandatory non-finite rejection invariant. Conversely, sacrificing constant canonical vectors (such as `zero`, `unitX`, `unitY`, `unitZ`) is unnecessary.

**Resolution Design:**
1. **Public Generative Constructor (Runtime Validating, Non-Const):**
   ```dart
   @immutable
   class Vector3 {
     final double x;
     final double y;
     final double z;

     Vector3(this.x, this.y, this.z) {
       if (!x.isFinite || !y.isFinite || !z.isFinite) {
         throw ScientificComputationException(
           message: 'Vector3 components must be finite numeric values. Got: ($x, $y, $z)',
           code: 'NON_FINITE_VALUE',
           context: {'x': x, 'y': y, 'z': z},
         );
       }
     }
   ```
2. **Private Const Constructor for Verified Invariants:**
   A private constructor `const Vector3._internal(this.x, this.y, this.z)` is defined without body logic.
3. **Safe Canonical Constant Instances:**
   Using the private const constructor, the class exposes verified, immutable constant instances and factory accessors:
   - `static const Vector3 zero = Vector3._internal(0.0, 0.0, 0.0);`
   - `static const Vector3 unitX = Vector3._internal(1.0, 0.0, 0.0);`
   - `static const Vector3 unitY = Vector3._internal(0.0, 1.0, 0.0);`
   - `static const Vector3 unitZ = Vector3._internal(0.0, 0.0, 1.0);`
   - Factory constructors: `factory Vector3.zero() => zero;`, `factory Vector3.unitX() => unitX;`, etc.
4. **Security Boundary:** All arbitrary user/runtime inputs must pass through the public `Vector3(x, y, z)` constructor or mathematical operators, ensuring that invalid non-finite instances can never be instantiated.

#### 3.2.2 Mathematical Operations & Intermediate Overflow Semantics
For the initial Phase 04B implementation, operations employ direct IEEE-754 binary64 component arithmetic:
1. **Vector Addition & Subtraction:**
   $$\vec{u} + \vec{v} = (u_x + v_x, u_y + v_y, u_z + v_z)^T$$
   $$\vec{u} - \vec{v} = (u_x - v_x, u_y - v_y, u_z - v_z)^T$$
   Evaluates component sums/differences. Throws `ScientificComputationException(code: 'ARITHMETIC_OVERFLOW')` if any resulting component overflows finite binary64 range.
2. **Scalar Multiplication & Division:**
   $$s \cdot \vec{v} = (s \cdot v_x, s \cdot v_y, s \cdot v_z)^T$$
   $$\vec{v} / s = (v_x / s, v_y / s, v_z / s)^T$$
   - Scalar multiplication throws `ScientificComputationException(code: 'NON_FINITE_VALUE')` if $s$ is non-finite, or `ARITHMETIC_OVERFLOW` if a product component overflows.
   - Division throws `ScientificComputationException(code: 'DIVISION_BY_ZERO')` if $s == 0.0 || s == -0.0$, `NON_FINITE_VALUE` if $s$ is non-finite, and `ARITHMETIC_OVERFLOW` if a quotient component overflows.
3. **Dot Product:**
   $$\vec{u} \cdot \vec{v} = u_x v_x + u_y v_y + u_z v_z$$
   - **Intermediate Overflow Policy [PROJECT CONTRACT]:**
     Direct component arithmetic is applied: compute pairwise products $p_x = u_x v_x$, $p_y = u_y v_y$, $p_z = u_z v_z$.
     Each product is checked for finiteness: if `!p_x.isFinite || !p_y.isFinite || !p_z.isFinite`, throw `ScientificComputationException(code: 'ARITHMETIC_OVERFLOW')`.
     Compute the sum $s = p_x + p_y + p_z$. If `!s.isFinite`, throw `ScientificComputationException(code: 'ARITHMETIC_OVERFLOW')`.
     *Note:* If an intermediate multiplication overflows, the operation throws `ARITHMETIC_OVERFLOW` even if compensatory terms in a mathematically rearranged formulation might have canceled out to a finite result. Compensated dot products (e.g. Ogita-Rump-Oishi algorithms) are deferred to later numerical refinements.
4. **Cross Product:**
   $$\vec{u} \times \vec{v} = \begin{pmatrix} u_y v_z - u_z v_y \\ u_z v_x - u_x v_z \\ u_x v_y - u_y v_x \end{pmatrix}$$
   - **Intermediate Overflow Policy [PROJECT CONTRACT]:**
     Direct component arithmetic is applied: for each component (e.g. $c_x = u_y v_z - u_z v_y$), both products $u_y v_z$ and $u_z v_y$ are evaluated and checked for finiteness. If either product overflows, or if their subtraction produces non-finite values, throw `ScientificComputationException(code: 'ARITHMETIC_OVERFLOW')`.
     Returns a `Vector3` passing through the validating constructor.

#### 3.2.3 Scaled Magnitude and Normalization Algorithms

##### The Mathematical Failure Modes of Naive Sum-of-Squares
A naive Euclidean magnitude calculation $\|\vec{v}\| = \sqrt{x^2 + y^2 + z^2}$ suffers from two severe IEEE-754 binary64 limitations:
1. **Squaring Overflow:** The maximum representable finite binary64 float is $\Omega \approx 1.7976931348623157 \times 10^{308}$. If any component exceeds $\sqrt{\Omega / 3} \approx 7.74 \times 10^{153}$, squaring that component results in $+\infty$. The subsequent sum and square root evaluate to $+\infty$, causing an arithmetic failure even though the actual mathematical magnitude $\sqrt{x^2 + y^2 + z^2}$ is well within representable floating-point bounds.
2. **Squaring Underflow and the Underflow-to-Zero Boundary:**
   - The smallest positive **normal** binary64 float is $2^{-1022} \approx 2.2250738585072014 \times 10^{-308}$.
   - The smallest positive **subnormal** binary64 float is $2^{-1074} \approx 4.9406564584124654 \times 10^{-324}$.
   - **Normal vs Subnormal Transition:** When $|x| < \sqrt{2^{-1022}} \approx 1.4916681462400413 \times 10^{-154}$, squaring it yields a value strictly below the normal threshold ($x^2 < 2^{-1022}$). The squared result becomes subnormal, losing significand precision bits progressively.
   - **Round-to-Nearest Midpoint Semantics for Underflow to Zero:**
     Under IEEE-754 default round-to-nearest, ties-to-even mode:
     - Half of the minimum positive subnormal value is $2^{-1075} \approx 2.4703282292062327 \times 10^{-324}$.
     - A positive squared mathematical result strictly below this midpoint ($x^2 < 2^{-1075}$) rounds to $+0.0$.
     - An exact mathematical result equal to the midpoint ($x^2 == 2^{-1075}$) also rounds to $+0.0$ because zero has an even significand (0) under ties-to-even.
     - Values above the midpoint ($x^2 > 2^{-1075}$) round to the minimum positive subnormal ($2^{-1074}$) or larger.
     - The corresponding magnitude boundary for a real number is:
       $$\sqrt{2^{-1075}} = 2^{-537.5} \approx 1.57172778 \times 10^{-162}$$
     - *Distinction Between Mathematical Midpoint and Floating-Point Multiplication:* The above decimal value represents the continuous mathematical boundary. In an actual computation, whether the floating-point instruction `x * x` produces zero depends strictly on the exact binary64 operand bits, intermediate precision, and the IEEE-754 rounding mode. Values near this decimal approximation cannot be assumed to behave identically without considering the specific bit representation.
   - If all components round to zero upon squaring, the naive sum evaluates to $+0.0$, causing subsequent normalization to erroneously throw a division-by-zero exception on non-zero vectors.

##### Algorithm 1: Scaled Magnitude (Blue's Algorithm / Maximum Component Scaling)
To guarantee numerical stability across the entire binary64 exponent dynamic range:
1. Determine the maximum absolute component:
   $$m = \max(|x|, \max(|y|, |z|))$$
2. If $m = 0.0$, return $0.0$.
3. If $m$ is non-finite, throw `ScientificComputationException(code: 'NON_FINITE_VALUE')`.
4. Scale all components by $m$:
   $$x' = x / m, \quad y' = y / m, \quad z' = z / m$$
5. Compute the scaled Euclidean sum:
   $$\|\vec{v}\| = m \cdot \sqrt{(x')^2 + (y')^2 + (z')^2}$$
6. If the final product $m \cdot \sqrt{\dots}$ overflows to infinity (which can occur only if $m$ is within a factor of $\sqrt{3}$ of $\Omega$), throw `ScientificComputationException(code: 'MAGNITUDE_OVERFLOW')`.

**Specific Guarantees of Scaled Magnitude:**
- Prevents overflow in the intermediate component squares $(x')^2, (y')^2, (z')^2$.
- Prevents the scaled sum of squares from underflowing to zero for any non-zero vector (since at least one $(x')^2 == 1.0$).
- Very small scaled component ratios may lose relative precision or underflow to zero.
- The final magnitude can overflow if the true mathematical magnitude exceeds $\Omega$; this condition is explicitly detected and reported via `MAGNITUDE_OVERFLOW`.

##### Algorithm 2: Scaled Normalization & Its Precise Guarantees
To compute the unit vector $\hat{v} = \vec{v} / \|\vec{v}\|$:
1. Determine $m = \max(|x|, \max(|y|, |z|))$.
2. **Zero-Vector Rejection:** If $m = 0.0$ (meaning $x = 0 \land y = 0 \land z = 0$ exactly), the vector has undefined direction. Throw `ScientificComputationException(code: 'ZERO_VECTOR_NORMALIZATION')`.
3. If $m$ is non-finite, throw `ScientificComputationException(code: 'NON_FINITE_VALUE')`.
4. Scale components by $m$:
   $$x' = x / m, \quad y' = y / m, \quad z' = z / m$$
5. Compute the scaled magnitude $L' = \sqrt{(x')^2 + (y')^2 + (z')^2}$.
   - **Guaranteed Invariant:** Because at least one component has $|x'/y'/z'| == 1.0$, $L' \ge 1.0$. Therefore, $L'$ can never underflow to zero or be subnormal.
   - **Precision Limitations on Disparate Components:**
     Consider a vector with disparate components: $x = 10^{300}, y = 1.0$.
     The scaled ratio $y / m = 1.0 / 10^{300} = 10^{-300}$.
     This ratio ($10^{-300}$) is fully representable as a normal binary64 value (since $10^{-300} > 2^{-1022} \approx 2.23 \times 10^{-308}$).
     However, upon squaring in the Euclidean sum, $(10^{-300})^2 = 10^{-600}$, which is far below $2^{-1075}$ and underflows completely to $+0.0$.
     Furthermore, in the sum $1.0 + (y/m)^2$, even if $(y/m)^2$ did not underflow to zero, adding a term smaller than $2^{-53} \approx 1.11 \times 10^{-16}$ to $1.0$ is swallowed by significand roundoff (machine epsilon).
     Therefore:
     1. *Relative precision:* binary64 has 53 bits of significand precision; components whose ratio to $m$ is smaller than $2^{-53}$ cannot influence the dominant norm $L'$.
     2. *Subnormal range:* ratios between $2^{-1022}$ and $2^{-1074}$ are representable as subnormals with reduced precision.
     3. *Underflow to zero:* ratios below $2^{-1075}$ round to zero.
     4. *Squaring underflow:* representable normal ratios can still square to zero.
6. The normalized components are:
   $$\hat{v} = \begin{pmatrix} x' / L' \\ y' / L' \\ z' / L' \end{pmatrix}$$
7. Return a new `Vector3` constructed from these components.

**Specific Guarantees of Scaled Normalization:**
- Prevents the scaled norm $L'$ from becoming zero due to underflow.
- Avoids overflow caused by directly squaring original large components.
- Does **not** guarantee preservation of negligible components whose ratio to the dominant component underflows or falls below significand precision.
- Does **not** promise exact mathematical normalization across the unbounded real-number continuum.

##### Threshold Policy [APPROVED PROJECT CONTRACT & PRESERVATION]
- **No Universal Arbitrary Epsilon:** The mathematical primitive `Vector3.normalize()` rejects an **exact zero vector** ($m == 0.0$).
- **No Premature Promotion:** The illustrative value $1.0 \times 10^{-12}\text{ m}$ discussed in Phase 04A is **not** hardcoded as a universal normalization threshold inside `Vector3`.
- **Reason:** As proven in Phase 04A Section 12.2, a generic `Vector3` is unit-neutral and scale-neutral. A vector with components $10^{-20}$ is mathematically well-defined and can be normalized accurately via scaled normalization, whereas a subtraction between two selenocentric radius vectors cannot resolve differences below $\sim 2.33 \times 10^{-10}\text{ m}$. Scale-dependent normalization policies belong to contextual domain validators in later subphases, not inside generic `Vector3`.

---

### 3.3 Reference Frame & Origin Identity

To prevent mixing coordinate systems, spatial directions, and centers of mass, Phase 04B specifies strongly typed identities.

#### 3.3.1 `VectorUnit`
Enumerates the physical unit associated with vector components:
```dart
enum VectorUnit {
  meters,
  kilometers,
  dimensionless,
}
```

#### 3.3.2 `ReferenceFrameId`
A strongly typed value object representing the orientation and realization of spatial axes.
- **Clarification of Frame Identity Concepts:**
  1. *Frame Orientation:* The tri-orthogonal spatial directions of axes (e.g. ICRF space-fixed axes, B1950, or rotating lunar body-fixed axes).
  2. *Frame Realization:* The concrete mathematical alignment and numerical ephemeris integration defining the axes (e.g., `DE421` vs `DE440`).
  3. *Ephemeris Version:* The planetary ephemeris kernel or integration release (e.g., `DE421`, `DE440`, `DE441`).
  4. *Reference Epoch:* The epoch at which frame axes are evaluated or anchored (e.g. J2000.0, or of-date).
     - *Architectural Decision:* The reference epoch is **not** embedded inside `ReferenceFrameId`. Ephemeris vectors and orientation matrices vary continuously with time, whereas `ReferenceFrameId` designates the formal reference frame definition. The observation epoch belongs to time-series states or ephemeris query parameters in Phase 04C/04D.
  5. *Coordinate Origin:* The spatial point defined as $(0, 0, 0)$ (strictly separated into `CoordinateOriginId`).
- **Fields:**
  - `final String name;`
  - `final int? naifId;`
  - `final String? ephemerisVersion;`
- **Identity & Equality Semantics:**
  - An NAIF ID alone does **not** prove all frame metadata are equivalent across kernels.
  - Value equality (`operator ==`) compares `name`, `naifId`, and `ephemerisVersion`.
  - Equal-looking names do not imply identical frame realizations:
    - `ReferenceFrameId.moonMeDe421 != ReferenceFrameId.moonMeDe440`
    - `ReferenceFrameId.icrf != ReferenceFrameId.j2000`
- **Standard Well-Known Realizations:**
  - `ReferenceFrameId.icrf`: Radio-source kinematically non-rotating celestial frame.
  - `ReferenceFrameId.j2000`: Dynamical/FK5 equator and equinox of J2000.0 (NAIF ID `1`). Distinct from ICRF.
  - `ReferenceFrameId.moonMeDe421`: Mean Earth / Polar Axis frame tied to DE421 (NAIF ID `31007` per `moon_080317.tf`).
  - `ReferenceFrameId.moonPaDe421`: Principal Axes frame tied to DE421 (NAIF ID `31006` per `moon_080317.tf`).
  - `ReferenceFrameId.moonMeDe440`: Mean Earth frame tied to DE440 (`MOON_ME_DE440_ME421`, NAIF ID `31009` per `moon_de440_220930.tf`).
  - `ReferenceFrameId.moonPaDe440`: Principal Axes frame tied to DE440 (`MOON_PA_DE440`, NAIF ID `31008` per `moon_de440_220930.tf`).

#### 3.3.3 `CoordinateOriginId`
A strongly typed value object representing the physical coordinate origin:
- **Fields:**
  - `final String name;`
  - `final int? naifBodyId;`
  - `final String? siteIdentifier;`
- **Standard Well-Known Origins:**
  - `CoordinateOriginId.ssb`: Solar System Barycenter (NAIF ID `0`).
  - `CoordinateOriginId.moonCenterOfMass`: Moon Center of Mass (NAIF ID `301`).
  - `CoordinateOriginId.earthCenterOfMass`: Earth Center of Mass (NAIF ID `399`).
  - `CoordinateOriginId.topocentricSite(String siteId)`: Custom surface station (e.g. Artemis candidate site).
- **Identity Invariants:**
  - A lunar surface origin is strictly non-identical to the lunar center of mass.

#### 3.3.4 `FramedVector3`
Encapsulates a mathematical `Vector3` bound to its physical coordinate metadata:
```dart
@immutable
class FramedVector3 {
  final Vector3 vector;
  final ReferenceFrameId frame;
  final CoordinateOriginId origin;
  final VectorUnit unit;

  const FramedVector3({
    required this.vector,
    required this.frame,
    required this.origin,
    required this.unit,
  });
}
```
- **Arithmetic Deferral Invariant:**
  - Mathematical arithmetic operators (`+`, `-`, `*`) are **not** defined directly on `FramedVector3` in Phase 04B.
  - *Reasoning:* Adding or subtracting vectors across different reference frames, origins, or units is mathematically and physically invalid without explicit coordinate translations and rotation matrices. Defining naive component-wise arithmetic on `FramedVector3` would violate the core architectural boundary established in Phase 04A. Frame-aware spatial algebra is deferred to Phase 04C.
- **Unit Conversion Contract (`toUnit`):**
  - Allowed conversions:
    - `meters` $\to$ `kilometers`: Divides components by $1,000.0$.
    - `kilometers` $\to$ `meters`: Multiplies components by $1,000.0$. Throws `ARITHMETIC_OVERFLOW` if multiplication overflows finite binary64 range.
    - `dimensionless` $\to$ `dimensionless`: No numerical scaling; returns identical instance.
    - Any attempt to convert between `dimensionless` and `meters` or `kilometers` is strictly rejected:
      Throws `ScientificComputationException(code: 'UNIT_MISMATCH', message: 'Cannot convert between dimensionless unit and dimensional distance units.')`.
  - Frame orientation (`frame`) and coordinate origin (`origin`) metadata are preserved exactly without alteration.

---

### 3.4 Scientific Failure Contract & Enforceable Context Immutability

To prevent unhandled exceptions, diagnostic state tampering, or exposing raw system stack traces to operators, Phase 04B specifies a dedicated domain exception with an immutable scalar whitelist:

```dart
@immutable
class ScientificComputationException implements Exception {
  final String message;
  final String code;
  final Map<String, Object?> context;

  ScientificComputationException({
    required this.message,
    required this.code,
    Map<String, Object?> context = const {},
  }) : context = _validateAndFreezeContext(context);

  static Map<String, Object?> _validateAndFreezeContext(Map<String, Object?> raw) {
    final copy = <String, Object?>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value == null || value is num || value is String || value is bool) {
        copy[entry.key] = value;
      } else {
        throw ArgumentError(
          'ScientificComputationException context only supports immutable primitives '
          '(String, int, double, bool, null). Got ${value.runtimeType} for key "${entry.key}".',
        );
      }
    }
    return Map.unmodifiable(copy);
  }

  @override
  String toString() => 'ScientificComputationException($code: $message, context: $context)';
}
```

#### Context Immutability & Diagnostic Value Model:
- **Enforced Scalar Whitelist:** Only `String`, `int`, `double`, `bool`, and `null` are permitted as values in `context`.
- **Rejection of Mutable Objects:** Any mutable collections (`List`, `Map`, `Set`) or arbitrary domain objects are strictly rejected with an `ArgumentError` during construction.
- **Unmodifiable Map:** The resulting map is defensively copied and wrapped in `Map.unmodifiable`.
- **Immutability Scope:** This ensures that all entries in the map are inherently immutable primitives and the map container cannot be altered. *Note:* This is a targeted scalar-whitelist pattern for diagnostic metadata, not a general-purpose deep-freezing engine for arbitrary object graphs.

#### Stable Error Codes:
- `NON_FINITE_VALUE`: Encountered `NaN`, `+Infinity`, or `-Infinity` in inputs or arguments.
- `NEGATIVE_DISTANCE`: Attempted to construct a `Distance` with a negative scalar, subtract a larger distance from a smaller distance, or multiply/divide by a negative scalar.
- `ZERO_VECTOR_NORMALIZATION`: Attempted to normalize a vector whose components are all exactly zero ($m == 0.0$).
- `DIVISION_BY_ZERO`: Division by zero scalar ($s == 0.0 || s == -0.0$) in vector or quantity arithmetic.
- `MAGNITUDE_OVERFLOW`: Vector magnitude calculation exceeded IEEE-754 binary64 range.
- `ARITHMETIC_OVERFLOW`: A mathematical operation on finite inputs produced an unrepresentable infinite result, or intermediate multiplication in dot/cross products overflowed.
- `UNIT_MISMATCH`: Unit conversion attempted with incompatible unit specifications (e.g. dimensionless to meters).

---

## 4. Numerical Verification Plan & Test Matrix

All tests shall reside in `test/features/scientific_geometry/` and execute as deterministic Dart unit tests without Flutter dependencies.

### 4.1 Operation-Specific Scale-Aware Tolerances
Floating-point comparisons must never use exact equality (`==`), except when checking for exact zeros or identical binary representations. Tolerances are scale-aware test acceptance values:
- **Angle Conversion Tolerance ($\epsilon_\theta$):**
  - Proposed test tolerance: $\epsilon_\theta = 1.0 \times 10^{-12}\text{ rad}$ for degrees $\leftrightarrow$ radians conversions.
- **Normalized Vector Unit Magnitude Tolerance ($\epsilon_{\text{norm}}$):**
  - Proposed test tolerance: $\epsilon_{\text{norm}} = 1.0 \times 10^{-15}$ (dimensionless) for verifying $\|\hat{v}\| \approx 1.0$.
  - *Verification Requirement:* This tolerance is a **proposed test acceptance value**, not a universal mathematical bound. It must be validated during Phase 04B implementation against analytically known unit vectors, multiple magnitude scales ($10^{-200}$ to $10^{200}$), mixed-exponent components, and independent high-precision expected values.
- **Distance Scaling Tolerance ($\epsilon_d$):**
  - Proposed test tolerance: $\epsilon_d = 1.0 \times 10^{-12}\text{ m}$ for general distance arithmetic, or exact IEEE representation where applicable.
- *Status:* All tolerances are **PROPOSED IMPLEMENTATION TOLERANCES** and are not approved as permanent scientific constants until implementation tests and independent verification justify their adoption.

### 4.2 Test Matrix (Strictly Restricted to Phase 04B Primitives)

| Component | Test Case | Input / Scenario | Expected Analytical Result / Behavior |
|:---|:---|:---|:---|
| `Angle` | Degrees to Radians | $180.0°$, $90.0°$, $45.0°$, $0.0°$, $-90.0°$ | $\pi$, $\pi/2$, $\pi/4$, $0.0$, $-\pi/2$ within $\epsilon_\theta$ |
| `Angle` | Radians to Degrees | $\pi$, $2\pi$, $-\pi/4$ | $180.0°$, $360.0°$, $-45.0°$ within $\epsilon_\theta \times (180/\pi)$ |
| `Angle` | Non-Finite Input Rejection | `double.nan`, `double.infinity`, `double.negativeInfinity` | Throws `ScientificComputationException(code: 'NON_FINITE_VALUE')` |
| `Angle` | Preserve Signed Value | $-720.0°$, $+1080.0°$ | Preserved exactly, no modulo $360°$ wrapping |
| `Angle` | Arithmetic & Overflow | $\text{Angle}(\pi) + \text{Angle}(\pi)$, $\text{Angle}(10^{308}) \times 10.0$ | Adds correctly; throws `ARITHMETIC_OVERFLOW` on overflow |
| `Angle` | Division by Zero | $\text{Angle}(\pi) / 0.0$, $\text{Angle}(\pi) / (-0.0)$ | Throws `ScientificComputationException(code: 'DIVISION_BY_ZERO')` |
| `Distance` | Meters to Kilometers | $1,737,400.0\text{ m}$, $1,000.0\text{ m}$ | $1,737.4\text{ km}$, $1.0\text{ km}$ exactly |
| `Distance` | Kilometers to Meters Overflow | `Distance.fromKilometers(1e306)` | Throws `ScientificComputationException(code: 'ARITHMETIC_OVERFLOW')` |
| `Distance` | Negative Rejection | $-0.001\text{ m}$, $-1,000.0\text{ m}$ | Throws `ScientificComputationException(code: 'NEGATIVE_DISTANCE')` |
| `Distance` | Non-Finite Input Rejection | `double.nan`, `double.infinity` | Throws `ScientificComputationException(code: 'NON_FINITE_VALUE')` |
| `Distance` | Subtraction Boundary | $100\text{ m} - 150\text{ m}$ | Throws `ScientificComputationException(code: 'NEGATIVE_DISTANCE')` |
| `Distance` | Unambiguous Division Semantics | $100\text{ m} / 0.0$, $100\text{ m} / (-2.0)$, $100\text{ m} / \text{NaN}$ | Throws `DIVISION_BY_ZERO`; throws `NEGATIVE_DISTANCE`; throws `NON_FINITE_VALUE` |
| `Vector3` | Non-Const Validating Constructor | `Vector3(1.0, double.nan, 3.0)` | Throws `ScientificComputationException(code: 'NON_FINITE_VALUE')` |
| `Vector3` | Canonical Const Instances | `Vector3.zero`, `Vector3.unitX`, `unitY`, `unitZ` | Correct components, exact immutable instances |
| `Vector3` | Addition / Subtraction | $(1, 2, 3) + (4, 5, 6)$ | $(5, 7, 9)$ exactly |
| `Vector3` | Addition Overflow | $(10^{308}, 0, 0) + (10^{308}, 0, 0)$ | Throws `ScientificComputationException(code: 'ARITHMETIC_OVERFLOW')` |
| `Vector3` | Scalar Multiply / Divide | $(2, -4, 6) \cdot 0.5$, $(2, -4, 6) / 2.0$ | $(1, -2, 3)$ exactly |
| `Vector3` | Scalar Division by Zero | $(1, 2, 3) / 0.0$, $(1, 2, 3) / (-0.0)$ | Throws `ScientificComputationException(code: 'DIVISION_BY_ZERO')` |
| `Vector3` | Dot Product Invariants | $\hat{i} \cdot \hat{j}$, $\hat{i} \cdot \hat{i}$, $\vec{u} \cdot \vec{v} == \vec{v} \cdot \vec{u}$ | $0.0$, $1.0$, commutative identity |
| `Vector3` | Dot Product Intermediate Overflow | $(10^{200}, 0, 0) \cdot (10^{200}, 0, 0)$ | Throws `ScientificComputationException(code: 'ARITHMETIC_OVERFLOW')` |
| `Vector3` | Cross Product Invariants | $\hat{i} \times \hat{j}$, $\hat{j} \times \hat{k}$, $\hat{k} \times \hat{i}$, $\vec{u} \times \vec{u}$ | $\hat{k}$, $\hat{i}$, $\hat{j}$, $\vec{0}$ |
| `Vector3` | Cross Product Intermediate Overflow | $(10^{200}, 0, 0) \times (0, 10^{200}, 0)$ | Throws `ScientificComputationException(code: 'ARITHMETIC_OVERFLOW')` |
| `Vector3` | Scaled Magnitude (Large) | $(10^{200}, 10^{200}, 10^{200})$ | $\sqrt{3} \times 10^{200}$ (naive would overflow to $+\infty$) |
| `Vector3` | Scaled Magnitude (Small) | $(10^{-200}, 10^{-200}, 10^{-200})$ | $\sqrt{3} \times 10^{-200}$ (naive would underflow to $0.0$) |
| `Vector3` | Scaled Normalization | $(0, 3 \times 10^{250}, 4 \times 10^{250})$ | $(0, 0.6, 0.8)$ with unit magnitude within $\epsilon_{\text{norm}}$ |
| `Vector3` | Zero Vector Normalization | $(0.0, 0.0, 0.0)$ | Throws `ScientificComputationException(code: 'ZERO_VECTOR_NORMALIZATION')` |
| `Vector3` | Magnitude Overflow | $(10^{308}, 10^{308}, 10^{308})$ | Throws `ScientificComputationException(code: 'MAGNITUDE_OVERFLOW')` |
| `ReferenceFrameId` | Identity Separation | `moonMeDe421` vs `moonMeDe440`, `icrf` vs `j2000` | Not equal (`operator ==` returns false) |
| `CoordinateOriginId` | Origin Separation | `moonCenterOfMass` vs `topocentricSite('shackleton')` | Not equal (`operator ==` returns false) |
| `FramedVector3` | Valid Unit Conversion | $(1000, 2000, 3000)\text{ m} \to \text{km}$ | $(1, 2, 3)\text{ km}$, identical frame and origin |
| `FramedVector3` | Conversion Overflow | $(10^{306}, 0, 0)\text{ km} \to \text{m}$ | Throws `ScientificComputationException(code: 'ARITHMETIC_OVERFLOW')` |
| `FramedVector3` | Incompatible Unit Rejection | `dimensionless` $\to$ `meters` | Throws `ScientificComputationException(code: 'UNIT_MISMATCH')` |
| `FramedVector3` | Metadata Preservation | Access `vector`, `frame`, `origin`, `unit` | All fields preserve reference and value identities |
| `ScientificComputationException` | Context Map Mutation Rejection | Call `e.context['new'] = 1` | Throws `UnsupportedError` (unmodifiable map) |
| `ScientificComputationException` | Unsupported Context Value Rejection | Pass `context: {'list': [1, 2, 3]}` | Throws `ArgumentError` |
| `ScientificComputationException` | Valid Primitive Context Values | Pass `context: {'str': 'val', 'num': 42.5, 'flag': true, 'nil': null}` | Retains all primitive entries accessible |

---

## 5. Explicit Non-Goals & Prohibitions

To preserve system stability and prevent scope creep, Phase 04B strictly prohibits:
1. **No Coordinate Transformations:** No rotation matrices, Euler angle conversions, or frame shifts.
2. **No Geodetic/Selenographic Conversions:** No latitude/longitude to Cartesian vector algorithms.
3. **No Local Horizon Basis Generation:** No ENU or topocentric basis generation.
4. **No Ephemeris or Horizons I/O:** No network calls to `ssd.jpl.nasa.gov`, no vector interpolation.
5. **No SPICE Integration:** No C-bindings, no binary PCK/SPK kernel loading.
6. **No DEM Reading:** No GeoTIFF decoding, no elevation interpolation, no slope derivation.
7. **No UI or Presentation Integration:** No widgets, no state management integration.

---

## 6. Proposed File Layout

The runtime implementation of Phase 04B (to be executed in the implementation subphase) shall follow this precise directory layout:

```
lib/features/scientific_geometry/
├── domain/
│   ├── failures/
│   │   └── scientific_computation_exception.dart
│   ├── quantities/
│   │   ├── angle.dart
│   │   └── distance.dart
│   └── value_objects/
│       ├── coordinate_origin_id.dart
│       ├── framed_vector3.dart
│       ├── reference_frame_id.dart
│       ├── vector3.dart
│       └── vector_unit.dart
└── scientific_geometry.dart

test/features/scientific_geometry/
├── domain/
│   ├── failures/
│   │   └── scientific_computation_exception_test.dart
│   ├── quantities/
│   │   ├── angle_test.dart
│   │   └── distance_test.dart
│   └── value_objects/
│       ├── framed_vector3_test.dart
│       ├── reference_frame_id_test.dart
│       └── vector3_test.dart
```

---

## 7. Dependencies and Implementation Order

Phase 04B has zero external runtime package dependencies beyond pure Dart:
1. **Step 1:** Implement `ScientificComputationException` with validated immutable context.
2. **Step 2:** Implement `Angle` and `Distance` with strict validation, unambiguous division semantics, and overflow handling.
3. **Step 3:** Implement `Vector3` with non-const validating constructor, private const constructor for canonical constants, Blue's scaled magnitude/normalization algorithms, and intermediate overflow checks on dot/cross products.
4. **Step 4:** Implement `VectorUnit`, `ReferenceFrameId`, and `CoordinateOriginId`.
5. **Step 5:** Implement `FramedVector3` and unit conversions.
6. **Step 6:** Implement `scientific_geometry.dart` barrel export.
7. **Step 7:** Implement full test suite matching Section 4.2.

---

## 8. Phase 04A Preservation and Open Scientific Decisions

This specification strictly honors and preserves all scientific conclusions and open items established in `docs/phase_04a_scientific_contract.md`:
1. **LOLA Spherical Datum vs Horizons Geodetic Reference Shape [UNRESOLVED]:** Remains unresolved. `Distance` and `FramedVector3` do not assume or enforce any datum conversion between the $1,737,400\text{ m}$ LOLA spherical datum and Horizons geodetic coordinates.
2. **Spherical Cartesian Coordinate Formulation [UNRESOLVED / APPROXIMATION]:** The spherical equation $\vec{P} = (R + h)[\cos\phi\cos\lambda, \dots]^T$ remains documented as an approximation; no coordinate transformation is implemented in Phase 04B.
3. **Radial Up vs Geodetic Up vs Terrain Normal [UNRESOLVED]:** Conceptual separation is strictly preserved; basis vectors are excluded from Phase 04B.
4. **NAIF Reference Frame Identifiers [PRESERVED]:**
   - `moon_080317.tf`: `MOON_PA_DE421` (31006), `MOON_ME_DE421` (31007).
   - `moon_de440_220930.tf`: `MOON_PA_DE440` (31008), `MOON_ME_DE440_ME421` (31009), `MOON_PA` (31010), `MOON_ME` (31011).
5. **Numerical Threshold Statuses [PRESERVED]:**
   - Zero-vector normalization threshold strategy remains **UNRESOLVED**; generic `Vector3` only rejects exact zero vectors ($0, 0, 0$).
   - Polar singularity threshold ($\epsilon_{\text{pole}} = 1.0 \times 10^{-7}\text{ rad}$) remains **PROPOSED**.
   - Dimensionless matrix orthogonality loss ($\epsilon_{\text{ortho}} = 1.0 \times 10^{-15}$) remains **PROPOSED**.
   - Positional frame transformation error ($\Delta r$) remains **UNRESOLVED**.
   - Horizons acceptance tolerance ($\Delta\theta = 0.01°$) remains **UNRESOLVED**.

---

## 9. Phase 04B Acceptance Criteria

Phase 04B shall be considered complete when:
1. All domain primitives and value objects specified herein are implemented in `lib/features/scientific_geometry/domain/`.
2. All non-finite inputs, negative distances, zero-vector normalizations, arithmetic overflows, and division-by-zero operations throw `ScientificComputationException`.
3. The scaled magnitude and scaled normalization algorithms satisfy the following verifiable criteria:
   - No intermediate squaring overflow occurs in the scaled sum-of-squares calculation for any finite vector.
   - The scaled sum of squares cannot underflow to zero for any non-zero finite input vector.
   - Final magnitude overflow is correctly detected and reported via `MAGNITUDE_OVERFLOW` when the true magnitude exceeds the binary64 representable range.
   - Behavior when negligible component ratios or their squares underflow is fully documented and verified against test cases.
   - Representative large, small, and mixed-exponent vectors normalize correctly within the explicitly proposed test tolerances.
4. Automated unit test suite under `test/features/scientific_geometry/` executes with 100% pass rate.
5. `flutter analyze` reports zero errors, warnings, or lints.
6. The project roadmap in `lib/features/home/data/repositories/local_system_module_repository.dart` continues to show **Phase 04 as planned** (`ModuleStatus.planned`) until all Phase 04 subphases are completed and approved.
