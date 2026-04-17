//// Relay-style connection/pagination helpers for GraphQL.
////
//// This module provides types and builders for implementing the Relay Connection
//// specification, which is the standard approach for cursor-based pagination.
////
//// ## Usage
////
//// ```gleam
//// import mochi_relay/connections
//// import mochi/query
////
//// // Create connection types for User
//// let #(connection_type, edge_type, page_info_type) =
////   connections.connection_types("User")
////
//// // Add to schema
//// query.new()
////   |> query.add_type(connection_type)
////   |> query.add_type(edge_type)
////   |> query.add_type(page_info_type)
////
//// // In your resolver
//// let conn = connections.Connection(
////   edges: [
////     connections.Edge(node: user1, cursor: "cursor1"),
////     connections.Edge(node: user2, cursor: "cursor2"),
////   ],
////   page_info: connections.PageInfo(
////     has_next_page: True,
////     has_previous_page: False,
////     start_cursor: Some("cursor1"),
////     end_cursor: Some("cursor2"),
////   ),
////   total_count: Some(100),
//// )
////
//// // Encode for response
//// connections.connection_to_dynamic(conn, user_to_dynamic)
//// ```

import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import mochi/schema.{type ArgumentDefinition, type ObjectType, Named, NonNull}

// ============================================================================
// Connection Types
// ============================================================================

/// Relay-style PageInfo for pagination
pub type PageInfo {
  PageInfo(
    has_next_page: Bool,
    has_previous_page: Bool,
    start_cursor: Option(String),
    end_cursor: Option(String),
  )
}

/// An edge in a connection, containing a node and cursor
pub type Edge(a) {
  Edge(node: a, cursor: String)
}

/// A Relay-style connection with edges and pagination info
pub type Connection(a) {
  Connection(
    edges: List(Edge(a)),
    page_info: PageInfo,
    total_count: Option(Int),
  )
}

// ============================================================================
// Helper to convert any value to Dynamic
// ============================================================================

@external(erlang, "gleam_stdlib", "identity")
fn to_dynamic(value: a) -> Dynamic

// ============================================================================
// PageInfo Schema Type
// ============================================================================

/// Create the PageInfo type for schema registration
pub fn page_info_type() -> ObjectType {
  schema.object("PageInfo")
  |> schema.description("Information about pagination in a connection")
  |> schema.required_bool_field("hasNextPage")
  |> schema.required_bool_field("hasPreviousPage")
  |> schema.string_field("startCursor")
  |> schema.string_field("endCursor")
}

// ============================================================================
// Edge Schema Type
// ============================================================================

/// Create an Edge type for a specific node type
///
/// ```gleam
/// let user_edge = connections.edge_type("User", "User")
/// // Creates UserEdge with node: User and cursor: String!
/// ```
pub fn edge_type(name: String, node_type_name: String) -> ObjectType {
  schema.object(name <> "Edge")
  |> schema.description("An edge in a " <> name <> " connection")
  |> schema.field(
    schema.field_def("node", Named(node_type_name))
    |> schema.field_description("The item at the end of the edge"),
  )
  |> schema.field(
    schema.field_def("cursor", NonNull(Named("String")))
    |> schema.field_description("A cursor for use in pagination"),
  )
}

// ============================================================================
// Connection Schema Type
// ============================================================================

/// Create a Connection type for a specific edge type
///
/// ```gleam
/// let user_connection = connections.connection_type("User", "UserEdge")
/// // Creates UserConnection with edges, pageInfo, and totalCount
/// ```
pub fn connection_type(name: String, edge_type_name: String) -> ObjectType {
  schema.object(name <> "Connection")
  |> schema.description("A connection to a list of " <> name <> " items")
  |> schema.field(
    schema.field_def("edges", schema.List(Named(edge_type_name)))
    |> schema.field_description("A list of edges"),
  )
  |> schema.field(
    schema.field_def("pageInfo", NonNull(Named("PageInfo")))
    |> schema.field_description("Information to aid in pagination"),
  )
  |> schema.field(
    schema.field_def("totalCount", Named("Int"))
    |> schema.field_description("Total number of items in the connection"),
  )
}

