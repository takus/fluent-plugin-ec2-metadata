require 'fluent/plugin/filter'
require_relative 'ec2_metadata'

module Fluent::Plugin
  class EC2MetadataFilter < Filter
    include Fluent::EC2Metadata

    Fluent::Plugin.register_filter('ec2_metadata', self)

    config_param :aws_key_id, :string, default: ENV['AWS_ACCESS_KEY_ID'], secret: true
    config_param :aws_sec_key, :string, default: ENV['AWS_SECRET_ACCESS_KEY'], secret: true
    config_param :metadata_refresh_seconds, :integer, default: 300
    config_param :imdsv2, :bool, default: false

    attr_reader :ec2_metadata

    def filter(tag, time, record)
      tag_parts = tag.split('.')
      modify_record(record, tag, tag_parts)
    rescue => e
      log.warn "ec2-metadata: #{e.class} #{e.message} #{e.backtrace.join(', ')}"
    end
  end
end
