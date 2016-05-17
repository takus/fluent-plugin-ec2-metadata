require_relative 'ec2_metadata'

module Fluent
  class EC2MetadataOutput < Output
    include EC2Metadata

    Fluent::Plugin.register_output('ec2_metadata', self)

    # Define `router` method of v0.12 to support v0.10 or earlier
    unless method_defined?(:router)
      define_method("router") { Fluent::Engine }
    end

    config_param :output_tag, :string
    config_param :aws_key_id, :string, :default => ENV['AWS_ACCESS_KEY_ID'], :secret => true
    config_param :aws_sec_key, :string, :default => ENV['AWS_SECRET_ACCESS_KEY'], :secret => true

    attr_reader :ec2_metadata

    def emit(tag, es, chain)
      tag_parts = tag.split('.')
      es.each { |time, record|
        new_tag, new_record = modify(@output_tag, record, tag, tag_parts)
        router.emit(new_tag, time, new_record)
      }
      chain.next
    rescue => e
      $log.warn "ec2-metadata: #{e.class} #{e.message} #{e.backtrace.join(', ')}"
    end
  end
end
