# frozen_string_literal: true

module UmbrellioUtils::Jobs
  extend self

  Worker = Data.define(:name)
  Capsule = Data.define(:name, :worker, :weight)
  Queue = Data.define(:name, :capsule, :weight)

  MIN_RETRY_INTERVAL = 10.seconds
  MAX_RETRY_INTERVAL = 4.hours

  def workers
    @workers ||= []
  end

  def capsules
    @capsules ||= []
  end

  def queues
    @queues ||= []
  end

  def register_worker(name)
    workers << Worker.new(name:)
  end

  def register_capsule(name, worker: :default, weight: 1)
    workers.find { |x| x.name == worker } or raise "Worker not found: #{worker.inspect}"
    capsules << Capsule.new(name:, worker:, weight:)
  end

  def register_queue(name, capsule: :default, weight: 1)
    capsules.find { |x| x.name == capsule } or raise "Capsule not found: #{capsule.inspect}"
    queues << Queue.new(name:, capsule:, weight:)
  end

  def retry_interval(error_count)
    interval = MIN_RETRY_INTERVAL * (1.3**(error_count - 3))

    interval
      .then { |x| [x, MIN_RETRY_INTERVAL].max }
      .then { |x| [x, MAX_RETRY_INTERVAL].min }
      .round
  end

  def capsules_for(worker, max_concurrency)
    capsules = self.capsules.select do |capsule|
      next unless capsule.worker.to_s == worker.underscore.to_s
      next unless queues.select { |queue| queue.capsule == capsule.name }.any?
      true
    end

    total_weight = capsules.sum(&:weight)

    result = capsules.filter_map do |capsule|
      weight_coef = capsule.weight / total_weight.to_f
      concurrency = (max_concurrency * weight_coef).to_i
      concurrency = 1 unless concurrency > 1
      queues = self.queues.select { |x| x.capsule == capsule.name }.map { |x| [x.name, x.weight] }
      [capsule.name, queues, concurrency]
    end

    raise "No queues found for worker #{worker.inspect}" if result.empty?

    result
  end

  def validate_queue_name!(queue_name)
    found = queues.any? do |queue|
      queue.name.to_s == queue_name.to_s
    end

    raise "Unknown queue: #{queue_name.inspect}" unless found
  end
end
