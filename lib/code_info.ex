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

    documented_types =
      for {{:type, name, arity}, _, signature, doc, metadata} <- docs,
          into: %{} do
        {kind, spec} = Map.fetch!(types, {name, arity})

        spec_string =
          spec
          |> Code.Typespec.type_to_quoted()
          |> Macro.to_string()

        map = %{
          kind: kind,
          doc: doc,
          doc_metadata: metadata,
          signature: signature,
          spec_string: spec_string
        }

        map = filter(map, filter[:types])
        {{name, arity}, map}
      end

    private_types =
      for {{name, arity}, {:typep, spec}} <- types,
          into: %{} do
        spec_string =
          spec
          |> Code.Typespec.type_to_quoted()
          |> Macro.to_string()

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

    types = Map.merge(documented_types, private_types)

    {:ok, specs} = Code.Typespec.fetch_specs(module)
    specs = Map.new(specs)

    functions =
      for {{:function, name, arity}, _, signature, doc, metadata} <- docs,
          into: %{} do
        spec_strings =
          case Map.fetch(specs, {name, arity}) do
            {:ok, specs} ->
              for spec <- specs do
                name
                |> Code.Typespec.spec_to_quoted(spec)
                |> Macro.to_string()
              end

            :error ->
              nil
          end

        map = %{
          doc: doc,
          doc_metadata: metadata,
          signature: signature,
          spec_strings: spec_strings
        }

        map = filter(map, filter[:functions])
        {{name, arity}, map}
      end

    macros =
      for {{:macro, name, arity}, _, signature, doc, metadata} <- docs,
          into: %{} do
        spec_strings =
          case Map.fetch(specs, {:"MACRO-#{name}", arity + 1}) do
            {:ok, specs} ->
              for spec <- specs do
                name
                |> Code.Typespec.spec_to_quoted(spec)
                |> Macro.to_string()
              end

            :error ->
              []
          end

        map = %{
          doc: doc,
          doc_metadata: metadata,
          signature: signature,
          spec_strings: spec_strings
        }

        map = filter(map, filter[:macros])
        {{name, arity}, map}
      end

    {:ok, callbacks} = Code.Typespec.fetch_callbacks(module)
    callbacks = Map.new(callbacks)

    regular_callbacks =
      for {{:callback, name, arity}, _anno, signature, doc, metadata} <- docs,
          into: %{} do
        spec_strings =
          case Map.fetch(callbacks, {name, arity}) do
            {:ok, specs} ->
              for spec <- specs do
                name
                |> Code.Typespec.spec_to_quoted(spec)
                |> Macro.to_string()
              end

            :error ->
              nil
          end

        map = %{
          doc: doc,
          doc_metadata: metadata,
          signature: signature,
          spec_strings: spec_strings
        }

        map = filter(map, filter[:callbacks])
        {{name, arity}, map}
      end

    macro_callbacks =
      for {{:macrocallback, name, arity}, _anno, signature, doc, metadata} <- docs,
          into: %{} do
        spec_strings =
          case Map.fetch(callbacks, {:"MACRO-#{name}", arity + 1}) do
            {:ok, specs} ->
              for spec <- specs do
                name
                |> Code.Typespec.spec_to_quoted(spec)
                |> Macro.to_string()
              end

            :error ->
              nil
          end

        map = %{
          doc: doc,
          doc_metadata: metadata,
          signature: signature,
          spec_strings: spec_strings
        }

        map = filter(map, filter[:macrocallbacks])
        {{name, arity}, map}
      end

    %{
      functions: functions,
      macros: macros,
      callbacks: regular_callbacks,
      macrocallbacks: macro_callbacks,
      types: types,
      doc: doc,
      doc_metadata: metadata
    }
    |> top_filter(filter)
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
end
