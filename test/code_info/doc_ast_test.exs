defmodule CodeInfo.DocASTTest do
  use ExUnit.Case, async: true
  alias CodeInfo.DocAST

  describe "parse/3" do
    test "markdown" do
      markdown = """
      `String.upcase/1`
      """

      assert DocAST.parse!(markdown, "text/markdown") == [
               {"p", [],
                [
                  {"code", [{"class", "inline"}],
                   [
                     "String.upcase/1"
                   ], %{}}
                ], %{}}
             ]
    end

    test "markdown errors" do
      assert {:error, exception} = DocAST.parse("`String.upcase", "text/markdown")
      assert exception.message =~ "parsing markdown failed"

      assert exception.message =~
               "(warning) nofile:1 Closing unclosed backquotes ` at end of input"
    end

    test "erlang+html" do
      erl_ast = [
        {:a,
         [
           href: "stdlib:array#new/2",
           rel: "https://erlang.org/doc/link/seemfa"
         ], [{:code, [], ["new/2"]}]}
      ]

      assert DocAST.parse!(erl_ast, "application/erlang+html") ==
               [
                 {:a, [href: "stdlib:array#new/2", rel: "https://erlang.org/doc/link/seemfa"],
                  [
                    {:code, [], ["new/2"], %{}}
                  ], %{}}
               ]
    end
  end

  test "to_string/2" do
    markdown = """
    foo `String.upcase/1` bar
    """

    ast = DocAST.parse!(markdown, "text/markdown")

    f = fn
      {"code", _, _, _}, string ->
        String.upcase(string)

      _ast, string ->
        string
    end

    assert DocAST.to_string(ast, f) == "<p>foo <CODE>STRING.UPCASE/1</CODE> bar</p>"
  end
end
