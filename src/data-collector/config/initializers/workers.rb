if Rails.env.development? || Rails.env.production?
  #require 'bunny'
  require 'aws-sdk-sqs'

  WORKERS_LOGGER ||= Logger.new("#{Rails.root}/log/workers.log")

  # Rails.configuration.worker_conn = Bunny.new(
  #   hostname: SERVICES_CONFIG['services']['rabbitmq'],
  #   logger: WORKERS_LOGGER,
  # )
  # Rails.configuration.worker_conn.start

  # Configurar o cliente SQS
  Rails.configuration.sqs_client = Aws::SQS::Client.new(
    region: 'sa-east-1',
    access_key_id: ENV['AWS_ACCESS_KEY_ID'],
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
  )

  # URL da fila SQS
  Rails.configuration.sqs_queue_url = ENV['SQS_QUEUE_URL']

  resource_creator_worker = ResourceCreator.new(2, 2)
  resource_creator_worker.perform

  resource_updater_worker = ResourceUpdater.new(1, 1)
  resource_updater_worker.perform

  data_receiver_worker = DataReceiver.new(3, 3)
  data_receiver_worker.perform
end
