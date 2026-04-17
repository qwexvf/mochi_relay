# mochi_relay

Relay-style cursor pagination for mochi GraphQL.

## Installation

```sh
gleam add mochi_relay
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

