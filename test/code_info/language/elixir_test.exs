defmodule CodeInfo.Language.ElixirTest do
  use ExUnit.Case, async: true
  import CodeInfo.Language.Elixir
  doctest CodeInfo.Language.Elixir

  test "parse_ref/1" do
    assert parse_ref("String") == {:module, String}
    assert parse_ref("Version.Requirement") == {:module, Version.Requirement}
    assert parse_ref("Unknown") == {:module, Unknown}
    assert parse_ref("mix new") == {:module, Mix.Tasks.New}
    assert parse_ref("mix help deps.get") == {:module, Mix.Tasks.Deps.Get}
    assert parse_ref("String.upcase/1") == {:function, {String, :upcase, 1}}
    assert parse_ref(":array.new/0") == {:function, {:array, :new, 0}}
    assert parse_ref("foo/2") == {:function, {:foo, 2}}
    assert parse_ref("+/2") == {:function, {:+, 2}}
    assert parse_ref("c:GenServer.handle_call/3") == {:callback, {GenServer, :handle_call, 3}}
    assert parse_ref("t:Keyword.t/0") == {:type, {Keyword, :t, 0}}
    assert parse_ref("Foo Bar") == :error
    assert parse_ref("1 + 2") == :error
    assert parse_ref("foo / 1") == :error
    assert parse_ref("foo(1)") == :error
    assert parse_ref("foo(1") == :error
    assert parse_ref(":foo") == :error
    assert parse_ref(":\"foo\"") == :error
    assert parse_ref("") == :error
  end
end
