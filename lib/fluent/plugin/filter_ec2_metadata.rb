require_relative 'ec2_metadata'

module Fluent
  class EC2MetadataFilter < Filter
    include Fluent::EC2Metadata

    Fluent::Plugin.register_filter('ec2_metadata', self)

    # Define `router` method of v0.12 to support v0.10 or earlier
    unless method_defined?(:router)
      define_method("router") { Fluent::Engine }
    end

    config_param :aws_key_id, :string, :default => ENV['AWS_ACCESS_KEY_ID'], :secret => true
    config_param :aws_sec_key, :string, :default => ENV['AWS_SECRET_ACCESS_KEY'], :secret => true

    attr_reader :ec2_metadata

    def filter(tag, time, record)
      tag_parts = tag.split('.')
      modify_record(record, tag, tag_parts)
    rescue => e
      $log.warn "ec2-metadata: #{e.class} #{e.message} #{e.backtrace.join(', ')}"
    end
  end
end
