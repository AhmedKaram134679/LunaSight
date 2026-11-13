# LunaSight — Phase 04B: Geometry Primitives
## Technical Implementation Specification

- **Status:** SPECIFICATION ONLY (Documentation-Only Task)
- **Approved Baseline:** Phase 04A Scientific Contract & Architecture (`docs/phase_04a_scientific_contract.md`, commit `d176bca72d408b5c9ba3da0fb4ab03fe24698628`)
- **Target Feature Package:** `lib/features/scientific_geometry/`
- **Target Test Suite:** `test/features/scientific_geometry/`

---

## 1. Purpose and Scope

### 1.1 Purpose
Phase 04B establishes the fundamental, implementation-ready mathematical primitives for the LunaSight scientific geometry engine. The mission planning, lunar ephemeris integration, and visibility analysis layers in LunaSight require high-precision 3D vector calculations and strictly typed physical quantities. Phase 04B defines these bedrock value objects—namely `Angle`, `Distance`, `Vector3`, `ReferenceFrameId`, `CoordinateOriginId`, `VectorUnit`, `FramedVector3`, and `ScientificComputationException`.

### 1.2 Scope Boundaries
This specification defines domain-level value objects and exceptions adhering strictly to Clean Architecture principles:
- **Included:**
  - Strongly typed physical quantities: `Angle` (radians canonical), `Distance` (meters canonical, non-negative magnitude).
  - High-precision, unit-neutral `Vector3` primitive with robust scaled normalization (preventing overflow/underflow on large and small vectors) and standard vector algebra.
  - Strongly typed frame and origin identifiers (`ReferenceFrameId`, `CoordinateOriginId`, `VectorUnit`).
  - Metadata-preserving `FramedVector3` combining `Vector3` with its spatial frame orientation, origin, and unit.
  - Dedicated domain-level exception `ScientificComputationException` with stable error codes and diagnostic context.
  - Comprehensive unit and numerical test matrix with scale-aware tolerances.
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
1. **Zero Flutter UI Coupling:** No dependencies on `package:flutter/material.dart`, `package:flutter/widgets.dart`, or UI layout elements. Only `package:meta/meta.dart` (`@immutable`) is permitted for value-object immutability.
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
  - `Angle.fromRadians(double radians)`
  - `Angle.fromDegrees(double degrees)`
- **Accessors:**
  - `double get inRadians => radians;`
  - `double get inDegrees => radians * (180.0 / math.pi);`
- **Validation Semantics:**
  - Must reject non-finite inputs (`radians.isNaN` or `radians.isInfinite`), throwing `ScientificComputationException(code: 'NON_FINITE_VALUE')`.
  - **Zero Wrapping / Clamping Invariant:** Angles must **not** be silently normalized or wrapped into $[0, 2\pi)$ or $[-\pi, +\pi]$ upon construction. Physical orientation, rotation accumulated across epochs, and raw input representations require preserving the exact signed input value. (Normalization functions, if needed in later subphases, must be explicit named methods).
- **Arithmetic:**
  - `Angle operator +(Angle other)`
  - `Angle operator -(Angle other)`
  - `Angle operator -()` (unary negation)
  - `Angle operator *(double scalar)`
  - `Angle operator /(double scalar)` (rejects division by zero or non-finite scalar)
- **Comparisons & Value Equality:**
  - Implements `Comparable<Angle>` based on `radians`.
  - Standard `operator ==` (exact IEEE equality on `radians`), `hashCode`, and `toString()`.

#### 3.1.2 `Distance`
Encapsulates a physical distance or magnitude in double precision.
- **Canonical Storage:** Meters (`final double meters`).
- **Constructors:**
  - `Distance.fromMeters(double meters)`
  - `Distance.fromKilometers(double kilometers)`
- **Accessors:**
  - `double get inMeters => meters;`
  - `double get inKilometers => meters / 1000.0;`
- **Validation Semantics:**
  - Must reject non-finite inputs (`meters.isNaN` or `meters.isInfinite`), throwing `ScientificComputationException(code: 'NON_FINITE_VALUE')`.
  - **Non-Negative Magnitude Invariant:** A physical `Distance` represents a geometric separation or vector magnitude and must satisfy `meters >= 0.0`. If a negative value is passed (`meters < 0.0`), the constructor must throw `ScientificComputationException(code: 'NEGATIVE_DISTANCE')`.
  - **Component Type Invariant:** `Distance` shall **not** be used as the field type for signed Cartesian vector components ($x, y, z$), which represent directional projections and can be negative. Signed spatial vector components remain untyped or unit-governed `double` values inside `Vector3` and `FramedVector3`.
- **Arithmetic:**
  - `Distance operator +(Distance other)`
  - `Distance operator -(Distance other)` (throws if result would be `< 0.0`)
  - `Distance operator *(double scalar)` (throws if scalar is negative or non-finite)
  - `Distance operator /(double scalar)` (throws if scalar is non-positive or non-finite)
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

