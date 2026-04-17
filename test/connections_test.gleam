// Tests for mochi_relay/connections.gleam module
// Tests Relay-style connection/pagination helpers

import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{None, Some}
import mochi/schema
import mochi_relay/connections

// ============================================================================
// Test Types
// ============================================================================

pub type TestUser {
  TestUser(id: String, name: String)
}

fn user_to_dynamic(u: TestUser) -> Dynamic {
  connections_to_dynamic(
    dict.from_list([
      #("id", connections_to_dynamic(u.id)),
      #("name", connections_to_dynamic(u.name)),
    ]),
  )
}

@external(erlang, "gleam_stdlib", "identity")
fn connections_to_dynamic(value: a) -> Dynamic

// ============================================================================
// PageInfo Tests
// ============================================================================

pub fn page_info_creation_test() {
  let page_info =
    connections.PageInfo(
      has_next_page: True,
      has_previous_page: False,
      start_cursor: Some("cursor1"),
      end_cursor: Some("cursor10"),
    )

  case page_info.has_next_page {
    True -> Nil
    False -> panic as "has_next_page should be True"
  }
  case page_info.has_previous_page {
    False -> Nil
    True -> panic as "has_previous_page should be False"
  }
  case page_info.start_cursor {
    Some("cursor1") -> Nil
    _ -> panic as "start_cursor should be Some('cursor1')"
  }
  case page_info.end_cursor {
    Some("cursor10") -> Nil
    _ -> panic as "end_cursor should be Some('cursor10')"
  }
}

pub fn page_info_to_dynamic_test() {
  let page_info =
    connections.PageInfo(
      has_next_page: True,
      has_previous_page: False,
      start_cursor: Some("start"),
      end_cursor: Some("end"),
    )

  let dyn = connections.page_info_to_dynamic(page_info)

  // Verify it's a dict with expected keys
  case decode.run(dyn, decode.at(["hasNextPage"], decode.bool)) {
    Ok(True) -> Nil
    _ -> panic as "hasNextPage should be True"
  }
  case decode.run(dyn, decode.at(["hasPreviousPage"], decode.bool)) {
    Ok(False) -> Nil
    _ -> panic as "hasPreviousPage should be False"
  }
}

// ============================================================================
// Edge Tests
// ============================================================================

pub fn edge_creation_test() {
  let user = TestUser("1", "Alice")
  let edge = connections.Edge(node: user, cursor: "user-1")

  case edge.cursor == "user-1" {
    True -> Nil
    False -> panic as "Edge cursor should be 'user-1'"
  }
  case edge.node.name == "Alice" {
    True -> Nil
    False -> panic as "Edge node name should be 'Alice'"
  }
}

pub fn edge_to_dynamic_test() {
  let user = TestUser("1", "Alice")
  let edge = connections.Edge(node: user, cursor: "user-1")

  let dyn = connections.edge_to_dynamic(edge, user_to_dynamic)

  case decode.run(dyn, decode.at(["cursor"], decode.string)) {
    Ok("user-1") -> Nil
    _ -> panic as "Edge cursor in dynamic should be 'user-1'"
  }
}

// ============================================================================
// Connection Tests
// ============================================================================

pub fn connection_creation_test() {
  let users = [TestUser("1", "Alice"), TestUser("2", "Bob")]
  let edges = list.map(users, fn(u) { connections.Edge(node: u, cursor: u.id) })

  let conn =
    connections.Connection(
      edges: edges,
      page_info: connections.PageInfo(
        has_next_page: True,
        has_previous_page: False,
        start_cursor: Some("1"),
        end_cursor: Some("2"),
      ),
      total_count: Some(100),
    )

  case list.length(conn.edges) == 2 {
    True -> Nil
    False -> panic as "Connection should have 2 edges"
  }
  case conn.total_count {
    Some(100) -> Nil
    _ -> panic as "total_count should be Some(100)"
  }
}

