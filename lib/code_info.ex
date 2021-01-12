defmodule CodeInfo do
  @moduledoc """
  Functions for getting information about modules.
  """

  @doc """
  Get info about a given module.

  ## Examples

  Get all info:

      CodeInfo.get(Version)
      %{
        doc: %{
          "en" => "Functions for parsing and matching versions against requirements." <> _
        },
        doc_metadata: %{...},
        functions: [...],
        types: [...],
        ...
      }

  Get just module doc and function signatures:

      CodeInfo.get(Version, [:doc, functions: [:signatures]])
      %{
        doc: %{
          "en" => "Functions for parsing and matching versions against requirements." <> _,
        },
        functions: %{
          {:__struct__, 0} => %{signature: ["%Version{}"]},
          {:__struct__, 1} => %{signature: ["__struct__(kv)"]},
          {:compare, 2} => %{signature: ["compare(version1, version2)"]},
          ...
        }
      }

  """
  @spec get(module(), [atom() | {atom(), [atom()] | :*}]) :: map()
  def get(module, filter \\ []) do
    {:docs_v1, _anno, _language, _content_type, doc, metadata, docs} = Code.fetch_docs(module)

    {:ok, types} = Code.Typespec.fetch_types(module)

    types =
      for {kind, {name, _, args} = spec} <- types,
          into: %{} do
        {{name, length(args)}, {kind, spec}}
      end

    {:ok, specs} = Code.Typespec.fetch_specs(module)
    specs = Map.new(specs)

    {:ok, callbacks} = Code.Typespec.fetch_callbacks(module)
    callbacks = Map.new(callbacks)

    state = %{
      types: %{},
      callbacks: %{},
      macrocallbacks: %{},
      functions: %{},
      macros: %{},
      doc: doc,
      doc_metadata: metadata
    }

    state =
      Enum.reduce(docs, state, fn {{kind, name, arity}, _anno, signature, doc, metadata}, acc ->
        case kind do
          :type ->
            {kind, spec} = Map.fetch!(types, {name, arity})
            spec_string = type_spec_to_string(spec)

            map = %{
              kind: kind,
              doc: doc,
              doc_metadata: metadata,
              signature: signature,
              spec_string: spec_string
            }

            put_in(acc, [:types, {name, arity}], filter(map, filter[:types]))

          :callback ->
            spec_strings =
              case Map.fetch(callbacks, {name, arity}) do
                {:ok, specs} -> Enum.map(specs, &function_spec_to_string(&1, name))
                :error -> []
              end

            map = %{
              doc: doc,
              doc_metadata: metadata,
              signature: signature,
              spec_strings: spec_strings
            }

            put_in(acc, [:callbacks, {name, arity}], filter(map, filter[:callbacks]))

          :macrocallback ->
            spec_strings =
              case Map.fetch(callbacks, {:"MACRO-#{name}", arity + 1}) do
                {:ok, specs} -> Enum.map(specs, &macro_spec_to_string(&1, name))
                :error -> []
              end

            map = %{
              doc: doc,
              doc_metadata: metadata,
              signature: signature,
              spec_strings: spec_strings
            }

            put_in(acc, [:macrocallbacks, {name, arity}], filter(map, filter[:macrocallbacks]))

          :function ->
            spec_strings =
              case Map.fetch(specs, {name, arity}) do
                {:ok, specs} -> Enum.map(specs, &function_spec_to_string(&1, name))
                :error -> []
              end

            map = %{
              doc: doc,
              doc_metadata: metadata,
              signature: signature,
              spec_strings: spec_strings
            }

            put_in(acc, [:functions, {name, arity}], filter(map, filter[:functions]))

          :macro ->
            spec_strings =
              case Map.fetch(specs, {:"MACRO-#{name}", arity + 1}) do
                {:ok, specs} -> Enum.map(specs, &macro_spec_to_string(&1, name))
                :error -> []
              end

            map = %{
              doc: doc,
              doc_metadata: metadata,
              signature: signature,
              spec_strings: spec_strings
            }

            put_in(acc, [:macros, {name, arity}], filter(map, filter[:macros]))

          _ ->
            acc
        end
      end)

    typeps =
      for {{name, arity}, {:typep, spec}} <- types,
          into: %{} do
        spec_string = type_spec_to_string(spec)

        map = %{
          kind: :typep,
          doc: :none,
          doc_metadata: %{},
          signature: [],
          spec_string: spec_string
        }

        map = filter(map, filter[:types])
        {{name, arity}, map}
      end

    state =
      Enum.reduce(typeps, state, fn {{name, arity}, map}, acc ->
        put_in(acc, [:types, {name, arity}], map)
      end)

    top_filter(state, filter)
  end

  defp top_filter(thing, filter) do
    if filter != [] do
      keys =
        Enum.map(filter, fn
          key when is_atom(key) ->
            key

          {key, _} when is_atom(key) ->
            key
        end)

      Map.take(thing, keys)
    else
      thing
    end
  end

  defp filter(thing, filter) do
    if filter && filter != :* do
      Map.take(thing, filter)
    else
      thing
    end
  end

  defp function_spec_to_string(spec, name) do
    name |> Code.Typespec.spec_to_quoted(spec) |> Macro.to_string()
  end

  defp macro_spec_to_string(spec, name) do
    name |> Code.Typespec.spec_to_quoted(spec) |> remove_first_macro_arg() |> Macro.to_string()
  end

  defp type_spec_to_string(spec) do
    spec |> Code.Typespec.type_to_quoted() |> Macro.to_string()
  end

  defp remove_first_macro_arg({:"::", info, [{name, info2, [_term_arg | rest_args]}, return]}) do
    {:"::", info, [{name, info2, rest_args}, return]}
  end

  defp remove_first_macro_arg({:when, meta, [lhs, rhs]}) do
    {:when, meta, [remove_first_macro_arg(lhs), rhs]}
  end
end
