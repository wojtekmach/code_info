defmodule CodeInfo.DocASTTest do
  use ExUnit.Case, async: true
  alias CodeInfo.DocAST

  describe "parse" do
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
end