pub fn connection_to_dynamic_test() {
  let users = [TestUser("1", "Alice")]
  let edges = list.map(users, fn(u) { connections.Edge(node: u, cursor: u.id) })

  let conn =
    connections.Connection(
      edges: edges,
      page_info: connections.PageInfo(
        has_next_page: False,
        has_previous_page: False,
        start_cursor: Some("1"),
        end_cursor: Some("1"),
      ),
      total_count: Some(1),
    )

  let dyn = connections.connection_to_dynamic(conn, user_to_dynamic)

  // Verify structure
  case decode.run(dyn, decode.at(["totalCount"], decode.int)) {
    Ok(1) -> Nil
    _ -> panic as "totalCount should be 1"
  }
}

pub fn empty_connection_test() {
  let conn: connections.Connection(TestUser) = connections.empty_connection()

  case conn.edges == [] {
    True -> Nil
    False -> panic as "Empty connection should have 0 edges"
  }
  case conn.total_count {
    Some(0) -> Nil
    _ -> panic as "Empty connection total_count should be Some(0)"
  }
  case conn.page_info.has_next_page {
    False -> Nil
    True -> panic as "Empty connection has_next_page should be False"
  }
  case conn.page_info.has_previous_page {
    False -> Nil
    True -> panic as "Empty connection has_previous_page should be False"
  }
}

// ============================================================================
// from_list Tests
// ============================================================================

pub fn from_list_basic_test() {
  let users = [
    TestUser("1", "Alice"),
    TestUser("2", "Bob"),
    TestUser("3", "Carol"),
  ]

  let conn =
    connections.from_list(
      users,
      fn(u) { u.id },
      has_next: True,
      has_prev: False,
      total: Some(100),
    )

  case list.length(conn.edges) == 3 {
    True -> Nil
    False -> panic as "Connection should have 3 edges"
  }
  case conn.page_info.has_next_page {
    True -> Nil
    False -> panic as "has_next_page should be True"
  }
  case conn.page_info.has_previous_page {
    False -> Nil
    True -> panic as "has_previous_page should be False"
  }
  case conn.page_info.start_cursor {
    Some("1") -> Nil
    _ -> panic as "start_cursor should be '1'"
  }
  case conn.page_info.end_cursor {
    Some("3") -> Nil
    _ -> panic as "end_cursor should be '3'"
  }
  case conn.total_count {
    Some(100) -> Nil
    _ -> panic as "total_count should be Some(100)"
  }
}

pub fn from_list_empty_test() {
  let users: List(TestUser) = []

  let conn =
    connections.from_list(
      users,
      fn(u: TestUser) { u.id },
      has_next: False,
      has_prev: False,
      total: Some(0),
    )

  case conn.edges == [] {
    True -> Nil
    False -> panic as "Connection should have 0 edges"
  }
  case conn.page_info.start_cursor {
    None -> Nil
    Some(_) -> panic as "start_cursor should be None for empty list"
  }
  case conn.page_info.end_cursor {
    None -> Nil
    Some(_) -> panic as "end_cursor should be None for empty list"
  }
}

// ============================================================================
// from_offset_pagination Tests
// ============================================================================

pub fn from_offset_pagination_first_page_test() {
  let users = [TestUser("1", "Alice"), TestUser("2", "Bob")]

  let conn =
    connections.from_offset_pagination(
      users,
      fn(u) { u.id },
      offset: 0,
      limit: 2,
      total: 10,
    )

  case conn.page_info.has_previous_page {
    False -> Nil
    True -> panic as "First page should not have previous page"
  }
  case conn.page_info.has_next_page {
    True -> Nil
    False -> panic as "First page with more items should have next page"
  }
}

pub fn from_offset_pagination_middle_page_test() {
  let users = [TestUser("3", "Carol"), TestUser("4", "Dave")]

  let conn =
    connections.from_offset_pagination(
      users,
      fn(u) { u.id },
      offset: 2,
      limit: 2,
      total: 10,
    )

  case conn.page_info.has_previous_page {
    True -> Nil
    False -> panic as "Middle page should have previous page"
  }
  case conn.page_info.has_next_page {
    True -> Nil
    False -> panic as "Middle page should have next page"
  }
}

