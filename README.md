# Deque Primitives

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)
[![CI](https://github.com/swift-primitives/swift-deque-primitives/actions/workflows/ci.yml/badge.svg)](https://github.com/swift-primitives/swift-deque-primitives/actions/workflows/ci.yml)

`Deque<S>` — a double-ended queue generic over its storage **column**. It is `Queue<S>.DoubleEnded`: the FIFO queue's generalization that pushes and pops at *both* ends in O(1). The backing is a ring (`Buffer.Ring`), so a front push retreats the head and a back push advances the tail — neither shifts elements. As with the rest of the family, copyability and capacity flow from the column: a move-only ring is zero-cost and move-only, a `Shared` ring is copy-on-write, and a bounded ring is fixed-capacity.

The element surface (`push`/`pop` at a `Position`, `peek`, `drain`) is written once against the column seam; only construction, growth, and capacity specialize per column. There is no separate bounded-deque type — the bounded ring column is the fixed-capacity story.

---

## Key Features

- **O(1) at both ends** — `push`/`pop` to `.front` or `.back` over a ring, with no element shifting.
- **Ownership from the column** — move-only by default; opt into copy-on-write value semantics by choosing a `Shared` column.
- **Fixed-capacity via the column** — a bounded ring column gives a throwing, allocation-free deque; no separate bounded type.
- **Move-only elements** — `~Copyable` elements are pushed and popped by ownership transfer.

---

## Quick Start

```swift
import Deque_Primitives
import Column_Primitives

// Move-only by default, over a growable ring column:
var deque = Deque<Column.Ring<Int>>()
deque.push(1, to: .back)               // append at the back
deque.push(0, to: .front)              // prepend at the front — the head retreats, no shifting
let front = deque.pop(from: .front)    // Optional(0)
let back = deque.pop(from: .back)      // Optional(1)
```

---

## Installation

Add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-deque-primitives.git", branch: "main")
]
```

Add the product to your target:

```swift
.target(
    name: "App",
    dependencies: [
        .product(name: "Deque Primitives", package: "swift-deque-primitives")
    ]
)
```

The package is pre-1.0 — depend on `branch: "main"` until `0.1.0` is tagged. Requires Swift 6.3 and macOS 26 / iOS 26 / tvOS 26 / watchOS 26 / visionOS 26 (or the corresponding Linux / Windows toolchain).

---

## Architecture

| Product | Contents | When to import |
|---------|----------|----------------|
| `Deque Primitives` | Umbrella — the `Deque<S>` alias (= `Queue<S>.DoubleEnded`), the type, and its conformances | Most consumers |
| `Queue DoubleEnded Primitive` | The `Queue.DoubleEnded` value type alone, without the conformances | Minimal-surface use that names the type directly |

---

## Platform Support

| Platform         | CI  | Status       |
|------------------|-----|--------------|
| macOS 26         | Yes | Full support |
| Linux            | Yes | Full support |
| Windows          | Yes | Full support |
| iOS/tvOS/watchOS | —   | Supported    |
| Swift Embedded   | —   | Pending (nightly-toolchain follow-up) |

---

## Related Packages

- [`swift-queue-primitives`](https://github.com/swift-primitives/swift-queue-primitives) — the FIFO queue this double-ends; `Deque<S>` is `Queue<S>.DoubleEnded`.
- [`swift-buffer-ring-primitives`](https://github.com/swift-primitives/swift-buffer-ring-primitives) — the ring column the deque is built over.
- [`swift-column-primitives`](https://github.com/swift-primitives/swift-column-primitives) — the column vocabulary (`Column.Ring`, …) the deque composes.

---

## Community

<!-- BEGIN: discussion -->
<!-- END: discussion -->

## License

Apache 2.0. See [LICENSE.md](LICENSE.md).
