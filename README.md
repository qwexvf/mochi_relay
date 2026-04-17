> **Active development** — breaking changes may be pushed to `main` at any time.
> Built with the help of [Claude Code](https://claude.ai/code).

# mochi_relay

Relay-style cursor pagination for mochi GraphQL.

## Installation

```toml
# gleam.toml
[dependencies]
mochi_relay = { git = "https://github.com/qwexvf/mochi_relay", ref = "main" }
```

## Usage

```gleam
import mochi_relay/connections

let connection =
  connections.build(
    items: users,
    first: args.first,
    after: args.after,
    encode: fn(u) { types.to_dynamic(u) },
  )
```

## License

Apache-2.0
Built with the help of [Claude Code](https://claude.ai/code).