#### 3.2.1 Fields & Constructor
- `final double x;`
- `final double y;`
- `final double z;`
- `const Vector3(this.x, this.y, this.z)`: Validates that all components are finite; otherwise throws `ScientificComputationException(code: 'NON_FINITE_VALUE')`.
- Factory constructors:
  - `const Vector3.zero() : x = 0.0, y = 0.0, z = 0.0;`
  - Specialized unit axes: `const Vector3.unitX()`, `const Vector3.unitY()`, `const Vector3.unitZ()`.

#### 3.2.2 Mathematical Operations
1. **Vector Addition & Subtraction:**
   $$\vec{u} + \vec{v} = (u_x + v_x, u_y + v_y, u_z + v_z)^T$$
   $$\vec{u} - \vec{v} = (u_x - v_x, u_y - v_y, u_z - v_z)^T$$
   Throws `ScientificComputationException(code: 'NON_FINITE_VALUE')` if any resulting component overflows IEEE-754 finite range.
2. **Scalar Multiplication & Division:**
   $$s \cdot \vec{v} = (s \cdot v_x, s \cdot v_y, s \cdot v_z)^T$$
   $$\vec{v} / s = (v_x / s, v_y / s, v_z / s)^T$$
   Division throws `ScientificComputationException(code: 'DIVISION_BY_ZERO')` if $s = 0.0$ or if $s$ is non-finite.
3. **Dot Product:**
   $$\vec{u} \cdot \vec{v} = u_x v_x + u_y v_y + u_z v_z$$
   Returns a `double`. Throws if intermediate products or sum overflow to infinity.
4. **Cross Product:**
   $$\vec{u} \times \vec{v} = \begin{pmatrix} u_y v_z - u_z v_y \\ u_z v_x - u_x v_z \\ u_x v_y - u_y v_x \end{pmatrix}$$
   Returns a `Vector3`. Validates finiteness of all components.

#### 3.2.3 Scaled Magnitude and Normalization Algorithms

##### The Problem with Naive Sum-of-Squares
A naive calculation of Euclidean magnitude $\|\vec{v}\| = \sqrt{x^2 + y^2 + z^2}$ fails in two critical floating-point regimes:
1. **Overflow on Large Vectors:** The maximum finite binary64 float is $\Omega \approx 1.7977 \times 10^{308}$. If any component $|x| > \sqrt{\Omega / 3} \approx 7.74 \times 10^{153}$, squaring it produces $+\infty$, causing the entire magnitude to overflow to $+\infty$ even though the true mathematical magnitude is well within representable floating-point range.
2. **Underflow on Small Vectors:** The smallest positive normal binary64 float is $2^{-1022} \approx 2.225 \times 10^{-308}$. If components are smaller than $\approx 1.49 \times 10^{-154}$, squaring them flushes to zero, producing a calculated magnitude of exactly $0.0$, causing subsequent normalization to throw division-by-zero on non-zero vectors.

##### Algorithm 1: Scaled Magnitude (`Blue's Algorithm` / Maximum Component Scaling)
To guarantee numerical stability across the entire binary64 exponent dynamic range without overflow or premature underflow:
1. Determine the maximum absolute component:
   $$m = \max(|x|, \max(|y|, |z|))$$
2. If $m = 0.0$, return $0.0$.
3. If $m$ is non-finite, throw `ScientificComputationException(code: 'NON_FINITE_VALUE')`.
4. Scale all components by $m$:
   $$x' = x / m, \quad y' = y / m, \quad z' = z / m$$
5. Compute the scaled Euclidean sum:
   $$\|\vec{v}\| = m \cdot \sqrt{(x')^2 + (y')^2 + (z')^2}$$
6. If the final product $m \cdot \sqrt{\dots}$ overflows to infinity (which can occur only if $m$ is within a factor of $\sqrt{3}$ of $\Omega$), throw `ScientificComputationException(code: 'MAGNITUDE_OVERFLOW')`.

##### Algorithm 2: Scaled Normalization
To compute the unit vector $\hat{v} = \vec{v} / \|\vec{v}\|$:
1. Determine $m = \max(|x|, \max(|y|, |z|))$.
2. **Zero-Vector Rejection:** If $m = 0.0$ (meaning $x = 0 \land y = 0 \land z = 0$ exactly), the vector has undefined direction. Throw `ScientificComputationException(code: 'ZERO_VECTOR_NORMALIZATION')`.
3. If $m$ is non-finite, throw `ScientificComputationException(code: 'NON_FINITE_VALUE')`.
4. Scale components by $m$:
   $$x' = x / m, \quad y' = y / m, \quad z' = z / m$$
5. Compute the scaled magnitude $L' = \sqrt{(x')^2 + (y')^2 + (z')^2}$. Notice that because at least one component has $|x'/y'/z'| = 1.0$, $L' \ge 1.0$. Therefore, $L'$ can never underflow to zero or be subnormal.
6. The normalized components are:
   $$\hat{v} = \begin{pmatrix} x' / L' \\ y' / L' \\ z' / L' \end{pmatrix}$$
