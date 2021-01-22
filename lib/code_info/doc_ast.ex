defmodule CodeInfo.DocAST do
  @moduledoc false

  def parse(doc, doc_format, options \\ [])

  def parse(markdown, "text/markdown", opts) do
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

  def parse(erl_ast, "application/erlang+html", []) do
    {:ok, from_erl_ast(erl_ast)}
  end

  defp from_erl_ast(binary) when is_binary(binary) do
    binary
  end

  defp from_erl_ast(list) when is_list(list) do
    Enum.map(list, &from_erl_ast/1)
  end

  defp from_erl_ast({tag, attrs, content}) when is_atom(tag) do
    {tag, attrs, from_erl_ast(content), %{}}
  end

  def parse!(doc, doc_format, options \\ []) do
    case parse(doc, doc_format, options) do
      {:ok, ast} ->
        ast

      {:error, exception} ->
        raise exception
    end
  end
end
