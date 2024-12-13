defmodule PhxInterior.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PhxInteriorWeb.Telemetry,
      PhxInterior.Repo,
      {DNSCluster, query: Application.get_env(:phx_interior, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PhxInterior.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: PhxInterior.Finch},
      # Start a worker by calling: PhxInterior.Worker.start_link(arg)
      # {PhxInterior.Worker, arg},
      # Start to serve requests, typically the last entry
      PhxInteriorWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PhxInterior.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PhxInteriorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
