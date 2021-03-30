# frozen_string_literal: true

module UmbrellioUtils
  module Constants
    extend self

    def get_class(*name_parts)
      safe_constantize(name_parts.join("/").underscore.camelize)
    end

    def get_class!(*args)
      get_class(*args) or raise "Failed to get class for #{args.inspect}"
    end

    def safe_constantize(constant_name)
      constant = suppress(NameError) { Object.const_get(constant_name, false) }
      constant if constant && constant.name == constant_name
    end

    def match_by_class!(**kwargs)
      name, instance = kwargs.shift
      result = kwargs.find { |klass, _| instance.is_a?(klass) }&.last
      raise "Unsupported #{name} type: #{instance.inspect}" if result.nil?

      result.is_a?(Proc) ? result.call : result
    end
  end
end