pub fn from_offset_pagination_last_page_test() {
  let users = [TestUser("9", "Ivan"), TestUser("10", "Jane")]

  let conn =
    connections.from_offset_pagination(
      users,
      fn(u) { u.id },
      offset: 8,
      limit: 2,
      total: 10,
    )

  case conn.page_info.has_previous_page {
    True -> Nil
    False -> panic as "Last page should have previous page"
  }
  case conn.page_info.has_next_page {
    False -> Nil
    True -> panic as "Last page should not have next page"
  }
}

// ============================================================================
// Schema Type Tests
// ============================================================================

pub fn page_info_type_test() {
  let page_info_type = connections.page_info_type()

  case page_info_type.name == "PageInfo" {
    True -> Nil
    False -> panic as "Type name should be 'PageInfo'"
  }
  case dict.get(page_info_type.fields, "hasNextPage") {
    Ok(_) -> Nil
    Error(_) -> panic as "PageInfo should have 'hasNextPage' field"
  }
  case dict.get(page_info_type.fields, "hasPreviousPage") {
    Ok(_) -> Nil
    Error(_) -> panic as "PageInfo should have 'hasPreviousPage' field"
  }
  case dict.get(page_info_type.fields, "startCursor") {
    Ok(_) -> Nil
    Error(_) -> panic as "PageInfo should have 'startCursor' field"
  }
  case dict.get(page_info_type.fields, "endCursor") {
    Ok(_) -> Nil
    Error(_) -> panic as "PageInfo should have 'endCursor' field"
  }
}

pub fn edge_type_test() {
  let user_edge = connections.edge_type("User", "User")

  case user_edge.name == "UserEdge" {
    True -> Nil
    False -> panic as "Edge type name should be 'UserEdge'"
  }
  case dict.get(user_edge.fields, "node") {
    Ok(field) ->
      case field.field_type {
        schema.Named("User") -> Nil
        _ -> panic as "node field should be Named('User')"
      }
    Error(_) -> panic as "UserEdge should have 'node' field"
  }
  case dict.get(user_edge.fields, "cursor") {
    Ok(field) ->
      case field.field_type {
        schema.NonNull(schema.Named("String")) -> Nil
        _ -> panic as "cursor field should be NonNull(String)"
      }
    Error(_) -> panic as "UserEdge should have 'cursor' field"
  }
}

pub fn connection_type_test() {
  let user_connection = connections.connection_type("User", "UserEdge")

  case user_connection.name == "UserConnection" {
    True -> Nil
    False -> panic as "Connection type name should be 'UserConnection'"
  }
  case dict.get(user_connection.fields, "edges") {
    Ok(field) ->
      case field.field_type {
        schema.List(schema.Named("UserEdge")) -> Nil
        _ -> panic as "edges field should be List(UserEdge)"
      }
    Error(_) -> panic as "UserConnection should have 'edges' field"
  }
  case dict.get(user_connection.fields, "pageInfo") {
    Ok(field) ->
      case field.field_type {
        schema.NonNull(schema.Named("PageInfo")) -> Nil
        _ -> panic as "pageInfo field should be NonNull(PageInfo)"
      }
    Error(_) -> panic as "UserConnection should have 'pageInfo' field"
  }
  case dict.get(user_connection.fields, "totalCount") {
    Ok(_) -> Nil
    Error(_) -> panic as "UserConnection should have 'totalCount' field"
  }
}

pub fn connection_types_test() {
  let #(connection, edge, page_info) = connections.connection_types("Post")

  case connection.name == "PostConnection" {
    True -> Nil
    False -> panic as "Connection name should be 'PostConnection'"
  }
  case edge.name == "PostEdge" {
    True -> Nil
    False -> panic as "Edge name should be 'PostEdge'"
  }
  case page_info.name == "PageInfo" {
    True -> Nil
    False -> panic as "PageInfo name should be 'PageInfo'"
  }
}

// ============================================================================
// Connection Arguments Tests
// ============================================================================

