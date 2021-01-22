defmodule CodeInfoTest do
  use ExUnit.Case, async: true

  test "fetch/2: Elixir module" do
    TestHelper.elixirc(~S"""
    defmodule M do
      @moduledoc "M docs"

      @typedoc "type1 docs"
      @type type1() :: integer()

      @typedoc "opaque1 docs"
      @opaque opaque1() :: typep1()

      @typep typep1() :: integer()

      @doc "callback1 docs"
      @callback callback1() :: :ok

      @doc "macrocallback1 docs"
      @macrocallback macrocallback1() :: :ok

      @macrocallback macrocallback2(t) :: [t] when t: term()

      @doc "function1 docs"
      @doc since: "1.0.0"
      @spec function1() :: :ok
      def function1() do
        :ok
      end

      @doc "function2 docs"
      @spec function2(atom()) :: atom()
      @spec function2(integer()) :: integer()
      def function2(x) do
        x
      end

      @doc "macro1 docs"
      @spec macro1() :: :ok
      defmacro macro1() do
        :ok
      end
    end
    """)

    {:ok, info} = CodeInfo.fetch(M)

    assert info.doc == %{"en" => "M docs"}
    assert info.doc_format == "text/markdown"
    assert info.doc_metadata == %{}

    assert Map.fetch!(info.types, {:type1, 0}) == %{
             kind: :type,
             doc: %{"en" => "type1 docs"},
             doc_metadata: %{},
             signature: [],
             spec_ast: {:type1, {:type, 5, :integer, []}, []},
             spec_string: "type1() :: integer()"
           }

    assert Map.fetch!(info.types, {:opaque1, 0}) == %{
             kind: :opaque,
             doc: %{"en" => "opaque1 docs"},
             doc_metadata: %{opaque: true},
             signature: [],
             spec_ast: {:opaque1, {:user_type, 8, :typep1, []}, []},
             spec_string: "opaque1() :: typep1()"
           }

    assert Map.fetch!(info.types, {:typep1, 0}) == %{
             kind: :typep,
             doc: :none,
             doc_metadata: %{},
             signature: [],
             spec_ast: {:typep1, {:type, 10, :integer, []}, []},
             spec_string: "typep1() :: integer()"
           }

    assert Map.fetch!(info.callbacks, {:callback1, 0}) == %{
             doc: %{"en" => "callback1 docs"},
             doc_metadata: %{},
             signature: [],
             spec_strings: ["callback1() :: :ok"]
           }

    assert Map.fetch!(info.macrocallbacks, {:macrocallback1, 0}) == %{
             doc: %{"en" => "macrocallback1 docs"},
             doc_metadata: %{},
             signature: [],
             spec_strings: ["macrocallback1() :: :ok"]
           }

    assert Map.fetch!(info.macrocallbacks, {:macrocallback2, 1}) == %{
             doc: %{},
             doc_metadata: %{},
             signature: [],
             spec_strings: ["macrocallback2(t) :: [t] when t: term()"]
           }

    assert Map.fetch!(info.functions, {:function1, 0}) == %{
             doc: %{"en" => "function1 docs"},
             doc_metadata: %{since: "1.0.0"},
             signature: ["function1()"],
             spec_strings: ["function1() :: :ok"]
           }

    assert Map.fetch!(info.functions, {:function2, 1}) == %{
             doc: %{"en" => "function2 docs"},
             doc_metadata: %{},
             signature: ["function2(x)"],
             spec_strings: [
               "function2(atom()) :: atom()",
               "function2(integer()) :: integer()"
             ]
           }

    assert Map.fetch!(info.macros, {:macro1, 0}) == %{
             doc: %{"en" => "macro1 docs"},
             doc_metadata: %{},
             signature: ["macro1()"],
             spec_strings: ["macro1() :: :ok"]
           }
  end

  test "fetch/2: Erlang module with chunk" do
    TestHelper.erlc(:module1, ~S"""
    %% @doc module1 docs.
    -module(module1).
    -export([function1/0, function2/1]).
    -export_type([type1/0]).

    -type type1() :: atom().
    %% type1 docs.

    -callback callback1() -> atom().

    -record(record1, {field1, field2}).

    %% @doc function1 docs.
    -spec function1() -> atom().
    function1() ->
      ok.

    %% @doc function2 docs.
    -spec function2(atom()) -> atom();
                   (integer()) -> integer().
    function2(X) ->
      X.
    """)

    TestHelper.edoc_to_chunk(:module1)
    {:ok, info} = CodeInfo.fetch(:module1)

    assert info.doc == %{
             "en" => [
               {:p, [], ["module1 docs."]},
               {:h2, [], ["DATA TYPES"]},
               {:a, [id: "types"], []},
               {:dl, [],
                [
                  {:dt, [], [{:a, [id: "type-type1"], []}, "type1() = atom()"]},
                  {:dd, [], [{:p, [], []}, {:p, [], ["type1 docs."]}]}
                ]}
             ]
           }

    assert info.doc_format == "application/erlang+html"
    assert info.doc_metadata.name == "module1"
    assert Map.keys(info.doc_metadata) == [:name, :otp_doc_vsn, :source, :types]

    assert info.types == %{
             {:type1, 0} => %{
               doc: :none,
               doc_metadata: %{},
               kind: :type,
               signature: [],
               spec_ast: {:type1, {:type, 6, :atom, []}, []},
               spec_string: "-type type1() :: atom()."
             }
           }

    assert info.callbacks == %{
             {:callback1, 0} => %{
               doc: :none,
               doc_metadata: %{},
               signature: [],
               spec_strings: ["-callback callback1() -> atom()."]
             }
           }

    assert Map.fetch!(info.functions, {:function1, 0}) == %{
             doc: %{"en" => [{:a, [id: "function1-0"], []}, {:p, [], ["function1 docs."]}]},
             doc_metadata: %{},
             signature: ["function1() -> atom()"],
             spec_strings: ["-spec function1() -> atom()."]
           }

    assert Map.fetch!(info.functions, {:function2, 1}) == %{
             doc: %{"en" => [{:a, [id: "function2-1"], []}, {:p, [], ["function2 docs."]}]},
             doc_metadata: %{},
             signature: ["function2(X::integer()) -> integer()", "function2(X::atom()) -> atom()"],
             # FIXME
             # spec_strings: [
             #   """
             #   -spec function2(atom()) -> atom();
             #                  (integer()) -> integer().\
             #   """
             # ]
             spec_strings: [
               "-spec function2(atom()) -> atom().",
               "-spec function2(integer()) -> integer()."
             ]
           }
  end

  test "fetch/2: Erlang module without chunk" do
    TestHelper.erlc(:module2, ~S"""
    -module(module2).
    -export([function1/0]).
    -export_type([type1/0]).

    -type type1() :: atom().

    -callback callback1() -> atom().

    -spec function1() -> atom().
    function1() ->
      ok.
    """)

    {:ok, info} = CodeInfo.fetch(:module2)

    assert info ==
             %{
               callbacks: %{
                 {:callback1, 0} => %{
                   doc: :none,
                   doc_metadata: %{},
                   signature: [],
                   spec_strings: ["-callback callback1() -> atom()."]
                 }
               },
               doc: :none,
               doc_format: nil,
               doc_metadata: %{},
               functions: %{
                 {:function1, 0} => %{
                   doc: :hidden,
                   doc_metadata: %{},
                   signature: [],
                   spec_strings: ["-spec function1() -> atom()."]
                 }
               },
               macrocallbacks: %{},
               macros: %{},
               types: %{
                 {:type1, 0} => %{
                   doc: :none,
                   doc_metadata: %{},
                   kind: :type,
                   signature: [],
                   spec_ast: {:type1, {:type, 5, :atom, []}, []},
                   spec_string: "-type type1() :: atom()."
                 }
               }
             }
  end

  test "fetch/2: Unknown module" do
    assert CodeInfo.fetch(Unknown) == {:error, :module_not_found}
  end
end
