defmodule CodeInfo.SpecASTTest do
  use ExUnit.Case, async: true
  alias CodeInfo.SpecAST

  describe "to_string/3" do
    test "it works" do
      ast =
        quote do
          t(a, b) :: Keyword.t(a) | priv(b) | atom() when a: atom()
        end

      f = fn
        {:type, :atom, 0} -> "ATOM"
        {:user_type, :priv, 1} -> "PRIV"
        {:remote_type, Keyword, :t, 1} -> "KEYWORD.T"
      end

      assert SpecAST.to_string(ast, f) ==
               ~s{t(a, b) :: KEYWORD.T(a) | PRIV(b) | ATOM() when a: ATOM()}
    end

    test "underscores" do
      ast =
        quote do
          _f_(a_1, b_2) :: a_1 | b_2
        end

      f = fn
        {:type, name, 0} -> String.upcase("#{name}")
      end

      assert SpecAST.to_string(ast, f) ==
               ~s{_f_(a_1, b_2) :: a_1 | b_2}
    end

    test "operators" do
      ast =
        quote do
          integer() + float() :: float()
        end

      f = fn
        {:type, name, 0} -> String.upcase("#{name}")
      end

      assert SpecAST.to_string(ast, f) ==
               ~s{INTEGER() + FLOAT() :: FLOAT()}
    end

    test "formatter" do
      ast =
        quote do
          f(super_long_variable_name, super_long_variable_name, super_long_type_name()) ::
            super_long_type_name()
        end

      f = fn
        {:user_type, name, 0} -> String.upcase("#{name}")
      end

      assert SpecAST.to_string(ast, f) == """
             f(super_long_variable_name, super_long_variable_name, SUPER_LONG_TYPE_NAME()) ::
               SUPER_LONG_TYPE_NAME()\
             """
    end
  end
end
