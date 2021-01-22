defmodule CodeInfo.SpecASTTest do
  use ExUnit.Case, async: true
  alias CodeInfo.SpecAST
  alias CodeInfo.Language

  test "elixir" do
    TestHelper.elixirc(~S"""
    defmodule M do
      @type t(a, b) :: Keyword.t(a) | priv(b) | atom()

      @typep priv(a) :: [a]
    end
    """)

    info = CodeInfo.get(M)
    ast = get_in(info, [:types, {:t, 2}, :spec_ast])

    f = fn
      {:type, name, _arity} ->
        "#{name}"

      {:user_type, name, arity} ->
        ~s{<a href="##{name}/#{arity}"><#{name}/a>}

      {:remote_type, module, name, arity} ->
        ~s{<a href="#{inspect(module)}.html##{name}/#{arity}">#{inspect(module)}.#{name}</a>}
    end

    assert SpecAST.to_string(ast, Language.Elixir) ==
             ~s{t(a, b) :: Keyword.t(a) | priv(b) | atom()}

    assert SpecAST.to_string(ast, Language.Elixir, f) ==
             ~s{t(a, b) :: <a href="Keyword.html#t/1">Keyword.t</a>(a) | <a href="#priv/1"><priv/a>(b) | atom()}
  end

  test "erlang" do
    TestHelper.erlc(:m, ~S"""
    -module(m).
    -export_type([t/1]).

    -type t(Type) :: array:array(Type) | atom().
    """)

    info = CodeInfo.get(:m)
    ast = get_in(info, [:types, {:t, 1}, :spec_ast])

    f = fn
      {:type, name, _arity} ->
        "#{name}"

      {:user_type, name, arity} ->
        ~s{<a href="##{name}/#{arity}"><#{name}/a>}

      {:remote_type, module, name, arity} ->
        ~s{<a href="#{module}.html##{name}/#{arity}">#{module}:#{name}</a>}
    end

    assert SpecAST.to_string(ast, Language.Erlang) ==
             ~s{-type t(Type) :: array:array(Type) | atom().}

    assert SpecAST.to_string(ast, Language.Erlang, f) ==
             ~s{-type t(Type) :: <a href="array.html#array/1">array:array</a>(Type) | atom().}
  end
end
