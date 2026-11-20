# Coding standards

## Source text

- No code comments. Names and structure carry the meaning.
- Identifiers are spelled out in full. No abbreviations, no single-letter parameters.

## Grouping

Statements inside a function are grouped by goal: the lines that together achieve one thing sit next to each other, and a blank line separates one group from the next. Each branch of a conditional is its own group.

## Domain state

A piece of domain knowledge lives in one structure that encodes it: a state machine for a lifecycle, a lookup table keyed on the variant for per-variant values, a discriminated union for variants that hold different data. Code reads the structure instead of branching on the same condition in several places.

- A new variant is a new entry in the structure. A change that adds one more branch to an if/else chain that already exists is the sign the structure is missing.
- State that two booleans would have to keep in sync is one value: `status: Status.Loading` rather than `isLoading` beside `isLoaded`.
- A module is organized around the domain knowledge it owns. A pipeline split into steps (load, validate, transform, save) repeats the same domain rules in each step.
- Logic that lives in one place and has two or three cases stays a plain conditional. A structure earns its place by deleting branches, duplicated rules, or invalid states.

## Boundaries

Data from outside the program, from command-line arguments, environment variables, the zsh history file, and the output of other commands (`rex client ls --json`, `pmset -g log`, `ioreg`), is parsed into the repo's own types where it enters. Code past that point trusts those types and checks nothing again.

- A parse function turns raw input into a typed value or an error, and business logic receives the typed value.
- Business logic is pure functions with no framework imports. The framework layer parses input, calls them, and writes the output.
- The public surface of a module exposes the repo's domain types. Transport, storage, and wire types stay inside the module that talks to them.
