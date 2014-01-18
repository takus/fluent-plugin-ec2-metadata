module Fluent
  class EC2MetadataOutput < Output
    Fluent::Plugin.register_output('ec2_metadata', self)

    def initialize
      super
      require 'net/http'
    end

    config_param :output_tag,  :string

    config_param :aws_key_id,  :string, :default => ENV['AWS_ACCESS_KEY_ID']
    config_param :aws_sec_key, :string, :default => ENV['AWS_SECRET_ACCESS_KEY']

    def configure(conf)
      super

      # <record></record> directive
      @map = {}
      conf.elements.select { |element| element.name == 'record' }.each { |element|
        element.each_pair { |k, v|
          element.has_key?(k)
          @map[k] = v
        }
      }

      @placeholder_expander = PlaceholderExpander.new

      # get ec2 metadata
      @ec2_metadata = {}
      @ec2_metadata['instance_id']       = get_metadata('instance-id')
      @ec2_metadata['instance_type']     = get_metadata('instance-type')
      @ec2_metadata['availability_zone'] = get_metadata('placement/availability-zone')
      @ec2_metadata['region']            = @ec2_metadata['availability_zone'].chop

      if @aws_key_id and @aws_sec_key then
        require 'aws-sdk'

        AWS.config(access_key_id: @aws_key_id, secret_access_key: @aws_sec_key, region: @ec2_metadata['region'])

        response = AWS.ec2.client.describe_instances( { :instance_ids => [ @ec2_metadata['instance_id'] ] })
        instance = response[:reservation_set].first[:instances_set].first
        raise Fluent::ConfigError, "ec2-metadata: failed to get instance data #{response.pretty_inspect}" if instance.nil?

        @ec2_metadata['vpc_id']    = instance[:vpc_id]
        @ec2_metadata['subnet_id'] = instance[:subnet_id]

        instance[:tag_set].each { |tag|
            @ec2_metadata["tagset_#{tag[:key].downcase}"] = tag[:value]
        }
      end
    end

    def emit(tag, es, chain)
      tag_parts = tag.split('.')
      es.each { |time, record|
        new_tag, new_record = modify(@output_tag, record, tag, tag_parts)
        Engine.emit(new_tag, time, new_record)
      }
      chain.next
    rescue => e
      $log.warn "ec2-metadata: #{e.class} #{e.message} #{e.backtrace.join(', ')}"
    end

    private

    def get_metadata(f)
        res = Net::HTTP.get_response("169.254.169.254", "/latest/meta-data/#{f}")
        raise Fluent::ConfigError, "ec2-metadata: failed to get #{f}" unless res.is_a?(Net::HTTPSuccess)
        res.body
    end

    def modify(output_tag, record, tag, tag_parts)
      @placeholder_expander.prepare_placeholders(record, tag, tag_parts, @ec2_metadata)

      new_tag = @placeholder_expander.expand(output_tag)

      new_record = record.dup
      @map.each_pair { |k, v| new_record[k] = @placeholder_expander.expand(v) }

      [new_tag, new_record]
    end

    class PlaceholderExpander
      # referenced https://github.com/fluent/fluent-plugin-rewrite-tag-filter
      # referenced https://github.com/sonots/fluent-plugin-record-reformer
      attr_reader :placeholders

      def prepare_placeholders(record, tag, tag_parts, ec2_metadata)
        placeholders = {
          '${tag}' => tag,
        }

        size = tag_parts.size
        tag_parts.each_with_index { |t, idx|
          placeholders.store("${tag_parts[#{idx}]}", t)
          placeholders.store("${tag_parts[#{idx-size}]}", t) # support tag_parts[-1]
        }

        ec2_metadata.each { |k, v|
          placeholders.store("${#{k}}", v)
        }

        @placeholders = placeholders
      end

      def expand(str)
        str.gsub(/(\${[a-z_]+(\[-?[0-9]+\])?}|__[A-Z_]+__)/) { $log.warn "ec2-metadata: unknown placeholder `#{$1}` found in a tag `#{tag}`" unless @placeholders.include?($1)
          @placeholders[$1]
        }
      end
    end

  end
end