// ============================================================================
// Connection Types Helper
// ============================================================================

/// Create all three connection types at once: Connection, Edge, and PageInfo
///
/// Returns a tuple of (Connection, Edge, PageInfo) ObjectTypes.
/// Note: PageInfo is shared across all connections, so you only need to
/// register it once.
///
/// ```gleam
/// let #(user_connection, user_edge, page_info) =
///   connections.connection_types("User")
///
/// query.new()
///   |> query.add_type(user_connection)
///   |> query.add_type(user_edge)
///   |> query.add_type(page_info)
/// ```
pub fn connection_types(
  item_name: String,
) -> #(ObjectType, ObjectType, ObjectType) {
  let edge = edge_type(item_name, item_name)
  let connection = connection_type(item_name, item_name <> "Edge")
  let page_info = page_info_type()
  #(connection, edge, page_info)
}

// ============================================================================
// Connection Arguments
// ============================================================================

/// Get standard connection arguments for pagination
///
/// Returns [first, after, last, before] arguments as used in Relay connections.
///
/// ```gleam
/// query.query_with_args(
///   name: "users",
///   args: connections.connection_args(),
///   returns: schema.named_type("UserConnection"),
///   ...
/// )
/// ```
pub fn connection_args() -> List(ArgumentDefinition) {
  [
    schema.arg("first", Named("Int"))
      |> schema.arg_description("Returns the first n items"),
    schema.arg("after", Named("String"))
      |> schema.arg_description("Returns items after the specified cursor"),
    schema.arg("last", Named("Int"))
      |> schema.arg_description("Returns the last n items"),
    schema.arg("before", Named("String"))
      |> schema.arg_description("Returns items before the specified cursor"),
  ]
}

/// Get connection arguments with default first value
pub fn connection_args_with_default(
  default_first: Int,
) -> List(ArgumentDefinition) {
  [
    schema.arg("first", Named("Int"))
      |> schema.arg_description("Returns the first n items")
      |> schema.default_value(to_dynamic(default_first)),
    schema.arg("after", Named("String"))
      |> schema.arg_description("Returns items after the specified cursor"),
    schema.arg("last", Named("Int"))
      |> schema.arg_description("Returns the last n items"),
    schema.arg("before", Named("String"))
      |> schema.arg_description("Returns items before the specified cursor"),
  ]
}

// ============================================================================
// Dynamic Encoding Helpers
// ============================================================================

/// Convert PageInfo to Dynamic for GraphQL response
pub fn page_info_to_dynamic(info: PageInfo) -> Dynamic {
  to_dynamic(
    dict.from_list([
      #("hasNextPage", to_dynamic(info.has_next_page)),
      #("hasPreviousPage", to_dynamic(info.has_previous_page)),
      #("startCursor", case info.start_cursor {
        Some(c) -> to_dynamic(c)
        None -> to_dynamic(Nil)
      }),
      #("endCursor", case info.end_cursor {
        Some(c) -> to_dynamic(c)
        None -> to_dynamic(Nil)
      }),
    ]),
  )
}

/// Convert an Edge to Dynamic for GraphQL response
pub fn edge_to_dynamic(edge: Edge(a), node_encoder: fn(a) -> Dynamic) -> Dynamic {
  to_dynamic(
    dict.from_list([
      #("node", node_encoder(edge.node)),
      #("cursor", to_dynamic(edge.cursor)),
    ]),
  )
}

/// Convert a Connection to Dynamic for GraphQL response
pub fn connection_to_dynamic(
  conn: Connection(a),
  node_encoder: fn(a) -> Dynamic,
) -> Dynamic {
  to_dynamic(
    dict.from_list([
      #(
        "edges",
        to_dynamic(
          list.map(conn.edges, fn(e) { edge_to_dynamic(e, node_encoder) }),
        ),
      ),
      #("pageInfo", page_info_to_dynamic(conn.page_info)),
      #("totalCount", case conn.total_count {
        Some(count) -> to_dynamic(count)
        None -> to_dynamic(Nil)
      }),
    ]),
  )
}

