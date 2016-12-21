module IntegrationTestHelpers
  def allow_receivers_to_process_queues(ms_to_sleep = 1_000)
    sleep (ms_to_sleep.to_f / 1_000.0)
  end
end
