class LogStashLogger < ::Logger
  
  attr_reader :client
  
  LOGSTASH_EVENT_FIELDS = %w(@timestamp @tags @type @source @fields message).freeze
  HOST = ::Socket.gethostname
  
  def initialize(host, port, socket_type=:udp, debug=false)
    @debug = debug
    super(::LogStashLogger::Socket.new(host, port, socket_type))
  end
  
  def add(severity, message = nil, progname = nil, &block)
    severity ||= UNKNOWN
    if severity < @level
      return true
    end
    progname ||= @progname
    if message.nil?
      if block_given?
        message = yield
      else
        message = progname
        progname = @progname
      end
    end
    @logdev.write(
      format_message(format_severity(severity), Time.now, progname, message))
    true
  end
  
  def format_message(severity, time, progname, message)
    data = message
    if data.is_a?(String) && data[0] == '{'
      data = (JSON.parse(message) rescue nil) || message
    end
    
    event = case data
    when LogStash::Event
      data
    when Hash
      LogStash::Event.new(data.dup)
    when String
      LogStash::Event.new("message" => data, "@timestamp" => time)
    end

    event['severity'] ||= severity
    #event.type = progname
    if event['source'] == 'unknown'
      event['source'] = HOST
    end

    if @formatter && @formatter.is_a?(Proc) && @formatter.arity == 1
      @formatter.call(event)
    end

    puts event.to_hash if @debug
    event
  end
end
