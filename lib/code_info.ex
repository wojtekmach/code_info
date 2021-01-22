defmodule CodeInfo do
  @moduledoc """
  Functions for getting information about modules.
  """

  def get(module, filter \\ :*) do
    case fetch(module, filter) do
      {:ok, info} -> info
      {:error, :module_not_found} -> nil
    end
  end

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

      CodeInfo.get(Version, [:doc, functions: [:signature]])
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
  @spec fetch(module(), filter) :: {:ok, map()} | {:error, :module_not_found}
        when filter: :* | [atom() | {atom(), filter}]
  def fetch(module, filter \\ :*) do
    case Code.fetch_docs(module) do
      {:docs_v1, _anno, language, doc_format, doc, doc_metadata, docs} ->
        {:ok, fetch(module, language(language), doc_format, doc, doc_metadata, docs, filter)}

      {:error, :chunk_not_found} ->
        language = CodeInfo.Language.Erlang
        doc_format = nil
        doc = :none
        doc_metadata = %{}
        docs = %{}
        {:ok, fetch(module, language, doc_format, doc, doc_metadata, docs, filter)}

      {:error, _} = error ->
        error
    end
  end

  defp language(:elixir), do: CodeInfo.Language.Elixir
  defp language(:erlang), do: CodeInfo.Language.Erlang

  defp fetch(module, language, doc_format, doc, doc_metadata, docs, filter) do
    types = fetch_types(module)
    specs = fetch_specs(module)
    callbacks = fetch_callbacks(module)

    state = %{
      types: %{},
      callbacks: %{},
      macrocallbacks: %{},
      functions: %{},
      macros: %{},
      doc: doc,
      doc_format: doc_format,
      doc_metadata: doc_metadata
    }

    state =
      Enum.reduce(docs, state, fn {{kind, name, arity}, _anno, signature, doc, metadata}, acc ->
        case kind do
          :type ->
            map = type(types, language, name, arity, doc, metadata, signature)
            put_in(acc, [:types, {name, arity}], map)

          :callback ->
            map = callback(callbacks, language, name, arity, doc, metadata, signature)
            put_in(acc, [:callbacks, {name, arity}], map)

          :macrocallback ->
            spec_strings =
              case Map.fetch(callbacks, {:"MACRO-#{name}", arity + 1}) do
                {:ok, specs} -> Enum.map(specs, &language.spec_to_string(&1, :macro, name, arity))
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
                {:ok, specs} ->
                  Enum.map(specs, &language.spec_to_string(&1, :function, name, arity))

                :error ->
                  []
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
                {:ok, specs} -> Enum.map(specs, &language.spec_to_string(&1, :macro, name, arity))
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

    state
    |> put_missing_types(language, types)
    |> put_missing_callbacks(language, callbacks)
    |> put_missing_functions(language, module, specs)
    |> filter(filter)
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

  defp fetch_types(module) do
    types =
      case Code.Typespec.fetch_types(module) do
        {:ok, types} -> types
        :error -> []
      end

    for {kind, {name, _, args} = spec} <- types,
        into: %{} do
      {{name, length(args)}, {kind, spec}}
    end
  end

  defp fetch_specs(module) do
    case Code.Typespec.fetch_specs(module) do
      {:ok, specs} -> Map.new(specs)
      :error -> %{}
    end
  end

  defp fetch_callbacks(module) do
    case Code.Typespec.fetch_callbacks(module) do
      {:ok, callbacks} -> Map.new(callbacks)
      :error -> %{}
    end
  end

  # Add types that are in Dbgi chunk but not in Docs chunk.
  #
  # - Elixir doesn't put @typep into docs chunk
  # - xml_from_edoc + docgen_xml_to_chunk doesn't put types into chunk
  # - module may not have Docs chunk at all
  defp put_missing_types(state, language, types) do
    types =
      Enum.reduce(Map.keys(types), state.types, fn {name, arity}, acc ->
        map = type(types, language, name, arity, :none, %{}, [])
        Map.put_new(acc, {name, arity}, map)
      end)

    put_in(state.types, types)
  end

  defp type(types, language, name, arity, doc, doc_metadata, signature) do
    {kind, spec} = Map.fetch!(types, {name, arity})

    %{
      kind: kind,
      doc: doc,
      doc_metadata: doc_metadata,
      signature: signature,
      spec_ast: spec,
      spec_string: language.spec_to_string(spec, :type, name, arity)
    }
  end

  # Add callbacks that are in Dbgi chunk but not in Docs chunk.
  #
  # - xml_from_edoc + docgen_xml_to_chunk doesn't put callbacks into chunk.
  # - module may not have Docs chunk at all
  defp put_missing_callbacks(state, language, callbacks) do
    callbacks =
      Enum.reduce(Map.keys(callbacks), state.callbacks, fn {name, arity}, acc ->
        map = callback(callbacks, language, name, arity, :none, %{}, [])
        Map.put_new(acc, {name, arity}, map)
      end)

    put_in(state.callbacks, callbacks)
  end

  defp callback(callbacks, language, name, arity, doc, doc_metadata, signature) do
    spec_strings =
      case Map.fetch(callbacks, {name, arity}) do
        {:ok, specs} -> Enum.map(specs, &language.spec_to_string(&1, :callback, name, arity))
        :error -> []
      end

    %{
      doc: doc,
      doc_metadata: doc_metadata,
      signature: signature,
      spec_strings: spec_strings
    }
  end

  # Add functions that are not in the Docs chunk. 
  #
  # - module may not have Docs chunk at all
  defp put_missing_functions(state, language, module, specs) do
    functions = language.functions(module)

    functions =
      Enum.reduce(functions, state.functions, fn {name, arity}, acc ->
        spec_strings =
          case Map.fetch(specs, {name, arity}) do
            {:ok, specs} -> Enum.map(specs, &language.spec_to_string(&1, :function, name, arity))
            :error -> []
          end

        map = %{
          doc: :hidden,
          doc_metadata: %{},
          signature: [],
          spec_strings: spec_strings
        }

        Map.put_new(acc, {name, arity}, map)
      end)

    put_in(state.functions, functions)
  end
end