// ============================================================================
// Connection Builder Helpers
// ============================================================================

/// Create an empty connection
pub fn empty_connection() -> Connection(a) {
  Connection(
    edges: [],
    page_info: PageInfo(
      has_next_page: False,
      has_previous_page: False,
      start_cursor: None,
      end_cursor: None,
    ),
    total_count: Some(0),
  )
}

/// Create a connection from a list of items with a cursor generator
///
/// ```gleam
/// let users = [user1, user2, user3]
/// let conn = connections.from_list(
///   users,
///   fn(u) { u.id },  // cursor from id
///   has_next: True,
///   has_prev: False,
///   total: Some(100),
/// )
/// ```
pub fn from_list(
  items: List(a),
  cursor_fn: fn(a) -> String,
  has_next has_next_page: Bool,
  has_prev has_previous_page: Bool,
  total total_count: Option(Int),
) -> Connection(a) {
  let edges =
    list.map(items, fn(item) { Edge(node: item, cursor: cursor_fn(item)) })

  let start_cursor = case edges {
    [first, ..] -> Some(first.cursor)
    [] -> None
  }

  let end_cursor = case list.last(edges) {
    Ok(last) -> Some(last.cursor)
    Error(_) -> None
  }

  Connection(
    edges: edges,
    page_info: PageInfo(
      has_next_page: has_next_page,
      has_previous_page: has_previous_page,
      start_cursor: start_cursor,
      end_cursor: end_cursor,
    ),
    total_count: total_count,
  )
}

/// Create a simple paginated connection from offset-based pagination
///
/// ```gleam
/// let page = get_users(offset: 10, limit: 10)
/// let conn = connections.from_offset_pagination(
///   page.items,
///   fn(u) { int.to_string(u.id) },
///   offset: 10,
///   limit: 10,
///   total: page.total_count,
/// )
/// ```
pub fn from_offset_pagination(
  items: List(a),
  cursor_fn: fn(a) -> String,
  offset offset: Int,
  limit _limit: Int,
  total total_count: Int,
) -> Connection(a) {
  let has_previous_page = offset > 0
  let has_next_page = offset + list.length(items) < total_count

  from_list(
    items,
    cursor_fn,
    has_next: has_next_page,
    has_prev: has_previous_page,
    total: Some(total_count),
  )
}

// ============================================================================
// Argument Parsing Helpers
// ============================================================================

/// Connection pagination arguments parsed from GraphQL input
pub type ConnectionArgs {
  ConnectionArgs(
    first: Option(Int),
    after: Option(String),
    last: Option(Int),
    before: Option(String),
  )
}

/// Parse connection arguments from a Dynamic dict
///
/// ```gleam
/// fn decode_args(args) {
///   let conn_args = connections.parse_connection_args(args)
///   // Use conn_args.first, conn_args.after, etc.
/// }
/// ```
pub fn parse_connection_args(args: dict.Dict(String, Dynamic)) -> ConnectionArgs {
  let first = case dict.get(args, "first") {
    Ok(v) ->
      case decode.run(v, decode.int) {
        Ok(i) -> Some(i)
        Error(_) -> None
      }
    Error(_) -> None
  }

  let after = case dict.get(args, "after") {
    Ok(v) ->
      case decode.run(v, decode.string) {
        Ok(s) -> Some(s)
        Error(_) -> None
      }
    Error(_) -> None
  }

  let last = case dict.get(args, "last") {
    Ok(v) ->
      case decode.run(v, decode.int) {
        Ok(i) -> Some(i)
        Error(_) -> None
      }
    Error(_) -> None
  }

  let before = case dict.get(args, "before") {
    Ok(v) ->
      case decode.run(v, decode.string) {
        Ok(s) -> Some(s)
        Error(_) -> None
      }
    Error(_) -> None
  }

  ConnectionArgs(first: first, after: after, last: last, before: before)
}

/// Get the limit from connection args, using first or last with a default
pub fn get_limit(args: ConnectionArgs, default: Int) -> Int {
  case args.first {
    Some(f) -> f
    None ->
      case args.last {
        Some(l) -> l
        None -> default
      }
  }
}
