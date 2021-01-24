defmodule CodeInfo.DocAST do
  @moduledoc false

  @doc """
  Parse given `doc` according to `doc_format`.
  """
  def parse(doc, doc_format, options \\ [])

  def parse(markdown, "text/markdown", opts) do
    parse_markdown(markdown, opts)
  end

  def parse(ast, "application/erlang+html", []) do
    {:ok, parse_erl_ast(ast)}
  end

  @doc """
  See `parse/3`.
  """
  def parse!(doc, doc_format, options \\ []) do
    case parse(doc, doc_format, options) do
      {:ok, ast} -> ast
      {:error, exception} -> raise exception
    end
  end

  @doc """
  Transform AST into string.
  """
  def to_string(ast, fun \\ fn _ast, string -> string end)

  def to_string(binary, _fun) when is_binary(binary) do
    binary
  end

  def to_string(list, fun) when is_list(list) do
    result = Enum.map_join(list, "", &to_string(&1, fun))
    fun.(list, result)
  end

  def to_string({tag, _attrs, inner, _meta} = ast, fun) do
    result = "<#{tag}>" <> to_string(inner, fun) <> "</#{tag}>"
    fun.(ast, result)
  end

  ## markdown

  defp parse_markdown(markdown, opts) do
    opts = [
      gfm: Keyword.get(opts, :gfm, true),
      line: Keyword.get(opts, :line, 1),
      file: Keyword.get(opts, :file, "nofile"),
      breaks: Keyword.get(opts, :breaks, false),
      smartypants: Keyword.get(opts, :smartypants, false),
      pure_links: true
    ]

    case EarmarkParser.as_ast(markdown, opts) do
      {:ok, ast, messages} ->
        [] = messages
        {:ok, ast}

      {:error, _, messages} ->
        message =
          for {severity, line, message} <- messages do
            file = opts[:file]
            "(#{severity}) #{file}:#{line} #{message}"
          end
          |> Enum.join("\n")

        exception = RuntimeError.exception("parsing markdown failed\n\n" <> message)
        {:error, exception}
    end
  end

  ## erlang+html

  defp parse_erl_ast(binary) when is_binary(binary) do
    binary
  end

  defp parse_erl_ast(list) when is_list(list) do
    Enum.map(list, &parse_erl_ast/1)
  end

  defp parse_erl_ast({tag, attrs, content}) when is_atom(tag) do
    {tag, attrs, parse_erl_ast(content), %{}}
  end
end
