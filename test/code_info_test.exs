defmodule CodeInfoTest do
  use ExUnit.Case, async: true

  test "get/2" do
    c(~S"""
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

      @doc "function1 docs"
      @doc since: "1.0.0"
      @spec function1() :: :ok
      def function1() do
        :ok
      end

      @doc "macro1 docs"
      @spec macro1() :: :ok
      defmacro macro1() do
        :ok
      end
    end
    """)

    info = CodeInfo.get(M)

    assert info.doc == %{"en" => "M docs"}
    assert info.doc_metadata == %{}

    assert Map.fetch!(info.types, {:type1, 0}) == %{
             kind: :type,
             doc: %{"en" => "type1 docs"},
             doc_metadata: %{},
             signature: [],
             spec_string: "type1() :: integer()"
           }

    assert Map.fetch!(info.types, {:opaque1, 0}) == %{
             kind: :opaque,
             doc: %{"en" => "opaque1 docs"},
             doc_metadata: %{opaque: true},
             signature: [],
             spec_string: "opaque1() :: typep1()"
           }

    assert Map.fetch!(info.types, {:typep1, 0}) == %{
             kind: :typep,
             doc: :none,
             doc_metadata: %{},
             signature: [],
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
             # TODO: remove macro first arg
             spec_strings: ["macrocallback1(term()) :: :ok"]
           }

    assert Map.fetch!(info.functions, {:function1, 0}) == %{
             doc: %{"en" => "function1 docs"},
             doc_metadata: %{since: "1.0.0"},
             signature: ["function1()"],
             spec_strings: ["function1() :: :ok"]
           }

    assert Map.fetch!(info.macros, {:macro1, 0}) == %{
             doc: %{"en" => "macro1 docs"},
             doc_metadata: %{},
             signature: ["macro1()"],
             # TODO: remove macro first arg
             spec_strings: ["macro1(term()) :: :ok"]
           }
  end

  defp c(code) do
    [{module, bytecode}] = Code.compile_string(code)
    beam_path = "#{module}.beam"
    File.write!(beam_path, bytecode)

    on_exit(fn ->
      :code.purge(module)
      :code.delete(module)
      File.rm!(beam_path)
    end)
  end
end
