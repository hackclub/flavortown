class FlavortextService
  def self.method_missing(method_name, *args, &block)
    if args.length == 1 && args.first.is_a?(String)
      key = args.first
      file_path = Rails.root.join("app", "services", "flavortext", "#{method_name}.yml")
      
      if File.exist?(file_path)
        new(file_path).sample_from_key(key)
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
    item = @data[key]
    return key if item.nil?
    text = item&.is_a?(Array) ? item.sample : item
    process_erb(text)
  end

  # Method available in ERB context to sample from other keys
  def transcript(key)
    sample_from_key(key)
  end

  # Short alias for transcript
  alias_method :t, :transcript

  private

  def load_flavortext_data(file_path)
    YAML.load_file(file_path)
  end

  def process_erb(text, depth = 0)
    return text unless text.include?("<%")
    return text if depth >= 10 # Max recursion depth
    
    erb = ERB.new(text)
    result = erb.result(binding)
    
    # Recursive ERB processing - if the result still contains ERB, process it again
    if result != text && result.include?("<%")
      process_erb(result, depth + 1)
    else
      result
    end
  end
end