7. Verify that all components of $\hat{v}$ are finite (guaranteed mathematically by $L' \ge 1$).

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
A strongly typed value object representing the orientation of spatial axes:
- **Core Concept Distinction:**
  1. *Frame Orientation:* Spatial direction of tri-orthogonal axes.
  2. *Coordinate Origin:* Point in space defined as $(0, 0, 0)$.
  3. *Planetary Ephemeris Realization:* The numerical integration determining planetary/lunar orientations.
  4. *Reference Epoch:* Epoch at which axes are fixed.
- **Fields:**
  - `final String name;`
  - `final int? naifId;`
  - `final String? ephemerisVersion;`
- **Standard Well-Known Realizations:**
  - `ReferenceFrameId.icrf`: Radio-source kinematically non-rotating celestial frame.
  - `ReferenceFrameId.j2000`: Dynamical/FK5 equator and equinox of J2000.0 (NAIF ID `1`). Distinct from ICRF.
  - `ReferenceFrameId.moonMeDe421`: Mean Earth / Polar Axis frame tied to DE421 (NAIF ID `31007` per `moon_080317.tf`).
  - `ReferenceFrameId.moonPaDe421`: Principal Axes frame tied to DE421 (NAIF ID `31006` per `moon_080317.tf`).
  - `ReferenceFrameId.moonMeDe440`: Mean Earth frame tied to DE440 (`MOON_ME_DE440_ME421`, NAIF ID `31009` per `moon_de440_220930.tf`).
  - `ReferenceFrameId.moonPaDe440`: Principal Axes frame tied to DE440 (`MOON_PA_DE440`, NAIF ID `31008` per `moon_de440_220930.tf`).
- **Identity Invariants:**
  - Equal-looking names do not imply identical frame realizations. `moonMeDe421 != moonMeDe440` and `icrf != j2000`.

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
- **Conversion Helper:**
  - `FramedVector3 toUnit(VectorUnit newUnit)`: Allows explicit conversion between `meters` and `kilometers` (multiplying/dividing components by $1,000.0$) while preserving frame and origin identity.

---

### 3.4 Scientific Failure Contract

To prevent unhandled exceptions or exposing raw system stack traces to operators, Phase 04B specifies a dedicated domain exception:

```dart
@immutable
class ScientificComputationException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic> context;

  const ScientificComputationException({
    required this.message,
    required this.code,
    this.context = const {},
  });

  @override
  String toString() => 'ScientificComputationException($code: $message, context: $context)';
}
```

#### Stable Error Codes:
- `NON_FINITE_VALUE`: Encountered `NaN`, `+Infinity`, or `-Infinity`.
- `NEGATIVE_DISTANCE`: Attempted to construct a `Distance` with a negative scalar.
- `ZERO_VECTOR_NORMALIZATION`: Attempted to normalize a vector with zero magnitude.
- `DIVISION_BY_ZERO`: Division by zero scalar in vector or quantity arithmetic.
- `MAGNITUDE_OVERFLOW`: Vector magnitude calculation exceeded IEEE-754 binary64 range.
- `UNIT_MISMATCH`: Unit conversion attempted with incompatible unit specifications.

---

## 4. Numerical Verification Plan & Test Matrix

All tests shall reside in `test/features/scientific_geometry/` and execute as deterministic Dart unit tests without Flutter dependencies.

### 4.1 Scale-Aware Tolerances
Floating-point comparisons must never use exact equality (`==`), except when checking for exact zeros or identical binary representations. Tolerances must be scale-aware:
- For angles: $\epsilon_\theta = 1.0 \times 10^{-12}\text{ rad}$.
- For normalized vectors: $\epsilon_{\text{norm}} = 1.0 \times 10^{-15}$ (dimensionless).
- For matrix/basis orthogonality: $\epsilon_{\text{ortho}} = 1.0 \times 10^{-15}$ (dimensionless).
- For large coordinate conversions ($1.74 \times 10^6\text{ m}$): $\epsilon_r = 1.0 \times 10^{-9}\text{ m}$.

### 4.2 Test Matrix

| Component | Test Case | Input / Scenario | Expected Analytical Result / Behavior |
|:---|:---|:---|:---|
| `Angle` | Degrees to Radians | $180.0°$, $90.0°$, $45.0°$, $0.0°$, $-90.0°$ | $\pi$, $\pi/2$, $\pi/4$, $0.0$, $-\pi/2$ within $\epsilon_\theta$ |
| `Angle` | Radians to Degrees | $\pi$, $2\pi$, $-\pi/4$ | $180.0°$, $360.0°$, $-45.0°$ within $1.0 \times 10^{-10}°$ |
| `Angle` | Non-Finite Rejection | `double.nan`, `double.infinity`, `double.negativeInfinity` | Throws `ScientificComputationException(code: 'NON_FINITE_VALUE')` |
| `Angle` | Preserve Signed Value | $-720.0°$, $+1080.0°$ | Preserved exactly, no modulo $360°$ wrapping |
| `Distance` | Meters to Kilometers | $1,737,400.0\text{ m}$, $1,000.0\text{ m}$ | $1,737.4\text{ km}$, $1.0\text{ km}$ exactly |
| `Distance` | Negative Rejection | $-0.001\text{ m}$, $-1,000.0\text{ m}$ | Throws `ScientificComputationException(code: 'NEGATIVE_DISTANCE')` |
| `Distance` | Non-Finite Rejection | `double.nan`, `double.infinity` | Throws `ScientificComputationException(code: 'NON_FINITE_VALUE')` |
| `Distance` | Subtraction Boundary | $100\text{ m} - 150\text{ m}$ | Throws `ScientificComputationException(code: 'NEGATIVE_DISTANCE')` |
| `Vector3` | Addition / Subtraction | $(1, 2, 3) + (4, 5, 6)$ | $(5, 7, 9)$ exactly |
| `Vector3` | Scalar Multiply / Divide | $(2, -4, 6) \cdot 0.5$, $(2, -4, 6) / 2.0$ | $(1, -2, 3)$ exactly |
| `Vector3` | Dot Product Invariants | $\hat{i} \cdot \hat{j}$, $\hat{i} \cdot \hat{i}$, $\vec{u} \cdot \vec{v} == \vec{v} \cdot \vec{u}$ | $0.0$, $1.0$, commutative identity |
| `Vector3` | Cross Product Invariants | $\hat{i} \times \hat{j}$, $\hat{j} \times \hat{k}$, $\hat{k} \times \hat{i}$, $\vec{u} \times \vec{u}$ | $\hat{k}$, $\hat{i}$, $\hat{j}$, $\vec{0}$ |
| `Vector3` | Scaled Magnitude (Large) | $(10^{200}, 10^{200}, 10^{200})$ | $\sqrt{3} \times 10^{200}$ (naive would overflow to $+\infty$) |
| `Vector3` | Scaled Magnitude (Small) | $(10^{-200}, 10^{-200}, 10^{-200})$ | $\sqrt{3} \times 10^{-200}$ (naive would underflow to $0.0$) |
| `Vector3` | Scaled Normalization | $(0, 3 \times 10^{250}, 4 \times 10^{250})$ | $(0, 0.6, 0.8)$ with unit magnitude within $\epsilon_{\text{norm}}$ |
| `Vector3` | Zero Vector Normalization | $(0.0, 0.0, 0.0)$ | Throws `ScientificComputationException(code: 'ZERO_VECTOR_NORMALIZATION')` |
| `Vector3` | Magnitude Overflow | $(10^{308}, 10^{308}, 10^{308})$ | Throws `ScientificComputationException(code: 'MAGNITUDE_OVERFLOW')` |
| `ReferenceFrameId` | Identity Separation | `moonMeDe421` vs `moonMeDe440`, `icrf` vs `j2000` | Not equal (`operator ==` returns false) |
| `CoordinateOriginId` | Origin Separation | `moonCenterOfMass` vs `topocentricSite('shackleton')` | Not equal (`operator ==` returns false) |
| `FramedVector3` | Unit Conversion | $(1000, 2000, 3000)\text{ m} \to \text{km}$ | $(1, 2, 3)\text{ km}$, identical frame and origin |
| `FramedVector3` | Metadata Preservation | Access `vector`, `frame`, `origin`, `unit` | All fields preserve reference and value identities |

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
1. **Step 1:** Implement `ScientificComputationException`.
2. **Step 2:** Implement `Angle` and `Distance` with strict validation.
3. **Step 3:** Implement `Vector3` with Blue's scaled magnitude and normalization algorithms.
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
2. All non-finite inputs, negative distances, zero-vector normalizations, and division-by-zero operations throw `ScientificComputationException`.
3. Scaled magnitude and normalization algorithms are proven to handle extreme exponents without underflow or overflow.
4. Automated unit test suite under `test/features/scientific_geometry/` executes with 100% pass rate.
5. `flutter analyze` reports zero errors, warnings, or lints.
6. The project roadmap in `lib/features/home/data/repositories/local_system_module_repository.dart` continues to show **Phase 04 as planned** (`ModuleStatus.planned`) until all Phase 04 subphases are completed and approved.

