defmodule Snapex7.MixProject do
  use Mix.Project

  def project do
    [
      app: :snapex7,
      version: "0.1.1",
      elixir: "~> 1.7.2",
      start_permanent: Mix.env() == :prod,
      compilers: [:elixir_make] ++ Mix.compilers(),
      make_executable: "make",
      deps: deps(),
      name: "Snapex7",
      description: description(),
      package: package(),
      source_url: "https://github.com/valiot/snapex7"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description() do
    "Elixir wrapper for Snap7, for communication with Siemens PLC's."
  end

  defp package() do
    [
      files: [
        "lib",
        "src/*.[ch]",
        "src/snap7/src",
        "src/snap7/build",
        "src/snap7/examples/plain-c/*.h",
        "Makefile",
        "test",
        "mix.exs",
        "README.md",
        "LICENSE",
      ],
      maintainers: ["valiot"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/valiot/snapex7"}
    ]
  end


  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:elixir_make, "~> 0.4", runtime: false},
      {:ex_doc, "~> 0.19", only: :dev}
    ]
  end
end
