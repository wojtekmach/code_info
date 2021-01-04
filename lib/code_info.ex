defmodule CodeInfo do
  @doc """
  Fetch info about a given module.

  ## Examples

  Get all info:

      CodeInfo.fetch(Version)
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

      CodeInfo.fetch(Version, [:doc, functions: [:signatures]])
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
  def fetch(module, filter \\ []) do
    {:docs_v1, _anno, _language, _content_type, doc, metadata, docs} = Code.fetch_docs(module)

    {:ok, types} = Code.Typespec.fetch_types(module)

    types =
      for {_kind, {name, _, args} = spec} <- types,
          into: %{} do
        {{name, length(args)}, spec}
      end

    types =
      for {{kind, name, arity}, _, signature, doc, metadata} <- docs,
          kind in [:type, :opaque, :typep],
          into: %{} do
        spec_string =
          types
          |> Map.fetch!({name, arity})
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

        map =
          filter(
            %{
              doc: doc,
              doc_metadata: metadata,
              signature: signature,
              spec_strings: spec_strings
            },
            filter[:functions]
          )

        {{name, arity}, map}
      end

    %{
      functions: functions,
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
