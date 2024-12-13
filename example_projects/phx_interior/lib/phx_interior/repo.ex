defmodule PhxInterior.Repo do
  use Ecto.Repo,
    otp_app: :phx_interior,
    adapter: Ecto.Adapters.Postgres
end
