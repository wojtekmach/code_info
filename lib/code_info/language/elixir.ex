defmodule CodeInfo.Language.Elixir do
  @behaviour CodeInfo.Language

  @impl true
  def functions(module) do
    module.__info__(:functions)
  end

  @impl true
  def spec_to_string(spec, kind, name, _arity) when kind in [:function, :callback] do
    name |> Code.Typespec.spec_to_quoted(spec) |> Macro.to_string()
  end

  def spec_to_string(spec, :type, _name, _arity) do
    spec |> Code.Typespec.type_to_quoted() |> Macro.to_string()
  end

  def spec_to_string(spec, kind, name, _arity) when kind in [:macro, :macrocallback] do
    name |> Code.Typespec.spec_to_quoted(spec) |> remove_first_macro_arg() |> Macro.to_string()
  end

  defp remove_first_macro_arg({:"::", info, [{name, info2, [_term_arg | rest_args]}, return]}) do
    {:"::", info, [{name, info2, rest_args}, return]}
  end

  defp remove_first_macro_arg({:when, meta, [lhs, rhs]}) do
    {:when, meta, [remove_first_macro_arg(lhs), rhs]}
  end

  @doc """
  Parses code for references.

  ## Examples

      iex> parse_ref("String")
      {:module, String}

      iex> parse_ref("c:GenServer.handle_call/3")
      {:callback, {GenServer, :handle_call, 3}}

      iex> parse_ref("a / 2")
      :error

  """
  def parse_ref(string)

  def parse_ref("mix help " <> rest) do
    parse_mix_task(rest)
  end

  def parse_ref("mix " <> rest) do
    parse_mix_task(rest)
  end

  def parse_ref("c:" <> rest) do
    with {:function, tuple} <- do_parse(rest) do
      {:callback, tuple}
    end
  end

  def parse_ref("t:" <> rest) do
    with {:function, tuple} <- do_parse(rest) do
      {:type, tuple}
    end
  end

  def parse_ref(rest) do
    do_parse(rest)
  end

  defp do_parse(string) do
    if String.contains?(string, " ") do
      :error
    else
      case Code.string_to_quoted(string, warn_on_unnecessary_quotes: false) do
        {:ok, {:__aliases__, _, parts}} ->
          {:module, Module.concat(parts)}

        {:ok, {:/, _, [{{:., _, [module, name]}, _, []}, arity]}} when is_integer(arity) ->
          {:function, {module(module), name, arity}}

        {:ok, {:/, _, [{name, _, nil}, arity]}} when is_atom(name) and is_integer(arity) ->
          {:function, {name, arity}}

        {:ok, _} ->
          :error

        {:error, _} ->
          parse_operator(string)
      end
    end
  end

  defp module(atom) when is_atom(atom), do: atom
  defp module({:__aliases__, _, parts}), do: Module.concat(parts)

  defp parse_mix_task(name) do
    name_re = ~r/[a-z]+[a-z][0-9]*/.source

    if name =~ ~r/^#{name_re}(\.#{name_re})*$/ do
      parts = name |> String.split(".") |> Enum.map(&Macro.camelize/1)
      module = Module.concat([Mix, Tasks | parts])
      {:module, module}
    else
      :error
    end
  end

  operators = [+: 1, +: 2, -: 1, -: 2, !: 1, ^: 1, &: 1]

  for {name, arity} <- operators do
    defp parse_operator(unquote("#{name}/#{arity}")) do
      {:function, {unquote(name), unquote(arity)}}
    end
  end

  defp parse_operator(_), do: :error
end
