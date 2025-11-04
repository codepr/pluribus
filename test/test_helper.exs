ExUnit.start()

Logger.configure_backend(:console, level: :warning)

# Start the application supervision tree for tests
{:ok, _} = Application.ensure_all_started(:pluribus)
