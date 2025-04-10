if Rails.env.development? || Rails.env.production?
  #require 'bunny'
  require 'aws-sdk-sqs'

  WORKERS_LOGGER ||= Logger.new("#{Rails.root}/log/workers.log")

  # Configurar o cliente SQS
  Rails.configuration.sqs_client = Aws::SQS::Client.new(
    region: '{{ aws_region }}',
    access_key_id: ENV['{{ aws_access_key }}'],
    secret_access_key: ENV['{{ aws_secret_key }}']
  )

  # URL da fila SQS
  Rails.configuration.sqs_queue_url = ENV['{{ sqs_queue_url }}']

  resource_creator_worker = ResourceCreator.new(2, 2)
  resource_creator_worker.perform

  resource_updater_worker = ResourceUpdater.new(1, 1)
  resource_updater_worker.perform

  data_receiver_worker = DataReceiver.new(3, 3)
  data_receiver_worker.perform
end
