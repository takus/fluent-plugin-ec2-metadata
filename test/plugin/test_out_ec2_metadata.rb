require 'helper'

require 'webmock/test_unit'
WebMock.disable_net_connect!

class EC2MetadataOutputTest < Test::Unit::TestCase

  CONFIG = %[
    output_tag ${instance_id}.${tag}
    aws_key_id aws_key
    aws_sec_key aws_sec
    <record>
      name ${tagset_name}
      instance_id ${instance_id}
      az ${availability_zone}
    </record>
  ]

  def setup
    Fluent::Test.setup
    @time = Fluent::Engine.now
  end

  def create_driver(conf=CONFIG, tag='test')
    Fluent::Test::OutputTestDriver.new(Fluent::EC2MetadataOutput, tag).configure(conf)
  end

  test 'configure' do
    VCR.use_cassette('ec2') do
      d = create_driver
      assert_equal("${instance_id}.${tag}", d.instance.output_tag)
      assert_equal("aws_key", d.instance.aws_key_id)
      assert_equal("aws_sec", d.instance.aws_sec_key)
    end
  end

  test 'emit' do
    VCR.use_cassette('ec2') do
      d = create_driver

      d.run do
        d.emit("a" => 1)
        d.emit("a" => 2)
      end

      # tag
      assert_equal "i-0c0c0000.test", d.emits[0][0]
      assert_equal "i-0c0c0000.test", d.emits[1][0]

      # record
      mapped = { 'instance_id' => 'i-0c0c0000', 'az' => 'ap-northeast-1b', 'name' => 'instance-name' }
      assert_equal [
        {"a" => 1}.merge(mapped),
        {"a" => 2}.merge(mapped),
      ], d.records
    end
  end

end
