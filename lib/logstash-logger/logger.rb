class LogStashLogger < ::Logger
  
  attr_reader :client
  
  LOGSTASH_EVENT_FIELDS = %w(@timestamp @version).freeze
  
  def initialize(host, port, socket_type=:udp)
    super(::LogStashLogger::Socket.new(host, port, socket_type))
  end
  
  def add(severity, message = nil, progname = nil, &block)
    severity ||= UNKNOWN
    if severity < @level
      return true
    end
    if message.nil? and block_given?
      message = yield
    end
    @logdev.write(
      format_message(format_severity(severity), LogStash::Time.now, progname, message))
    true
  end
  
  def format_message(severity, time, progname, message)
    data = message
    if data.is_a?(String) && data[0] == '{'
      data = (JSON.parse(message) rescue nil) || message
    end

    event = case data
    when LogStash::Event
      data.clone
    when Hash
      event_data = {
        "@timestamp" => time,
        "@version" => 1
      }
      event_data.merge!(data)
      LogStash::Event.new(event_data)
    when String
      LogStash::Event.new("message" => data, "@timestamp" => time, '@version' => 1)
    end

    event['severity'] ||= severity
    event
  end
end
