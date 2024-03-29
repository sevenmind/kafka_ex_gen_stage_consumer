defmodule KafkaExGenStageConsumer.MixProject do
  use Mix.Project

  def project do
    [
      app: :kafka_ex_gen_stage_consumer,
      version: "0.1.2",
      elixir: "~> 1.10",
      dialyzer: [
        plt_add_deps: :transitive,
        flags: [
          :error_handling,
          :race_conditions
        ]
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test],
      description: description(),
      package: package(),
      deps: deps(),
      docs: [
        main: "readme",
        extras: ["README.md"],
        source_url: "https://github.com/kafkaex/kafka_ex"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:gen_stage, "~> 1.0"},
      {:kafka_ex, "~> 0.12"},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end

  defp description do
    "KafkaEx GenConsumer using GenStage"
  end

  defp package do
    [
      maintainers: [],
      files: [],
      licenses: [],
      links: %{}
    ]
  end
end
