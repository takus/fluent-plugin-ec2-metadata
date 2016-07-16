module Fluent
  module EC2Metadata

    def initialize
      super
      require 'net/http'
      require 'aws-sdk'
      require 'oj'
    end

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

      set_metadata
      set_tag
    end

    private

    def set_metadata()
      @ec2_metadata = {}


      instance_identity = Oj.load(get_dynamic_data("instance-identity/document"))
      @ec2_metadata['account_id'] = instance_identity["accountId"]
      @ec2_metadata['image_id'] = instance_identity["imageId"]

      @ec2_metadata['instance_id'] = get_metadata('instance-id')
      @ec2_metadata['instance_type'] = get_metadata('instance-type')
      @ec2_metadata['availability_zone'] = get_metadata('placement/availability-zone')
      @ec2_metadata['region'] = @ec2_metadata['availability_zone'].chop
      @ec2_metadata['private_ip'] = get_metadata('local-ipv4')
      @ec2_metadata['mac'] = get_metadata('mac')
      begin
        @ec2_metadata['vpc_id'] = get_metadata("network/interfaces/macs/#{@ec2_metadata['mac']}/vpc-id")
      rescue
        @ec2_metadata['vpc_id'] = nil
        $log.info "ec2-metadata: 'vpc_id' is undefined #{@ec2_metadata['instance_id']} is not in VPC}"
      end
      begin
        @ec2_metadata['subnet_id'] = get_metadata("network/interfaces/macs/#{@ec2_metadata['mac']}/subnet-id")
      rescue
        @ec2_metadata['subnet_id'] = nil
        $log.info "ec2-metadata: 'subnet_id' is undefined because #{@ec2_metadata['instance_id']} is not in VPC}"
      end
    end

    def get_dynamic_data(f)
      res = Net::HTTP.get_response("169.254.169.254", "/latest/dynamic/#{f}")
      raise Fluent::ConfigError, "ec2-dynamic-data: failed to get #{f}" unless res.is_a?(Net::HTTPSuccess)
      res.body
    end

    def get_metadata(f)
      res = Net::HTTP.get_response("169.254.169.254", "/latest/meta-data/#{f}")
      raise Fluent::ConfigError, "ec2-metadata: failed to get #{f}" unless res.is_a?(Net::HTTPSuccess)
      res.body
    end

    def set_tag()
      if @map.values.any? { |v| v.match(/^\${tagset_/) } || @output_tag =~ /\${tagset_/

        if @aws_key_id and @aws_sec_key
          ec2 = Aws::EC2::Client.new(
            region: @ec2_metadata['region'],
            access_key_id: @aws_key_id,
            secret_access_key: @aws_sec_key,
          )
        else
          ec2 = Aws::EC2::Client.new(
            region: @ec2_metadata['region'],
          )
        end

        response = ec2.describe_instances({ :instance_ids => [@ec2_metadata['instance_id']] })
        instance = response.reservations[0].instances[0]
        raise Fluent::ConfigError, "ec2-metadata: failed to get instance data #{response.pretty_inspect}" if instance.nil?

        instance.tags.each { |tag|
          @ec2_metadata["tagset_#{tag.key.downcase}"] = tag.value
        }
      end
    end

    def modify_record(record, tag, tag_parts)
      @placeholder_expander.prepare_placeholders(record, tag, tag_parts, @ec2_metadata)
      new_record = record.dup
      @map.each_pair { |k, v| new_record[k] = @placeholder_expander.expand(v) }
      new_record
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

        @placeholders = placeholders
      end

      def expand(str)
        str.gsub(/(\${[a-z_]+(\[-?[0-9]+\])?}|__[A-Z_]+__)/) {
          $log.warn "ec2-metadata: unknown placeholder `#{$1}` found in a tag `#{@placeholders['${tag}']}`" unless @placeholders.include?($1)
          @placeholders[$1]
        }
      end
    end
  end
end
