# derive-tests-from-invariants

Tests come from the properties the code must hold and the shape of its inputs, not from the change you happened to make. Before implementing, write down the invariants and the input equivalence classes; derive the test cases from those two lists.

This governs *what to test*. `testing-philosophy` governs *how to build the doubles*; different axes, both apply.

## Invariants

An invariant is a property that must hold for every execution, written so it can be false:

- "Every recorded value maps to exactly one binding key."
- "The pool never holds a slot past the caller's deadline."
- "Encoding then decoding returns the original value."

Write them as sentences, not as test names. A property stated vaguely ("handles nulls correctly") cannot fail and cannot be tested.

For each invariant, the test suite MUST contain a case that would fail if the invariant broke. An invariant with no such case is undefended.

## Input equivalence classes

For every input to the code being changed, enumerate the *classes*, not the examples:

- `nil`, and typed-nil where the language distinguishes it from a nil interface
- zero value vs. absent vs. present-but-null
- empty collection, one element, many elements
- duplicate elements, and elements equal under the comparison the code uses
- pointer vs. value receiver, or reference vs. copy
- boundaries and the values immediately on either side

Then ask whether each invariant still holds for each class.

**Inconsistency across classes is itself a defect.** If one class of null round-trips through a token and another is written as a literal, that asymmetry is a bug even when each path works in isolation. Test the classes against each other, not only against the happy path.

## Interactions

Single-input correctness is the easy half. Most invariant violations need two of something to become visible, so enumerate pairs:

- two arguments of the same kind in one call
- an argument plus a nested value (a row cell, a map entry, a repeated field)
- a foreground request plus the background work it spawns
- a retry plus the original attempt
- two calls in sequence against shared state

Pairwise coverage, not full combinatorial coverage. The second instance is where shared keys, shared buffers, and shared state surface.

## The revert-mutation trap

Frequently missed: a test suite that only proves *reverting your own change* breaks something has proved that the tests catch reverts. It has not proved the tests cover the input space.

Reverting your change exercises exactly the path you were already thinking about. It is a sanity check on test wiring, not evidence of coverage. The cases that catch real bugs are the ones derived from the lists above, which include inputs you were not thinking about when you wrote the code.

If the only new tests in a change are mirror images of the diff, the derivation step was skipped.

## Scope

- Applies to the code the change touches and the code it calls.
- A gap found in untouched code is still worth a test; write it or note it, do not silently widen the change (`minimal-changes`).
- Do not manufacture cases for classes the input type cannot express. A non-nullable integer has no nil class.

## See also

- `testing-philosophy` — how to build test doubles once you know what to test.
- `probe-not-assume` — a derived case still has to be run; generation is not verification.
- `implementation-minimalism` — rigor is never the thing minimalism cuts. Fewer lines, same coverage of the input space.
