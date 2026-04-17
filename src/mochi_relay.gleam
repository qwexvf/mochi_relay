//// Relay-style cursor pagination for mochi GraphQL.
////
//// ## Usage
////
//// ```gleam
//// import mochi_relay
//// import mochi_relay/connections
//// import mochi/query
////
//// let #(conn_type, edge_type, page_info) =
////   mochi_relay.connection_types("User")
////
//// query.new()
////   |> query.add_type(conn_type)
////   |> query.add_type(edge_type)
////   |> query.add_type(page_info)
////   |> query.add_query(
////     query.query_with_args(
////       name: "users",
////       args: mochi_relay.connection_args(),
////       returns: schema.named_type("UserConnection"),
////       decode: fn(args) { Ok(mochi_relay.parse_connection_args(args)) },
////       resolve: fn(conn_args, _ctx) {
////         let limit = mochi_relay.get_limit(conn_args, 20)
////         let users = get_users(limit)
////         Ok(mochi_relay.from_list(users, fn(u) { u.id },
////           has_next: False, has_prev: False, total: option.None))
////       },
////       encode: fn(conn) {
////         mochi_relay.connection_to_dynamic(conn, encode_user)
////       },
////     )
////   )
//// ```

import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option}
import mochi/schema.{type ArgumentDefinition, type ObjectType}
import mochi_relay/connections.{type Connection, type ConnectionArgs}

pub fn connection_types(name: String) -> #(ObjectType, ObjectType, ObjectType) {
  connections.connection_types(name)
}

pub fn connection_args() -> List(ArgumentDefinition) {
  connections.connection_args()
}

pub fn connection_args_with_default(
  default_first: Int,
) -> List(ArgumentDefinition) {
  connections.connection_args_with_default(default_first)
}

pub fn parse_connection_args(args: Dict(String, Dynamic)) -> ConnectionArgs {
  connections.parse_connection_args(args)
}

pub fn get_limit(args: ConnectionArgs, default: Int) -> Int {
  connections.get_limit(args, default)
}

pub fn from_list(
  items: List(a),
  cursor_fn: fn(a) -> String,
  has_next has_next: Bool,
  has_prev has_prev: Bool,
  total total: Option(Int),
) -> Connection(a) {
  connections.from_list(
    items,
    cursor_fn,
    has_next: has_next,
    has_prev: has_prev,
    total: total,
  )
}

pub fn from_offset_pagination(
  items: List(a),
  cursor_fn: fn(a) -> String,
  offset offset: Int,
  limit limit: Int,
  total total: Int,
) -> Connection(a) {
  connections.from_offset_pagination(
    items,
    cursor_fn,
    offset: offset,
    limit: limit,
    total: total,
  )
}

pub fn empty_connection() -> Connection(a) {
  connections.empty_connection()
}

pub fn connection_to_dynamic(
  conn: Connection(a),
  node_encoder: fn(a) -> Dynamic,
) -> Dynamic {
  connections.connection_to_dynamic(conn, node_encoder)
}

pub fn page_info_type() -> ObjectType {
  connections.page_info_type()
}

pub fn edge_type(name: String, node_type_name: String) -> ObjectType {
  connections.edge_type(name, node_type_name)
}
