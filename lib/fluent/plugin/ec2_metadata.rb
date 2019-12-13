module Fluent
  module EC2Metadata

    def initialize
      super
      require 'net/http'
      require 'aws-sdk-ec2'
      require 'oj'
    end

    def configure(conf)
      super

      # <record></record> directive
      @map = {}
      conf.elements.select { |element| element.name == 'record' }.each { |element|
        element.each_pair { |k, v|
          element.has_key?(k) # to suppress unread configuration warning
          @map[k] = v
        }
      }

      @placeholder_expander = PlaceholderExpander.new(log)

      # get metadata first and then setup a refresh thread
      @ec2_metadata = get_metadata_and_tags
      @refresh_thread = Thread.new {
        while true
          sleep @metadata_refresh_seconds
          @ec2_metadata = get_metadata_and_tags
        end
      }
    end

    private

    def get_metadata_and_tags
      metadata = {}
      set_metadata(metadata)
      set_tag(metadata)
      metadata
    end

    def set_metadata(ec2_metadata)
      instance_identity = Oj.load(get_dynamic_data("instance-identity/document"))
      ec2_metadata['account_id'] = instance_identity["accountId"]
      ec2_metadata['image_id'] = instance_identity["imageId"]

      ec2_metadata['instance_id'] = get_metadata('instance-id')
      ec2_metadata['instance_type'] = get_metadata('instance-type')
      ec2_metadata['availability_zone'] = get_metadata('placement/availability-zone')
      ec2_metadata['region'] = ec2_metadata['availability_zone'].chop
      ec2_metadata['private_ip'] = get_metadata('local-ipv4')
      ec2_metadata['mac'] = get_metadata('mac')
      begin
        ec2_metadata['vpc_id'] = get_metadata("network/interfaces/macs/#{ec2_metadata['mac']}/vpc-id")
      rescue
        ec2_metadata['vpc_id'] = nil
        log.info "ec2-metadata: 'vpc_id' is undefined #{ec2_metadata['instance_id']} is not in VPC}"
      end
      begin
        ec2_metadata['subnet_id'] = get_metadata("network/interfaces/macs/#{ec2_metadata['mac']}/subnet-id")
      rescue
        ec2_metadata['subnet_id'] = nil
        log.info "ec2-metadata: 'subnet_id' is undefined because #{ec2_metadata['instance_id']} is not in VPC}"
      end
      ec2_metadata
    end

    def get_dynamic_data(f)
      Net::HTTP.start('169.254.169.254') do |http|
        res = http.get("/latest/dynamic/#{f}", get_header())
        raise Fluent::ConfigError, "ec2-dynamic-data: failed to get #{f}" unless res.is_a?(Net::HTTPSuccess)
        res.body
      end
    end

    def get_metadata(f)
      Net::HTTP.start('169.254.169.254') do |http|
        res = http.get("/latest/meta-data/#{f}", get_header())
        raise Fluent::ConfigError, "ec2-metadata: failed to get #{f}" unless res.is_a?(Net::HTTPSuccess)
        res.body
      end
    end

    def get_header()
      if @imdsv2
        Net::HTTP.start('169.254.169.254') do |http|
          res = http.put("/latest/api/token", '', { 'X-aws-ec2-metadata-token-ttl-seconds' => '300' })
          raise Fluent::ConfigError, "ec2-metadata: failed to get token" unless res.is_a?(Net::HTTPSuccess)
          { 'X-aws-ec2-metadata-token' => res.body }
        end
      else
        {}
      end
    end

    def set_tag(ec2_metadata)
      if @map.values.any? { |v| v.match(/^\${tagset_/) } || @output_tag =~ /\${tagset_/

        if @aws_key_id and @aws_sec_key
          ec2 = Aws::EC2::Client.new(
            region: ec2_metadata['region'],
            access_key_id: @aws_key_id,
            secret_access_key: @aws_sec_key,
          )
        else
          ec2 = Aws::EC2::Client.new(
            region: ec2_metadata['region'],
          )
        end

        response = ec2.describe_instances({ :instance_ids => [ec2_metadata['instance_id']] })
        instance = response.reservations[0].instances[0]
        raise Fluent::ConfigError, "ec2-metadata: failed to get instance data #{response.pretty_inspect}" if instance.nil?

        instance.tags.each { |tag|
          ec2_metadata["tagset_#{tag.key.downcase}"] = tag.value
        }
      end
    end

    def modify_record(record, tag, tag_parts)
      placeholders = @placeholder_expander.prepare_placeholders(record, tag, tag_parts, @ec2_metadata)
      new_record = record.dup
      @map.each_pair { |k, v| new_record[k] = @placeholder_expander.expand(v, placeholders) }
      new_record
    end

    def modify(output_tag, record, tag, tag_parts)
      placeholders = @placeholder_expander.prepare_placeholders(record, tag, tag_parts, @ec2_metadata)

      new_tag = @placeholder_expander.expand(output_tag, placeholders)

      new_record = record.dup
      @map.each_pair { |k, v| new_record[k] = @placeholder_expander.expand(v, placeholders) }

      [new_tag, new_record]
    end

    class PlaceholderExpander
      def initialize(log)
        @log = log
      end

      # referenced https://github.com/fluent/fluent-plugin-rewrite-tag-filter
      # referenced https://github.com/sonots/fluent-plugin-record-reformer
      attr_reader :placeholders

      def prepare_placeholders(_record, tag, tag_parts, ec2_metadata)
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

        placeholders
      end

      def expand(str, placeholders)
        str.gsub(/(\${[a-z_:\-]+(\[-?[0-9]+\])?}|__[A-Z_]+__)/) {
          @log.warn "ec2-metadata: unknown placeholder `#{$1}` found in a tag `#{placeholders['${tag}']}`" unless placeholders.include?($1)
          placeholders[$1]
        }
      end
    end
  end
end
