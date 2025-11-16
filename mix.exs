defmodule PostMeetingApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :post_meeting_app,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixir_paths: elixir_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {PostMeetingApp.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixir_paths(:test), do: ["lib", "test/support"]
  defp elixir_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.7.0"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.10"},
       {:gettext, "~> 0.18"},
       {:hackney, "~> 1.18"},
       {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.20.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.0"},
      {:esbuild, "~> 0.7", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.3"},
      {:finch, "~> 0.16"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},
      {:oban, "~> 2.17"},
      {:ueberauth, "~> 0.10"},
      {:ueberauth_google, "~> 0.10"},
      {:oauth2, "~> 2.0"},
      {:mox, "~> 1.0", only: :test},
      {:ex_machina, "~> 2.7", only: :test},
       {:dotenv, "~> 3.0"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end

