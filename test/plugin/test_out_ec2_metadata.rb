require 'helper'

class EC2MetadataOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    output_tag ec2.test
    add_fields instance_id,ami_id
  ]

  def create_driver(conf = CONFIG, tag='test')
    Fluent::Test::OutputTestDriver.new(Fluent::EC2MetadataOutput, tag).configure(conf)
  end

  def get_instance_id
    Net::HTTP.get_response('169.254.169.254', '/latest/meta-data/instance-id').body
  end

  def get_ami_id
    Net::HTTP.get_response('169.254.169.254', '/latest/meta-data/ami-id').body
  end

  def test_configure
    d = create_driver %[
      output_tag ec2.test
      add_fields instance_id,ami_id
    ]
    assert_equal 'ec2.test', d.instance.output_tag
    assert_equal ['instance_id','ami_id'], d.instance.add_fields
  end

  def test_emit
    d = create_driver

    d.run do
      d.emit("a" => 1)
      d.emit("a" => 2)
    end

    mapped = { 'instance_id' => get_instance_id, 'ami_id' => get_ami_id }
    assert_equal [
      {"a" => 1}.merge(mapped),
      {"a" => 2}.merge(mapped),
    ], d.records
  end
end
