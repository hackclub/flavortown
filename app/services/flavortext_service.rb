class FlavortextService
  def self.method_missing(method_name, *args, &block)
    if args.length >= 1 && args.first.is_a?(String)
      key = args.first
      options = args[1] || {}
      file_path = Rails.root.join("app", "services", "flavortext", "#{method_name}.yml")

      if File.exist?(file_path)
        service = new(file_path)
        service.instance_variable_set(:@options, options)
        service.sample_from_key(key)
      else
        super
      end
    else
      super
    end
  end

  def self.respond_to_missing?(method_name, include_private = false)
    file_path = Rails.root.join("app", "services", "flavortext", "#{method_name}.yml")
    File.exist?(file_path) || super
  end

  def initialize(file_path)
    @data = load_flavortext_data(file_path)
    @file_path = file_path
  end

  def sample_from_key(key)
    # Handle dot notation for nested keys
    if key.include?(".")
      keys = key.split(".")
      item = @data[keys.first]
      keys[1..-1].each { |k| item = item[k] if item }
    else
      item = @data[key]
    end

    return key if item.nil?
    text = item&.is_a?(Array) ? item.sample : item
    process_erb(text)
  end

  def all_from_key(key)
    item = @data[key]
    return [ key ] if item.nil?

    if item.is_a?(Array)
      item.map { |text| process_erb(text) }
    else
      [ process_erb(item) ]
    end
  end

  # Method available in ERB context to sample from other keys
  def transcript(key)
    sample_from_key(key)
  end

  # Short alias for transcript
  alias_method :t, :transcript

  private

  def load_flavortext_data(file_path)
    if Rails.env.development?
      YAML.load_file(file_path)
    else
      @@flavortext_files ||= {}
      @@flavortext_files[file_path] ||= YAML.load_file(file_path)
    end
  end

  def process_erb(text, depth = 0)
    return text unless text.include?("<%")
    return text if depth >= 10 # Max recursion depth

    erb = ERB.new(text)
    erb_binding = create_erb_binding(@options || {})
    result = erb.result(erb_binding)

    # Recursive ERB processing - if the result still contains ERB, process it again
    if result != text && result.include?("<%")
      process_erb(result, depth + 1)
    else
      result
    end
  end

  def create_erb_binding(options)
    # Create a clean binding with the options and service methods available
    erb_context = Object.new
    service = self

    # Make service methods available
    erb_context.define_singleton_method(:t) { |key| service.sample_from_key(key) }
    erb_context.define_singleton_method(:transcript) { |key| service.sample_from_key(key) }

    # Make options available as instance variables
    options.each do |key, value|
      erb_context.instance_variable_set("@#{key}", value)
    end

    erb_context.instance_eval { binding }
  end
end
