defmodule Estructura do
  @moduledoc ~S"""
  `Estructura` is a set of extensions for Elixir structures,
    such as `Access` implementation, `Enumerable` and `Collectable`
    implementations, validations and test data generation via `StreamData`.

  `Estructura` simplifies the following

    * `Access` implementation for structs
    * `Enumerable` implementation for structs (as maps)
    * `Collectable` implementation for one of struct’s fields (as `MapSet` does)
    * `StreamData` generation of structs for property-based testing

  ### Use Options

  `use Estructura` accepts four keyword arguments.

    * `access: boolean()` whether to generate the `Access` implementation, default `true`; when `true`,
      it also produces `put/3` and `get/3` methods to be used with `coercion` and `validation`
    * `coercion: boolean() | [key()]` whether to generate the bunch of `coerce_×××/1` functions
      to be overwritten by implementations, default `false`
    * `validation: boolean() | [key()]` whether to generate the bunch of `validate_×××/1` functions
      to be overwritten by implementations, default `false`
    * `enumerable: boolean()` whether to generate the `Enumerable` porotocol implementation, default `false`
    * `collectable: false | key()` whether to generate the `Collectable` protocol implementation,
      default `false`; if non-falsey atom is given, it must point to a struct field where `Collectable`
      would collect. Should be one of `list()`, `map()`, `MapSet.t()`, `bitstribg()`
    * `generator: %{optional(key()) => Estructura.Config.generator()}` the instructions
      for the `__generate__/{0,1}` functions that would produce the target structure values suitable
      for usage in `StreamData` property testing; the generated `__generator__/1` function is overwritable.

  Please note, that setting `coercion` and/or `validation` to truthy values has effect
    if and only if `access` has been also set to `true`.

  Typical example of usage would be:

  ```elixir
  defmodule MyStruct do
    use Estructura,
      access: true,
      coercion: [:foo], # requires `c:MyStruct.Coercible.coerce_foo/1` impl
      validation: true, # requires `c:MyStruct.Validatable.validate_×××/1` impls
      enumerable: true,
      collectable: :bar,
      generator: [
        foo: {StreamData, :integer},
        bar: {StreamData, :list_of, [{StreamData, :string, [:alphanumeric]}]},
        baz: {StreamData, :fixed_map,
          [[key1: {StreamData, :integer}, key2: {StreamData, :integer}]]}
      ]

    defstruct foo: 42, bar: [], baz: %{}

    @impl MyStruct.Coercible
    def coerce_foo(value) when is_integer(value), do: {:ok, value}
    def coerce_foo(value) when is_float(value), do: {:ok, round(value)}
    def coerce_foo(value) when is_binary(value) do
      case Integer.parse(value) do
        {value, ""} -> {:ok, value}
        _ -> {:error, "#{value} is not a valid integer value"}
      end
    end
    def coerce_foo(value),
      do: {:error, "Cannot coerce value given for `foo` field (#{inspect(value)})"}

    @impl MyStruct.Validatable
    def validate_foo(value) when value >= 0, do: {:ok, value}
    def validate_foo(_), do: {:error, ":foo must be positive"}

    @impl MyStruct.Validatable
    def validate_bar(value), do: {:ok, value}

    @impl MyStruct.Validatable
    def validate_baz(value), do: {:ok, value}
  end
  ```

  The above would allow the following to be done with the structure:

  ```elixir
  s = %MyStruct{}

  put_in s, [:foo], :forty_two
  #⇒ %MyStruct{foo: :forty_two, bar: [], baz: %{}}

  for i <- [1, 2, 3], into: s, do: i
  #⇒ %MyStruct{foo: 42, bar: [1, 2, 3], baz: %{}}

  Enum.map(s, &elem(&1, 1))
  #⇒ [42, [], %{}]

  MyStruct.__generator__() |> Enum.take(3)
  #⇒ [
  #      %MyStruct{bar: [], baz: %{key1: 0, key2: 0}, foo: -1},
  #      %MyStruct{bar: ["g", "xO"], baz: %{key1: -1, key2: -2}, foo: 2},
  #      %MyStruct{bar: ["", "", ""], baz: %{key1: -3, key2: 1}, foo: -1}
  #    ]
  ```

  ### Coercion

  When `coercion: true | [key()]` is passed as an argument to `use Estructura`,
  the nested behaviour `Coercible` is generated and the target module claims to implement it.

  To make a coercion work with `MyStruct.put/3` and `put_in/3` provided
  by `Access` implementation, the consumer module should implement `MyStruct.Coercible`
  behaviour.

  For the consumer convenience, the warnings for not implemented functions will be issued by compiler.

  ### Validation

  When `validation: true | [key()]` is passed as an argument to `use Estructura`,
  the nested behaviour `Validatable` is generated and the target module claims to implement it.

  To make a validation work with `MyStruct.put/3` and `put_in/3` provided
  by `Access` implementation, the consumer module should implement `MyStruct.Validatable`
  behaviour.

  For the consumer convenience, the warnings for not implemented functions will be issued by compiler.

  ### Generation

  If `generator` keyword argument has been passed, `MyStruct.__generate__/{0,1}` can be
  used to generate instances of this struct for `StreamData` property based tests.

  ```elixir
  property "generation" do
    check all %MyStruct{foo: foo, bar: bar, baz: baz} <- MyStruct.__generator__() do
      assert match?(%{key1: v1, key2: v2} when is_integer(v1) and is_integer(v2), baz)
      assert is_integer(foo)
      assert is_binary(bar)
    end
  end
  ```
  """

  use Boundary

  @doc false
  defmacro __using__(opts) do
    quote do
      @__estructura__ struct!(Estructura.Config, unquote(opts))

      @before_compile {Estructura.Hooks, :inject_estructura}
    end
  end
end
