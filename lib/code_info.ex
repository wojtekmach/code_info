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
  @spec get(module(), filter) :: map() when filter: :* | [atom() | {atom(), filter}]
  def get(module, filter \\ :*) do
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

            put_in(acc, [:types, {name, arity}], map)

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

            put_in(acc, [:callbacks, {name, arity}], map)

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

            put_in(acc, [:macrocallbacks, {name, arity}], map)

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

            put_in(acc, [:functions, {name, arity}], map)

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

            put_in(acc, [:macros, {name, arity}], map)

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

        {{name, arity}, map}
      end

    state =
      Enum.reduce(typeps, state, fn {{name, arity}, map}, acc ->
        put_in(acc, [:types, {name, arity}], map)
      end)

    filter(state, filter)
  end

  defp filter(map, :*) do
    map
  end

  defp filter(map, filter) when is_list(filter) do
    for item <- filter, into: %{} do
      case item do
        key when is_atom(key) ->
          {key, Map.fetch!(map, key)}

        {key, filter} when is_atom(key) ->
          map =
            for {key, val} <- Map.fetch!(map, key), into: %{} do
              {key, filter(val, filter)}
            end

          {key, map}
      end
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
