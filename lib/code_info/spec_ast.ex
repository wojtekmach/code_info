defmodule CodeInfo.SpecAST do
  @moduledoc false

  @doc ~S"""
  Converts AST into string.

  `format_fun` allows formatting types. It can receive one of the
  following:

    * `{:type, name, arity}`

    * `{:user_type, name, arity}`

    * `{:remote_type, module, name, arity}`

  and must return a string rendering that type.

  This is useful to autolink types:

      format_fun = fn
        {:remote_type, module, name, arity} ->
          url = "#{inspect(module)}.html##{name}/#{arity}"
          text = "#{inspect(module)}.#{name}"
          ~s|<a href="#{href}">#{text}</a>|

        ...
      end

  """
  def to_string(ast, format_fun) do
    quoted = Code.Typespec.type_to_quoted(ast)
    {quoted, acc} = f(quoted)
    acc = Enum.reverse(acc)
    string = Macro.to_string(quoted)
    init!(acc)

    Regex.replace(~r/_+/, string, fn _placeholder ->
      case pop!() do
        {:var, var} ->
          "#{var}"

        other ->
          format_fun.(other)
      end
    end)
  end

  @id {__MODULE__, :placeholders}

  defp init!(items) do
    Process.put(@id, items)
  end

  defp pop!() do
    [head | tail] = Process.get(@id)
    Process.put(@id, tail)
    head
  end

  defp f(quoted) do
    f(quoted, [])
  end

  defp f({:"::", meta1, [{name, meta2, args}, rhs]}, acc) do
    {args, acc} = f(args, acc)
    {rhs, acc} = f(rhs, acc)
    {{:"::", meta1, [{name, meta2, args}, rhs]}, acc}
  end

  defp f(quoted, acc) do
    Macro.prewalk(quoted, acc, fn
      {:"::", _, _} = ast, acc ->
        {ast, acc}

      {:|, _, _} = ast, acc ->
        {ast, acc}

      {{:., meta, [module, name]}, _, args}, acc ->
        ast = {placeholder("#{inspect(module)}.#{name}"), meta, args}
        identifier = {:remote_type, module, name, length(args)}
        {ast, [identifier | acc]}

      {name, meta, args}, acc when is_atom(name) and is_list(args) ->
        ast = {placeholder(name), meta, args}
        arity = length(args)

        identifier =
          cond do
            basic_type?({name, arity}) ->
              {:type, name, arity}

            built_in_type?({name, arity}) ->
              {:type, name, arity}

            true ->
              {:user_type, name, arity}
          end

        {ast, [identifier | acc]}

      other, acc ->
        {other, acc}
    end)
  end

  defp placeholder(atom) when is_atom(atom) do
    atom |> Atom.to_string() |> placeholder()
  end

  defp placeholder(binary) when is_binary(binary) do
    "_"
    |> String.duplicate(byte_size(binary))
    |> String.to_atom()
  end

  @basic_types [
    any: 0,
    none: 0,
    atom: 0,
    map: 0,
    pid: 0,
    port: 0,
    reference: 0,
    struct: 0,
    tuple: 0,
    float: 0,
    integer: 0,
    neg_integer: 0,
    non_neg_integer: 0,
    pos_integer: 0,
    list: 1,
    nonempty_list: 1,
    maybe_improper_list: 2,
    nonempty_improper_list: 2,
    nonempty_maybe_improper_list: 2
  ]

  @built_in_types [
    term: 0,
    arity: 0,
    as_boolean: 1,
    binary: 0,
    bitstring: 0,
    boolean: 0,
    byte: 0,
    char: 0,
    charlist: 0,
    nonempty_charlist: 0,
    fun: 0,
    function: 0,
    identifier: 0,
    iodata: 0,
    iolist: 0,
    keyword: 0,
    keyword: 1,
    list: 0,
    nonempty_list: 0,
    maybe_improper_list: 0,
    nonempty_maybe_improper_list: 0,
    mfa: 0,
    module: 0,
    no_return: 0,
    node: 0,
    number: 0,
    struct: 0,
    timeout: 0
  ]

  def basic_type?(type) do
    type in @basic_types
  end

  def built_in_type?(type) do
    type in @built_in_types
  end
end
