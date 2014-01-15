module Fluent
  class EC2MetadataOutput < Output
    Fluent::Plugin.register_output('ec2-metadata', self)

    def initialize
      super
      require 'net/http'
    end

    ALLOWED_FIELD = {
        'ami_id'            => 'ami-id',
        'availability_zone' => 'placement/availability-zone',
        'instance_id'       => 'instance-id',
        'instance_type'     => 'instance-type',
    }

    config_param :output_tag, :string
    config_param :add_fields, :string

    def configure(conf)
      super
      @add_fields = @add_fields.split(',')

      @ec2_metadata = {}
      @add_fields.each { |f|
        raise Fluent::ConfigError, "#{f} is not allowed key" unless ALLOWED_FIELD.include?(f)
        @ec2_metadata[f] = get_metadata(f)
      }
    end

    def emit(tag, es, chain)
      es.each { |time, record|
        Engine.emit(output_tag, time, add_field(record))
      }
      chain.next
    rescue => e
      $log.warn e.message
      $log.warn e.backtrace.join(', ')
    end

    private

    def get_metadata(f)
        res = Net::HTTP.get_response("169.254.169.254", "/latest/meta-data/#{ALLOWED_FIELD[f]}")
        raise Fluent::ConfigError, "failed to get #{f}. Perhaps this host is not on EC2?" unless res.is_a?(Net::HTTPSuccess)
        res.body
    end

    def add_field(record)
      @ec2_metadata.each_pair { |k, v|
        record[k] = v
      }
      record
    end

  end
end
