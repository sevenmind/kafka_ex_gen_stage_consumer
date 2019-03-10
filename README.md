# KafkaExGenStageConsumer

A [KafkaEx.GenConsumer](https://github.com/kafkaex/kafka_ex) alternative using [GenStage](https://hexdocs.pm/gen_stage/GenStage.html) Producers for proper backpressure regulated event consumption.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `kafka_ex_gen_stage_consumer` to your list of dependencies in `mix.exs`:

```elixir
def deps do
[
  {:kafka_ex_gen_stage_consumer, git: "https://github.com/gerbal/kafka_ex_gen_stage_consumer"},
  # currently depends on an alternative kafka_ex branch
  {:kafka_ex, git: "https://github.com/gerbal/kafka_ex", branch: "custom-genconsumer"}
]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/kafka_ex_gen_stage_consumer](https://hexdocs.pm/kafka_ex_gen_stage_consumer).


`KafkaExGenStageConsumer`is a `GenStage` producer implementation of a
`KafkaEx.GenConsumer`. Unlike a GenConsumer, a `KafkaExGenStageConsumer`
consumes events from kafka in response to demand from subscribing services.
Allowing controlled consumption according to available service capacity.


## Consumer Group Supervision

`KafkaExGenStageConsumer` should be started as a `KafkaEx.GenConsumer` would
be started, except with an additional argument for the subscribing module

> n.b. This may not be the most ideal pattern, suggestions of alternate
supervision approaches are welcome.

```elixir
  defmodule MyApp do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    consumer_group_opts = [
      # setting for the ConsumerGroup
      heartbeat_interval: 1_000,
      # this setting will be forwarded to the GenConsumer
      commit_interval: 1_000,
      extra_consumer_args: [],
      commit_strategy: :async_commit
    ]

    subscriber_impl = ExampleSubscriber
    consumer_group_name = "example_group"
    topic_names = ["example_topic"]

    children = [
      # ... other children
      supervisor(
        KafkaEx.ConsumerGroup,
        [KafkaExGenStageConsumer, subscriber_impl, consumer_group_name, topic_names, consumer_group_opts]
      )
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

The subscribing module is expected to implement a single function of
`start_link/1`, which receives a tuple of `{pid, topic, partition, extra_consumer_args}`.


## Example Consumer stage

```elixir
defmodule ExampleSubscriber do
  use GenStage

  def start_link({pid, topic, partition, extra_consumer_args} = opts) do
    gen_server_options = Keyword.split([:name, :debug]) # GenServer.Options.t()
    GenStage.start_link(__MODULE__, opts, gen_server_options)
  end

  def init({pid, topic, partition, extra_consumer_args} = opts) do
    {:consumer, [], subscribe_to: [pid]}
  end

  def handle_events(events, state) do
    events
    |> Enum.map(&do_work/1)

    {:noreply, [], state}
  end
end
```

## Example `Flow` usage

```elixir
defmodule ExampleFlowConsumer do
  def start_link({pid, topic, partition, extra_consumer_args} = opts) do

    Flow.from_stages([pid])
    |> Flow.map(&decode_event/1)
    |> Flow.map(&do_work/1)
    |> Flow.map(&KafkaExGenStageConsumer.trigger_commit(pid, {:async_commit, &1.offset}))
    |> Flow.start_link()

  end
end
```

## Controlling Offset Commits

Because the Consumer Subscriber Stage is started by the Consumer, its possible
to lose events in the event of a crash or a consumer group reballance.

There are two strategies to handle this case:

1. use your consumer subscriber stage as a relay to consumers outside of the
`ConsumerGroup` supervision tree
2. use `commit_strategy: :no_commit` and add a commit offset stage to your
genstage pipeline. Call `KafkaExGenStageConsumer.trigger_commit/2` to trigger
commits