defmodule CodeInfo.SpecASTTest do
  use ExUnit.Case, async: true
  alias CodeInfo.SpecAST

  test "to_string/2" do
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
        url = "##{name}/#{arity}"
        text = name
        ~s{<a href="#{url}">#{text}/a>}

      {:remote_type, module, name, arity} ->
        url = "#{inspect(module)}.html##{name}/#{arity}"
        text = "#{inspect(module)}.#{name}"
        ~s{<a href="#{url}">#{text}</a>}
    end

    assert SpecAST.to_string(ast) ==
             ~s{t(a, b) :: Keyword.t(a) | priv(b) | atom()}

    assert SpecAST.to_string(ast, f) ==
             ~s{t(a, b) :: <a href="Keyword.html#t/1">Keyword.t</a>(a) | <a href="#priv/1">priv/a>(b) | atom()}
  end
end
