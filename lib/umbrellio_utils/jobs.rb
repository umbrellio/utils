# frozen_string_literal: true

module UmbrellioUtils::Jobs
  extend self

  Worker = Struct.new(:name)
  Capsule = Struct.new(:name, :worker, :weight)
  Queue = Struct.new(:name, :capsule, :weight)
  Entry = Struct.new(:capsule, :queues, :concurrency)

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
    workers << Worker.new(name)
  end

  def register_capsule(name, worker: :default, weight: 1)
    workers.find { |x| x.name == worker } or raise "Worker not found: #{worker.inspect}"
    capsules << Capsule.new(name, worker, weight)
  end

  def register_queue(name, capsule: :default, weight: 1)
    capsules.find { |x| x.name == capsule } or raise "Capsule not found: #{capsule.inspect}"
    queues << Queue.new(name, capsule, weight)
  end

  def retry_interval(error_count, min_interval:, max_interval:)
    interval = min_interval * (1.3**(error_count - 3))
    interval.clamp(min_interval, max_interval).round
  end

  def configure_capsules!(config, priority_level:, max_concurrency:)
    entries = capsules_for(priority_level, max_concurrency)

    unless entries.find { |x| x.capsule == :default }
      entries.last.capsule = :default # Default capsule should always be present in sidekiq
    end

    entries.each do |entry|
      config.capsule(entry.capsule) do |capsule|
        capsule.queues = entry.queues
        capsule.concurrency = entry.concurrency
      end
    end
  end

  def capsules_for(worker, max_concurrency)
    capsules = self.capsules.select do |capsule|
      next unless capsule.worker.to_s == worker.underscore.to_s
      next unless queues.any? { |queue| queue.capsule == capsule.name }
      true
    end

    total_weight = capsules.sum(&:weight)

    result = capsules.filter_map do |capsule|
      weight_coef = capsule.weight / total_weight.to_f
      concurrency = (max_concurrency * weight_coef).to_i
      concurrency = 1 unless concurrency > 1
      queues = self.queues.select { |x| x.capsule == capsule.name }.map { |x| [x.name, x.weight] }
      Entry.new(capsule.name, queues, concurrency)
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