pub fn connection_args_test() {
  let args = connections.connection_args()

  case list.length(args) == 4 {
    True -> Nil
    False -> panic as "connection_args should return 4 arguments"
  }

  // Check argument names
  let arg_names = list.map(args, fn(a) { a.name })
  case list.contains(arg_names, "first") {
    True -> Nil
    False -> panic as "Should have 'first' argument"
  }
  case list.contains(arg_names, "after") {
    True -> Nil
    False -> panic as "Should have 'after' argument"
  }
  case list.contains(arg_names, "last") {
    True -> Nil
    False -> panic as "Should have 'last' argument"
  }
  case list.contains(arg_names, "before") {
    True -> Nil
    False -> panic as "Should have 'before' argument"
  }
}

pub fn connection_args_with_default_test() {
  let args = connections.connection_args_with_default(20)

  case list.length(args) == 4 {
    True -> Nil
    False -> panic as "connection_args_with_default should return 4 arguments"
  }

  // Check that first has a default value
  case list.find(args, fn(a) { a.name == "first" }) {
    Ok(first_arg) ->
      case first_arg.default_value {
        Some(_) -> Nil
        None -> panic as "'first' argument should have default value"
      }
    Error(_) -> panic as "Should have 'first' argument"
  }
}

// ============================================================================
// ConnectionArgs Parsing Tests
// ============================================================================

pub fn parse_connection_args_all_present_test() {
  let args =
    dict.from_list([
      #("first", connections_to_dynamic(10)),
      #("after", connections_to_dynamic("cursor1")),
      #("last", connections_to_dynamic(5)),
      #("before", connections_to_dynamic("cursor2")),
    ])

  let conn_args = connections.parse_connection_args(args)

  case conn_args.first {
    Some(10) -> Nil
    _ -> panic as "first should be Some(10)"
  }
  case conn_args.after {
    Some("cursor1") -> Nil
    _ -> panic as "after should be Some('cursor1')"
  }
  case conn_args.last {
    Some(5) -> Nil
    _ -> panic as "last should be Some(5)"
  }
  case conn_args.before {
    Some("cursor2") -> Nil
    _ -> panic as "before should be Some('cursor2')"
  }
}

pub fn parse_connection_args_partial_test() {
  let args = dict.from_list([#("first", connections_to_dynamic(25))])

  let conn_args = connections.parse_connection_args(args)

  case conn_args.first {
    Some(25) -> Nil
    _ -> panic as "first should be Some(25)"
  }
  case conn_args.after {
    None -> Nil
    Some(_) -> panic as "after should be None"
  }
  case conn_args.last {
    None -> Nil
    Some(_) -> panic as "last should be None"
  }
  case conn_args.before {
    None -> Nil
    Some(_) -> panic as "before should be None"
  }
}

pub fn parse_connection_args_empty_test() {
  let args = dict.new()

  let conn_args = connections.parse_connection_args(args)

  case conn_args.first {
    None -> Nil
    Some(_) -> panic as "first should be None"
  }
  case conn_args.after {
    None -> Nil
    Some(_) -> panic as "after should be None"
  }
}

// ============================================================================
// get_limit Tests
// ============================================================================

pub fn get_limit_from_first_test() {
  let conn_args =
    connections.ConnectionArgs(
      first: Some(10),
      after: None,
      last: Some(5),
      before: None,
    )

  let limit = connections.get_limit(conn_args, 20)

  case limit == 10 {
    True -> Nil
    False -> panic as "limit should be 10 (from first)"
  }
}

pub fn get_limit_from_last_test() {
  let conn_args =
    connections.ConnectionArgs(
      first: None,
      after: None,
      last: Some(5),
      before: None,
    )

  let limit = connections.get_limit(conn_args, 20)

  case limit == 5 {
    True -> Nil
    False -> panic as "limit should be 5 (from last)"
  }
}

pub fn get_limit_default_test() {
  let conn_args =
    connections.ConnectionArgs(
      first: None,
      after: None,
      last: None,
      before: None,
    )

  let limit = connections.get_limit(conn_args, 20)

  case limit == 20 {
    True -> Nil
    False -> panic as "limit should be 20 (default)"
  }
}
